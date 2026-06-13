import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DEFAULT_PROJECT_ROOT = path.resolve(__dirname, "../../..");
const PROJECT_ROOT = process.env.INOVA_PROJECT_ROOT || DEFAULT_PROJECT_ROOT;

function textResult(text) {
  return { content: [{ type: "text", text }] };
}

function runProcess(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args, {
      cwd: options.cwd ?? PROJECT_ROOT,
      env: { ...process.env, ...options.env },
      shell: options.shell ?? false,
      stdio: "pipe",
    });

    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code === 0 || options.allowFailure) {
        resolve({ code, stdout: stdout.trim(), stderr: stderr.trim() });
      } else {
        reject(
          new Error(
            [`Command failed: ${command} ${args.join(" ")}`, stdout, stderr]
              .filter(Boolean)
              .join("\n"),
          ),
        );
      }
    });
  });
}

function pythonPath() {
  return process.platform === "win32"
    ? path.join(PROJECT_ROOT, ".venv", "Scripts", "python.exe")
    : path.join(PROJECT_ROOT, ".venv", "bin", "python");
}

async function dockerCompose(args, allowFailure = false) {
  return runProcess("docker", ["compose", ...args], { allowFailure });
}

async function publishViaDocker(subject, payloadRelative) {
  const { stdout, stderr } = await dockerCompose([
    "run",
    "--rm",
    "publisher",
    "python",
    "scripts/publish_event.py",
    "--subject",
    subject,
    "--payload",
    payloadRelative,
  ]);
  return [stdout, stderr].filter(Boolean).join("\n");
}

async function queryAuditLogLocal(args) {
  const pyArgs = [path.join(PROJECT_ROOT, "scripts", "query_audit_log.py")];
  if (args.correlation_id) {
    pyArgs.push("--correlation-id", args.correlation_id);
  }
  if (args.worker) {
    pyArgs.push("--worker", args.worker);
  }
  pyArgs.push("--last", String(args.last ?? 20));
  pyArgs.push("--docker");

  const { stdout, stderr } = await runProcess(pythonPath(), pyArgs, {
    allowFailure: true,
  });
  return [stdout, stderr].filter(Boolean).join("\n") || "(sem output)";
}

const server = new McpServer({
  name: "inova-runtime-mcp",
  version: "1.0.0",
});

server.registerTool(
  "publish_orchestrate",
  {
    description:
      "Publish task.orchestrate.requested to NATS (requires Docker stack up).",
    inputSchema: {
      pipeline: z
        .enum(["default", "full-devsecops"])
        .default("default")
        .describe("default=audit+test+review; full=all 10 workers"),
      correlation_id: z.string().optional(),
    },
  },
  async (args) => {
    const payloadFile =
      args.pipeline === "full-devsecops"
        ? "examples/events/orchestrate_full_devsecops.json"
        : "examples/events/orchestrate_requested.json";
    const publishPayload = "examples/events/.mcp_orchestrate_payload.json";

    if (args.correlation_id) {
      await runProcess(
        pythonPath(),
        [
          "-c",
          [
            "import json, pathlib",
            `src = pathlib.Path('${payloadFile}')`,
            `out = pathlib.Path('${publishPayload}')`,
            "d = json.loads(src.read_text(encoding='utf-8-sig'))",
            `d['correlation_id'] = ${JSON.stringify(args.correlation_id)}`,
            "out.write_text(json.dumps(d), encoding='utf-8')",
          ].join("; "),
        ],
        { cwd: PROJECT_ROOT },
      );
    }

    const output = await publishViaDocker(
      "task.orchestrate.requested",
      args.correlation_id ? publishPayload : payloadFile,
    );
    return textResult(output);
  },
);

server.registerTool(
  "publish_event",
  {
    description: "Publish any event subject with a JSON payload file path (relative to project root).",
    inputSchema: {
      subject: z.string().min(1),
      payload_path: z
        .string()
        .min(1)
        .describe("e.g. examples/events/audit_requested.json"),
    },
  },
  async (args) => {
    const output = await publishViaDocker(args.subject, args.payload_path);
    return textResult(output);
  },
);

server.registerTool(
  "query_audit_log",
  {
    description: "Query worker_audit_log from PostgreSQL.",
    inputSchema: {
      correlation_id: z.string().optional(),
      worker: z.string().optional(),
      last: z.number().int().min(1).max(200).default(20),
    },
  },
  async (args) => {
    const output = await queryAuditLogLocal(args);
    return textResult(output);
  },
);

server.registerTool(
  "runtime_health",
  {
    description: "Check Docker compose service status and NATS health endpoint.",
    inputSchema: {},
  },
  async () => {
    const ps = await dockerCompose(["ps"], true);
    let nats = "";
    try {
      const res = await fetch("http://127.0.0.1:8222/healthz");
      nats = `NATS healthz: ${res.status} ${await res.text()}`;
    } catch (error) {
      nats = `NATS healthz: unavailable (${error.message})`;
    }
    return textResult(`${ps.stdout}\n\n${nats}`);
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

import asyncio

from workers.common.handler import handle_task
from workers.common.runner import run_worker

WORKER_NAME = "opencode_executor"
SUBJECT = "task.opencode.requested"
DURABLE = "inova-opencode-executor"
COMPLETED_SUBJECT = "task.opencode.completed"
DESCRIPTION = "Executa auditoria/construcao via OpenCode/OpenRouter quando configurado."


async def main():
    async def handler(event):
        return await handle_task(
            WORKER_NAME, DESCRIPTION, DURABLE, COMPLETED_SUBJECT, event
        )

    await run_worker(WORKER_NAME, SUBJECT, DURABLE, COMPLETED_SUBJECT, handler)


if __name__ == "__main__":
    asyncio.run(main())

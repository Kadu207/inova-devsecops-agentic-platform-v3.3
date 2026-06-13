# Contratos de integração — workers externos

Todos os adapters vivem em `workers/common/adapters.py`. Cada worker chama `run_adapter(worker_name, event)` e recebe um dict com `mode: stub|integrated`.

## Envelope comum (entrada)

Campos do `EventEnvelope` usados pelos adapters:

| Campo | Uso |
|-------|-----|
| `tenant_id` | Tags Datadog, contexto multi-tenant |
| `project` | Chave Sonar default, identificação |
| `correlation_id` | Rastreio ponta a ponta |
| `payload` | Parâmetros específicos por worker (abaixo) |

---

## OpenRouter / opencode_executor

**Subject:** `task.opencode.requested`  
**Env:** `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`

| Payload key | Tipo | Descrição |
|-------------|------|-----------|
| `prompt` | string \| list | Texto enviado ao modelo |
| `scope` | string | Fallback se `prompt` ausente |

**Saída stub:** `{ mode, provider, note }`  
**Saída integrated:** `{ mode, provider, model, summary }` (summary truncado em 2000 chars)

---

## SonarQube / sonar_worker

**Subject:** `task.sonar.requested`  
**Env:** `SONAR_HOST_URL`, `SONAR_TOKEN`

| Payload key | Tipo | Descrição |
|-------------|------|-----------|
| `project_key` | string | Default: `event.project` |

**API:** `GET /api/qualitygates/project_status?projectKey=...`  
**Saída integrated:** `{ mode, provider, project_key, quality_gate, passed }`

---

## Snyk / snyk_worker

**Subject:** `task.snyk.requested`  
**Env:** `SNYK_TOKEN`

| Payload key | Tipo | Descrição |
|-------------|------|-----------|
| `org_id` | string | Opcional; default primeira org da conta |

**API:** `GET https://api.snyk.io/rest/orgs`  
**Saída integrated:** `{ mode, provider, org_id, orgs_available, vulnerabilities_checked }`

---

## Datadog / datadog_worker

**Subject:** `task.datadog.requested`  
**Env:** `DATADOG_API_KEY`

| Payload key | Tipo | Descrição |
|-------------|------|-----------|
| `title` | string | Título do evento |
| `text` | string | Corpo do evento |

**API:** `POST https://api.datadoghq.com/api/v1/events`  
**Saída integrated:** `{ mode, provider, event_id, status }`

---

## Workers internos (sempre stub local)

| Worker | Subject | Saída típica |
|--------|---------|--------------|
| audit_pipeline | task.audit.requested | score, checks |
| test_worker | task.test.requested | tests_passed |
| build_worker | task.build.requested | artifact |
| review_worker | task.review.requested | review_status |
| release_worker | task.release.requested | release_gate |
| notification_worker | task.notification.requested | channel, delivered |

---

## Exemplos de publish

```bash
make publish-orchestrate
docker compose run --rm publisher python scripts/publish_event.py \
  --subject task.sonar.requested \
  --payload examples/events/sonar_requested.json
```

Pipeline completo: `examples/events/orchestrate_full_devsecops.json`

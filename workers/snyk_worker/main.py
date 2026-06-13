import asyncio

from workers.common.handler import handle_task
from workers.common.runner import run_worker

WORKER_NAME = "snyk_worker"
SUBJECT = "task.snyk.requested"
DURABLE = "inova-snyk-worker"
COMPLETED_SUBJECT = "task.snyk.completed"
DESCRIPTION = "Integra analise Snyk."


async def main():
    async def handler(event):
        return await handle_task(
            WORKER_NAME, DESCRIPTION, DURABLE, COMPLETED_SUBJECT, event
        )

    await run_worker(WORKER_NAME, SUBJECT, DURABLE, COMPLETED_SUBJECT, handler)


if __name__ == "__main__":
    asyncio.run(main())

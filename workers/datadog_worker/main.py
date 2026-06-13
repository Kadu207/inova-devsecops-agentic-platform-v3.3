import asyncio

from workers.common.handler import handle_task
from workers.common.runner import run_worker

WORKER_NAME = "datadog_worker"
SUBJECT = "task.datadog.requested"
DURABLE = "inova-datadog-worker"
COMPLETED_SUBJECT = "task.datadog.completed"
DESCRIPTION = "Envia rastreabilidade para Datadog."


async def main():
    async def handler(event):
        return await handle_task(
            WORKER_NAME, DESCRIPTION, DURABLE, COMPLETED_SUBJECT, event
        )

    await run_worker(WORKER_NAME, SUBJECT, DURABLE, COMPLETED_SUBJECT, handler)


if __name__ == "__main__":
    asyncio.run(main())

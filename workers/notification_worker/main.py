import asyncio

from workers.common.handler import handle_task
from workers.common.runner import run_worker

WORKER_NAME = "notification_worker"
SUBJECT = "task.notification.requested"
DURABLE = "inova-notification-worker"
COMPLETED_SUBJECT = "task.notification.completed"
DESCRIPTION = "Envia notificacoes e resumo final."


async def main():
    async def handler(event):
        return await handle_task(
            WORKER_NAME, DESCRIPTION, DURABLE, COMPLETED_SUBJECT, event
        )

    await run_worker(WORKER_NAME, SUBJECT, DURABLE, COMPLETED_SUBJECT, handler)


if __name__ == "__main__":
    asyncio.run(main())

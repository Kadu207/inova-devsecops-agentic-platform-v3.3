import asyncio

from workers.common.handler import handle_task
from workers.common.runner import run_worker

WORKER_NAME = "sonar_worker"
SUBJECT = "task.sonar.requested"
DURABLE = "inova-sonar-worker"
COMPLETED_SUBJECT = "task.sonar.completed"
DESCRIPTION = "Integra Quality Gate SonarQube."


async def main():
    async def handler(event):
        return await handle_task(
            WORKER_NAME, DESCRIPTION, DURABLE, COMPLETED_SUBJECT, event
        )

    await run_worker(WORKER_NAME, SUBJECT, DURABLE, COMPLETED_SUBJECT, handler)


if __name__ == "__main__":
    asyncio.run(main())

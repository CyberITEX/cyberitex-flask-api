import os
from celery import Celery
from dotenv import load_dotenv

load_dotenv()

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# Shared Celery instance for all task modules
celery = Celery(
    "cyberitex",
    backend=REDIS_URL,
    broker=REDIS_URL,
    include=[
        "v1.tasks.routes",
        # Add new task modules here as they're created
    ]
)

celery.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    result_expires=86400,  # 24 hours
)

from celery.exceptions import SoftTimeLimitExceeded
from flask import Blueprint, jsonify, request
from common.celery_app import celery
from common.utils.common_utils import require_api_key
from common.utils.limiter import limiter
from time import sleep


tasks_routes = Blueprint("tasks", __name__)


@tasks_routes.route("/", methods=["GET"])
@limiter.limit("5/minute")
def home_tools():
    return jsonify({"message": "Welcome to CyberITEX tasks!"}), 200


@tasks_routes.route("/RunBackgroundTask", methods=["GET"])
@limiter.limit("20/minute")
def RunBackgroundTask():
    task = background_task.delay()
    return jsonify({"response": task.id}), 200


@celery.task(bind=True, time_limit=7200, soft_time_limit=7100, rate_limit="10/m")
def background_task(self):
    task_id = self.request.id
    try:
        sleep(10)
        return task_id
    except SoftTimeLimitExceeded:
        return f"Task exceeded soft time limit for"


@tasks_routes.route("/status/<task_id>", methods=["GET"])
@limiter.limit("30/minute")
def get_task_status(task_id):
    result = celery.AsyncResult(task_id)
    response = {
        "task_id": task_id,
        "state": result.state,
    }

    if result.state == "PENDING":
        response["message"] = "Task is pending or unknown"
    elif result.state == "STARTED":
        response["message"] = "Task has started"
    elif result.state == "SUCCESS":
        response["result"] = result.result
    elif result.state == "FAILURE":
        response["error"] = str(result.result)
    elif result.state == "REVOKED":
        response["message"] = "Task was revoked"

    return jsonify(response), 200


# Status route for checking The request status
@tasks_routes.route("/GetPendingRequests", methods=["GET"])
@require_api_key
# Function to inspect and gather tasks that are not successful
def GetPendingRequests():
    # Inspect the workers
    inspect = celery.control.inspect()

    # Get all active, scheduled, and reserved tasks
    active_tasks = inspect.active() or {}
    scheduled_tasks = inspect.scheduled() or {}
    reserved_tasks = inspect.reserved() or {}

    pending_tasks = []

    # Function to check tasks in any state (active, scheduled, reserved)
    def check_tasks(tasks, state_name):
        for worker, worker_tasks in tasks.items():
            for task in worker_tasks:
                task_id = task["id"]
                result = celery.AsyncResult(task_id)
                if result.state != "SUCCESS":  # Check if the task is not successful
                    pending_tasks.append(
                        {
                            "task_id": task_id,
                            "state": result.state,
                            "worker": worker,
                            "type": state_name,
                        }
                    )

    # Check active, scheduled, and reserved tasks
    check_tasks(active_tasks, "active")
    check_tasks(scheduled_tasks, "scheduled")
    check_tasks(reserved_tasks, "reserved")
    return jsonify({"response": pending_tasks}), 200

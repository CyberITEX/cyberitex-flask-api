import json
import pytest
from unittest.mock import patch
from app import app  # Adjust import if needed


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_home_tools(client):
    """Test the home route for tasks."""
    response = client.get('/v1/tasks/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['message'] == "Welcome to CyberITEX tasks!"


@patch('v1.tasks.routes.background_task.delay')
def test_run_background_task(mock_delay, client):
    """Test the RunBackgroundTask route."""
    mock_task = mock_delay.return_value
    mock_task.id = "mock-task-id"

    response = client.get('/v1/tasks/RunBackgroundTask')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['response'] == "mock-task-id"


@patch('v1.tasks.routes.celery.control.inspect')
def test_get_pending_requests(mock_inspect, client):
    """Test the GetPendingRequests route."""
    # Mock Celery inspect results
    mock_inspect.return_value.active.return_value = {
        "worker1": [{"id": "task1"}]
    }
    mock_inspect.return_value.scheduled.return_value = {}
    mock_inspect.return_value.reserved.return_value = {}

    headers = {"X-Api-Key": "expected-api-key"}  # Adjust key as needed
    response = client.get('/v1/tasks/GetPendingRequests', headers=headers)

    assert response.status_code == 200
    data = json.loads(response.data)
    assert len(data['response']) == 1
    assert data['response'][0]['task_id'] == "task1"
    assert data['response'][0]['state'] != "SUCCESS"
    assert data['response'][0]['worker'] == "worker1"
    assert data['response'][0]['type'] == "active"


@patch('v1.tasks.routes.background_task.delay')
def test_run_background_task_rate_limit(mock_delay, client):
    """Test rate limiting on RunBackgroundTask route."""
    mock_task = mock_delay.return_value
    mock_task.id = "mock-task-id"

    for _ in range(21):  # Exceed the rate limit of 20/minute
        response = client.get('/v1/tasks/RunBackgroundTask')

    assert response.status_code == 429  # Rate limit exceeded


def test_get_pending_requests_requires_api_key(client):
    """Test that GetPendingRequests route requires an API key."""
    response = client.get('/v1/tasks/GetPendingRequests')
    assert response.status_code == 401
    data = json.loads(response.data)
    assert "response" in data
    assert data['response'] == "Invalid or missing API key"

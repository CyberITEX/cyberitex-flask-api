import json
from unittest.mock import patch
from app import app


@patch('app.logging.getLogger')
def test_logging_message(mock_get_logger):
    """Test that the logger captures request details."""
    mock_logger = mock_get_logger.return_value
    app.config['TESTING'] = True

    with app.test_client() as client:
        client.get('/')

    # Verify the logger logged the correct details
    logged_calls = mock_logger.info.call_args_list  # Get all `info` calls

    # Check if any logged call matches the expected JSON structure
    found = False
    for call in logged_calls:
        try:
            log_data = json.loads(call[0][0])  # Parse the logged string into a dictionary
            if log_data["requester_ip"] == "127.0.0.1" and \
               log_data["method"] == "GET" and \
               log_data["path"] == "/" and \
               log_data["headers"] == {"User-Agent": "Werkzeug/3.1.3", "Host": "localhost"} and \
               log_data["body"] == "" and \
               log_data["client_name"] == "" and \
               log_data["request_name"] == "" and \
               log_data["event"] == "Incoming Request":
                found = True
                break
        except (json.JSONDecodeError, KeyError):
            continue

    assert found, "Expected log message not found in the logged calls."

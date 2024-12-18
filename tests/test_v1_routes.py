import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_v1_tools_route(client):
    """Test a route in v1/tools/routes.py."""
    response = client.get('/v1/tools/GeneratePassphrase')
    assert response.status_code == 200
    assert b"response" in response.data

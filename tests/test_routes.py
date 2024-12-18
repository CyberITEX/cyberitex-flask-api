import pytest
from app import app
from common.utils.limiter import limiter

@pytest.fixture
def client():
    """Flask test client setup."""
    app.config['TESTING'] = True
    app.config['LIMITER_STORAGE'] = "memory://"  # Use in-memory storage for tests
    with app.test_client() as client:
        yield client

def test_home_route(client):
    """Test the home route."""
    response = client.get('/')
    assert response.status_code == 200
    assert b"Welcome to the CyberITEX API!" in response.data

def test_tools_route(client):
    """Test example GET route."""
    response = client.get('/v1/tools/')
    assert response.status_code == 200
    assert b"Welcome to CyberITEX Tools!" in response.data

def test_protected_route_without_api_key(client):
    """Test accessing a protected route without API key."""
    headers = {"Content-Type": "application/json"}  # Ensure proper headers
    response = client.post('/api', headers=headers)
    assert response.status_code == 401
    assert b"Invalid" in response.data

def test_protected_route_with_api_key(client):
    """Test accessing a protected route with a valid API key."""
    headers = {
        "Content-Type": "application/json",
        "X-API-Key": "valid-key"  # Replace with a valid key logic if implemented
    }
    response = client.post('/api', headers=headers)
    assert response.status_code == 200
    assert b"success" in response.data

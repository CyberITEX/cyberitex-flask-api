import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_404_error(client):
    """Test 404 error handler."""
    response = client.get('/nonexistent')
    assert response.status_code == 404
    assert b"The requested URL" in response.data

def test_405_error(client):
    """Test 405 error handler."""
    response = client.post('/')  # POST not allowed
    assert response.status_code == 405
    assert b"The method 'POST' is not allowed" in response.data

def test_401_error(client):
    """Test 401 Too Many Requests error handler."""
    response = client.post('/api')
    assert response.status_code == 401
    assert b"Invalid or missing API key" in response.data

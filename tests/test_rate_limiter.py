import pytest
from app import app
from common.utils.limiter import limiter


@pytest.fixture
def client():
    """Flask test client setup."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_limiter_initialization(client):
    """Test that the limiter applies rate limiting correctly."""
    # Simulate 5 allowed requests (rate limit: 5/minute)
    for _ in range(5):
        response = client.get('/limit')
        assert response.status_code == 200
        assert b"Sky is the limit" in response.data

    # The 6th request should trigger rate limiting (429 Too Many Requests)
    response = client.get('/limit')
    assert response.status_code == 429
    assert b"You have exceeded your rate-limit" in response.data

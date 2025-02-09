from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

# Create a Limiter instance
limiter = Limiter(
    key_func=get_remote_address
)

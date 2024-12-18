from functools import wraps
from flask import jsonify, request

def authenticate_api_key(api_key):
    return True
    # return cfg.verify_key().get(api_key, None)

# Custom authentication decorator
def require_api_key(func):
    @wraps(func)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get("X-API-Key")
        if not api_key or not authenticate_api_key(api_key):
            return jsonify({"response": "Invalid or missing API key"}), 401
        return func(*args, **kwargs)
    return decorated_function

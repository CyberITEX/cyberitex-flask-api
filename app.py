import logging
import os
import uuid
from logging.handlers import RotatingFileHandler

import structlog
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS

from common.utils.common_utils import require_api_key
from common.utils.limiter import limiter
from config import DevelopmentConfig, ProductionConfig
from v1.tasks.routes import tasks_routes
from v1.tools.routes import tools_routes
from redis import Redis

# Load environment variables
load_dotenv()


# Initialize the Flask application
app = Flask(__name__)

# Environment-based configuration
if os.getenv("FLASK_ENV") == "development":
    app.config.from_object(DevelopmentConfig)
else:
    app.config.from_object(ProductionConfig)


# Initialize Redis client using LIMITER_STORAGE
app.config["REDIS_CLIENT"] = Redis.from_url(app.config["LIMITER_STORAGE"])

# Validate critical environment variables
if not app.config["HOST"] or not app.config["PORT"]:
    raise ValueError("HOST and PORT environment variables must be set.")

# Register Blueprints
app.register_blueprint(tools_routes, url_prefix="/v1/tools")
app.register_blueprint(tasks_routes, url_prefix="/v1/tasks")

# Initialize Limiter
limiter.init_app(app)
limiter.storage_uri = app.config["LIMITER_STORAGE"]


# Configure CORS
CORS(
    app,
    resources={r"/*": {"origins": "*", "methods": ["GET", "POST"]}},
    supports_credentials=True,
)


# Setup structured logging and rotating file handler
def setup_logger(log_folder, log_file_name="api_logs"):
    # Ensure the log directory exists
    os.makedirs(log_folder, exist_ok=True)

    # Define log file path
    log_file_path = os.path.join(log_folder, f"{log_file_name}.log")

    # Standard Python logger with RotatingFileHandler
    max_log_size = 15 * 1024 * 1024  # 15MB
    handler = RotatingFileHandler(log_file_path, maxBytes=max_log_size, backupCount=5)
    handler.setFormatter(
        logging.Formatter("%(message)s")
    )  # Plain format (structlog handles formatting)

    # Setup structlog with RotatingFileHandler
    structlog.configure(
        processors=[
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),  # Logs as JSON
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    # Get the logger and attach RotatingFileHandler
    logger = logging.getLogger("api_logger")
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        logger.addHandler(handler)

    return structlog.wrap_logger(logger)


# Helper function to filter sensitive headers
def filter_headers(headers):
    sensitive_keys = {"Authorization", "X-Api-Key"}
    return {
        k: (v if k not in sensitive_keys else "REDACTED") for k, v in headers.items()
    }


@app.before_request
def log_request_info():
    request_id = str(uuid.uuid4())
    # Define log folder and logger
    log_folder = "logs"
    logger = setup_logger(log_folder)
    logger = logger.bind(request_id=request_id)

    # Extract client and request details
    client_name, request_name = "", "base"
    request_path = request.path.strip("/").split("/")
    request_path = [item for item in request_path if item not in ["v1"]]

    if len(request_path) == 1:
        request_name = request_path[0]
    elif len(request_path) >= 2:
        client_name, request_name = request_path[0], request_path[1]

    # Log request details
    requester_ip = request.remote_addr
    request_details = {
        "requester_ip": requester_ip,
        "method": request.method,
        "path": request.path,
        "headers": filter_headers(dict(request.headers)),
        "body": request.get_data(as_text=True),
        "client_name": client_name,
        "request_name": request_name,
    }

    logger.info("Incoming Request", **request_details)


# Define routes
@app.route("/", methods=["GET"])
def home():
    return jsonify(message="Welcome to the CyberITEX API!")


@app.route("/api", methods=["POST"])
@require_api_key
@limiter.limit("5/minute")  # Rate limiting: 5 requests per minute
def api():
    return jsonify(status="success", data="This is the API endpoint.")


@app.route("/limit", methods=["GET"])
@limiter.limit("5/minute")  # Rate limiting: 5 requests per minute
def limit():
    return jsonify(status="success", data="Sky is the limit")


@app.route("/health", methods=["GET"])
def health_check():
    # Check dependencies
    health_status = {
        "status": "healthy",
        "dependencies": {
            "database": False,
            "redis": False,
        },
    }

    try:
        # Check database connection (example using SQLAlchemy)
        # with app.config['DB_ENGINE'].connect() as conn:
        #     conn.execute("SELECT 1")
        health_status["dependencies"]["database"] = True
    except Exception:
        health_status["status"] = "unhealthy"

    try:
        # Check Redis connection
        if app.config["REDIS_CLIENT"].ping():
            health_status["dependencies"]["redis"] = True
    except Exception as e:
        health_status["status"] = "unhealthy"
        health_status["dependencies"]["redis"] = False
        print(f"Redis health check failed: {e}")

    # Return appropriate status code
    if health_status["status"] == "healthy":
        return jsonify(health_status), 200
    else:
        return jsonify(health_status), 500


@app.route('/liveness', methods=['GET'])
def liveness_check():
    return jsonify({"status": "alive"}), 200


@app.errorhandler(400)
def bad_request(e):
    return (
        jsonify(
            {
                "error": "Bad Request",
                "message": "The server could not understand the request due to invalid syntax or missing data.",
                "status_code": 400,
            }
        ),
        400,
    )


@app.errorhandler(404)
def page_not_found(e):
    return (
        jsonify(
            {
                "error": "Not Found",
                "message": f"The requested URL '{request.path}' was not found on this server.",
                "status_code": 404,
            }
        ),
        404,
    )


@app.errorhandler(429)
def ratelimit_exceeded(e):
    return (
        jsonify(
            {
                "error": "Too Many Requests",
                "message": "You have exceeded your rate-limit. Please try again later.",
                "status_code": 429,
            }
        ),
        429,
    )


@app.errorhandler(405)
def method_not_allowed(e):
    return (
        jsonify(
            {
                "error": "Method Not Allowed",
                "message": f"The method '{request.method}' is not allowed for this endpoint.",
                "status_code": 405,
            }
        ),
        405,
    )


@app.errorhandler(415)
def unsupported_media_type(e):
    return (
        jsonify(
            {
                "error": "Unsupported Media Type",
                "message": "The media type provided is not supported. Please check 'Content-Type' header.",
                "status_code": 415,
            }
        ),
        415,
    )


@app.errorhandler(401)
def unauthorized_error(e):
    return (
        jsonify(
            {
                "error": "Unauthorized",
                "message": "You are not authorized to access this resource. Please provide valid credentials.",
                "status_code": 401,
            }
        ),
        401,
    )


@app.errorhandler(500)
def internal_server_error(e):
    return (
        jsonify(
            {
                "error": "Internal Server Error",
                "message": "The server encountered an internal error and could not complete your request.",
                "status_code": 500,
            }
        ),
        500,
    )


# Run the application
if __name__ == "__main__":
    app.run(host=app.config["HOST"], port=app.config["PORT"], debug=app.config["DEBUG"])

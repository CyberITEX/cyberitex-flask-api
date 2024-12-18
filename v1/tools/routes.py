from common.utils.limiter import limiter
from flask import Blueprint, jsonify, request
from common.utils.common_utils import require_api_key


from .scripts import utils

# Blueprint for AdminHub
tools_routes = Blueprint("tools", __name__)


@tools_routes.route("/", methods=["GET"])
@limiter.limit("5/minute")
def home_tools():
    return jsonify({"message": "Welcome to CyberITEX Tools!"}), 200


@tools_routes.route("/GeneratePassphrase", methods=["GET"])
@limiter.limit("20/minute")
def GeneratePassphrase():
    password = utils.generate_passphrase()
    return jsonify({"response": password}), 200


@tools_routes.route('/add', methods=['POST'])
@require_api_key
@limiter.limit("5/minute")
def add_numbers():
    """
    Add two numbers sent in the JSON payload.
    Example JSON payload: { "num1": 5, "num2": 3 }
    """
    data = request.get_json()  # Parse JSON payload

    # Validate input
    if not data or 'num1' not in data or 'num2' not in data:
        return jsonify({"error": "Invalid input, please provide num1 and num2"}), 400

    try:
        num1 = float(data['num1'])
        num2 = float(data['num2'])
    except ValueError:
        return jsonify({"error": "Invalid numbers provided"}), 400

    # Perform addition
    result = num1 + num2

    return jsonify({"num1": num1, "num2": num2, "result": result}), 200
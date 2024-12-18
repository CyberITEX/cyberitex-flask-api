# CyberITEX Flask API

Welcome to the **CyberITEX Flask API**, a scalable and modular Flask-based API designed for extensibility and ease of integration. It includes support for rate limiting, structured logging, versioned routes, and custom error handling to ensure robust and secure API operations. 🚀

---

## **Key Features**
- ⚡ **Rate Limiting**: Powered by Flask-Limiter to control API usage effectively.
- ⛑ **API Key Authorization**: Secure sensitive endpoints with `X-API-Key` headers.
- 🔐 **Structured Logging**: Logs all incoming requests, including HTTP method, path, headers, and IP.
- ❓ **Custom Error Handling**: User-friendly responses for common errors (e.g., 404, 405, 429, 500).
- 🏠 **Environment-Specific Configurations**: Centralized configuration via `config.py` and `.env`.
- 📊 **Comprehensive Testing**: Unit tests for routes, error handlers, and middlewares using `pytest`.
- ⚒️ **Modular Structure**: Organized for easy maintenance and extensibility.

---

## **Quick Deployment on Cloud**
Easily deploy the API on a cloud server, such as AWS EC2 or Azure, using the included installation script.

### **Steps for AWS EC2 Deployment**

1. **Launch an EC2 Instance**:
   - Use an Ubuntu 20.04+ AMI.
   - Configure your security group to open port `5000` (or your defined `FLASK_PORT`).

2. **Add the User-Data Script**:
   Include the following in the user-data field:
   ### **Without a Custom User** (Defaults to `ubuntu`):
   ```bash
   #!/bin/bash
   set -e
   curl -sSL https://raw.githubusercontent.com/CyberITEX/cyberitex-flask-api/main/user-data/install.sh | bash
   ```

   ### **With a Custom User** (e.g., `alex`):
   ```bash
   #!/bin/bash
   set -e
   curl -sSL https://raw.githubusercontent.com/CyberITEX/cyberitex-flask-api/main/user-data/install.sh | bash -s -- alex
   ```

3. **Access Your API**:
   Once the instance is running, the API will be available on the configured port.

---

## **Manual Setup Instructions**

### **Prerequisites**
- Python 3.8+
- Redis (required for Flask-Limiter)
- Git
- Virtualenv (optional but recommended)

---

## **Installation**

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/CyberITEX/cyberitex-flask-api.git
   cd cyberitex-flask-api
   ```

2. **Set Up a Virtual Environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # For Linux/macOS
   venv\Scripts\activate   # For Windows
   ```

3. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Set Up Redis**:
   Ensure Redis is installed and running on port `6379`:
   ```bash
   sudo apt install redis
   sudo systemctl start redis
   sudo systemctl enable redis
   ```

5. **Configure Environment Variables**:
   Rename `example.env` to `.env` and define the following variables:
   ```plaintext
   FLASK_ENV=development
   SECRET_KEY=your-secret-key
   FLASK_PORT=5000
   ```

6. **Run the Application**:
   ```bash
   python app.py
   ```

---

## **API Endpoints**

### **General Routes**

| **Method** | **Endpoint**      | **Description**              |
|------------|-------------------|------------------------------|
| `GET`      | `/`               | Welcome message.             |
| `GET`      | `/example`        | Example endpoint.            |
| `POST`     | `/upload`         | Example for content upload.  |

### **Protected Routes**

| **Method** | **Endpoint**      | **Description**              |
|------------|-------------------|------------------------------|
| `GET`      | `/protected`      | Access protected resources.  |

**Headers Required**:
- `X-API-Key`: Your API key.
- `Content-Type`: `application/json`.

---

## **Error Handling**
The API provides structured error responses for common issues:

| **HTTP Code** | **Error**                     | **Message**                                                                 |
|---------------|-------------------------------|-----------------------------------------------------------------------------|
| `400`         | Bad Request                  | Invalid syntax or missing data.                                            |
| `401`         | Unauthorized                 | API key is missing or invalid.                                             |
| `404`         | Not Found                    | The requested URL was not found.                                           |
| `405`         | Method Not Allowed           | The HTTP method is not allowed for the requested endpoint.                 |
| `415`         | Unsupported Media Type       | Content type is unsupported. Check the `Content-Type` header.              |
| `429`         | Too Many Requests            | Exceeded the rate limit.                                                   |
| `500`         | Internal Server Error        | An unexpected server error occurred.                                       |

---

## **Testing**

1. **Run All Tests**:
   ```bash
   pytest
   ```

2. **Run Tests with Coverage**:
   ```bash
   pytest --cov=./ --cov-report=html
   ```

3. **Test Structure**:
   - `tests/test_routes.py`: Tests for API endpoints.
   - `tests/test_error_handlers.py`: Tests custom error handlers.
   - `tests/test_logging.py`: Tests the logging middleware.

---

## **Project Structure**

```plaintext
cyberitex-flask-api/
├── .env                  # Environment variables
├── app.py                # Main application file
├── config.py             # Configuration settings
├── requirements.txt      # Python dependencies
├── common/               # Shared utilities
│   ├── __init__.py
│   └── utils/
│       ├── common_utils.py
│       └── limiter.py
├── tests/                # Unit tests
│   ├── test_error_handlers.py
│   ├── test_logging.py
│   ├── test_rate_limiter.py
│   └── test_routes.py
├── v1/                   # Versioned routes
│   ├── routes.py
│   └── tools/
│       └── scripts/
│           └── utils.py
└── logs/                 # Log files
```

---

## **License**
This project is licensed under the MIT License. See the `LICENSE` file for more details. 📚


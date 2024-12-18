# Project Structure: CyberITEX Flask API

This document outlines the structure of the **CyberITEX Flask API** project, providing descriptions of key files and directories for better understanding and navigation.

---

## **Directory Overview**

```
cyberitex-flask-api/
├── app.py                     # Main Flask application entry point
├── config.py                  # Configuration settings for the app
├── requirements.txt           # Project dependencies
├── .env                       # Environment variables file
├── README.md                  # Project documentation
├── structure.md               # Project structure overview
├── logs/                      # Directory for application logs
│   └── ...                    # Log files generated during runtime
├── common/                    # Shared utilities and helpers
│   ├── __init__.py            # Initializes the 'common' package
│   └── utils/
│       ├── limiter.py         # Rate limiter configuration (Flask-Limiter)
│       ├── common_utils.py    # General utility functions
│       └── __init__.py        # Initializes the 'utils' package
├── tests/                     # Unit tests for the application
│   ├── test_routes.py         # Tests for API routes
│   ├── test_logging.py        # Tests for request logging
│   ├── test_limiter.py        # Tests for rate limiting functionality
│   ├── test_tasks.py          # Tests for Celery background tasks
│   ├── test_error_handlers.py # Tests for custom error handlers
│   └── __init__.py            # Initializes the 'tests' package
├── v1/                        # Versioned API directory (v1)
│   ├── __init__.py            # Initializes the 'v1' package
│   ├── routes.py              # Main v1 routes (base API)
│   ├── tasks/                 # Celery background task routes
│   │   ├── routes.py          # Task-specific routes
│   │   ├── __init__.py        # Initializes the 'tasks' package
│   │   └── scripts/           # Supporting scripts for tasks
│   │       ├── utils.py       # Task-specific utilities
│   │       └── __init__.py    # Initializes the 'scripts' package
│   └── tools/                 # Tools-specific routes
│       ├── routes.py          # Routes for tools APIs
│       ├── __init__.py        # Initializes the 'tools' package
│       └── scripts/           # Supporting scripts for tools
│           ├── utils.py       # Tools-specific utilities
│           └── __init__.py    # Initializes the 'scripts' package
└── systemd/                   # Systemd service files for production
│   ├── api.service            # Gunicorn systemd service (serves the API)
│   └── celery.service         # Celery worker systemd service
└── venv/                      # Virtual environment directory (excluded from version control)
```

---

## **File and Directory Descriptions**

### **1. Root Files**
- **`app.py`**: 
  - Main application entry point.
  - Initializes the Flask app, registers blueprints, rate limiter, error handlers, and CORS settings.

- **`config.py`**: 
  - Contains configuration classes for `Development`, `Production`, and shared settings.
  - Loads environment variables from `.env`.

- **`requirements.txt`**: 
  - Lists all Python dependencies required to run the application.

- **`.env`**: 
  - Stores environment variables such as `FLASK_ENV`, `SECRET_KEY`, and `FLASK_PORT`.

- **`README.md`**: 
  - Detailed setup instructions, API documentation, and testing guidelines.

- **`structure.md`**: 
  - Provides an overview of the project directory structure.


---

### **2. `logs/`**
- Contains application logs organized by modules and request names.
- Logs include request details like IP address, headers, and paths.

---

### **3. `tests/`**
- Unit and integration tests to validate API functionality, error handling, rate limiting, and utilities.

| **Test File**               | **Purpose**                                  |
|-----------------------------|----------------------------------------------|
| `test_routes.py`            | Tests for API endpoints (`/`, `/api`, etc.). |
| `test_error_handlers.py`    | Tests for custom error responses (404, 429). |
| `test_logging.py`           | Verifies request logging functionality.      |
| `test_rate_limiter.py`      | Checks rate-limiting behavior.               |
| `test_limiter.py`           | Tests limiter initialization and setup.      |
| `test_common_utils.py`      | Tests utility functions in `common/utils`.   |

---

### **4. `common/`**
- Shared utility modules used across the project.

| **File**                | **Purpose**                                            |
|-------------------------|--------------------------------------------------------|
| `limiter.py`            | Configures Flask-Limiter for rate limiting.            |
| `common_utils.py`       | General-purpose utility functions.                     |

---

### **5. `v1/`**
- Versioned API routes for `v1` of the application.

| **File/Directory**      | **Purpose**                                            |
|-------------------------|--------------------------------------------------------|
| `routes.py`             | Defines primary routes for `v1`.                       |
| `tools/routes.py`       | Defines tools-related API routes.                      |
| `tools/scripts/utils.py`| Utility functions specific to tools functionality.     |

---

### **6. `venv/`**
- Virtual environment directory for isolating dependencies.
- Excluded from version control (listed in `.gitignore`).

---

## **Notes**
- The `tests/` directory is essential for ensuring code quality and validating API functionality.
- Logs are stored in `logs/` for debugging and monitoring purposes.
- Versioned routes allow for easy API scalability and backward compatibility.

---

## **Exclusions**
Add the following to `.gitignore` to avoid unnecessary files in version control:

```
venv/
__pycache__/
logs/
.env
*.log
```

---

This structure ensures the project is modular, testable, and scalable.

# CyberITEX API Routes Documentation

## **1. `/v1/tools` (GET)**
- **Description**: Welcome endpoint for tools.
- **Rate Limit**: `5/minute`.
- **Request**:
  ```http
  GET /v1/tools
  ```
- **Response**:
  ```json
  {
    "message": "Welcome to CyberITEX Tools!"
  }
  ```

---

## **2. `/v1/tools/GeneratePassphrase` (GET)**
- **Description**: Generates a random passphrase.
- **Rate Limit**: `20/minute`.
- **Request**:
  ```http
  GET /v1/tools/GeneratePassphrase
  ```
- **Response**:
  ```json
  {
    "response": "random-passphrase-here"
  }
  ```

---

## **3. `/v1/tools/add` (POST)**
- **Description**: Adds two numbers provided in the request JSON payload.
- **Rate Limit**: `5/minute`.
- **Authentication**: Requires an API key.
- **Request**:
  ```http
  POST /v1/tools/add
  Content-Type: application/json
  {
    "num1": 5,
    "num2": 3
  }
  ```
- **Response**:
  ```json
  {
    "num1": 5,
    "num2": 3,
    "result": 8
  }
  ```

---

## **4. `/v1/tasks` (GET)**
- **Description**: Welcome endpoint for tasks.
- **Rate Limit**: `5/minute`.
- **Request**:
  ```http
  GET /v1/tasks
  ```
- **Response**:
  ```json
  {
    "message": "Welcome to CyberITEX tasks!"
  }
  ```

---

## **5. `/v1/tasks/RunBackgroundTask` (GET)**
- **Description**: Starts a background task using Celery.
- **Rate Limit**: `20/minute`.
- **Request**:
  ```http
  GET /v1/tasks/RunBackgroundTask
  ```
- **Response**:
  ```json
  {
    "response": "task-id-here"
  }
  ```

---

## **6. `/v1/tasks/status/<task_id>` (GET)**
- **Description**: Retrieves the status of a specific Celery task by its ID.
- **Rate Limit**: `30/minute`.
- **Request**:
  ```http
  GET /v1/tasks/status/abc123-task-id
  ```
- **Response States**:

  **PENDING** (task is queued or unknown):
  ```json
  {
    "task_id": "abc123-task-id",
    "state": "PENDING",
    "message": "Task is pending or unknown"
  }
  ```

  **STARTED** (task is running):
  ```json
  {
    "task_id": "abc123-task-id",
    "state": "STARTED",
    "message": "Task has started"
  }
  ```

  **SUCCESS** (task completed):
  ```json
  {
    "task_id": "abc123-task-id",
    "state": "SUCCESS",
    "result": "task-result-here"
  }
  ```

  **FAILURE** (task failed):
  ```json
  {
    "task_id": "abc123-task-id",
    "state": "FAILURE",
    "error": "Error message describing what went wrong"
  }
  ```

  **REVOKED** (task was cancelled):
  ```json
  {
    "task_id": "abc123-task-id",
    "state": "REVOKED",
    "message": "Task was revoked"
  }
  ```

---

## **8. `/v1/tasks/GetPendingRequests` (GET)**
- **Description**: Inspects Celery workers and retrieves all active, scheduled, and reserved tasks.
- **Authentication**: Requires an API key.
- **Request**:
  ```http
  GET /v1/tasks/GetPendingRequests
  ```
- **Response** (example with pending tasks):
  ```json
  {
    "response": [
      {
        "task_id": "task-id-1",
        "state": "STARTED",
        "worker": "celery@hostname",
        "type": "active"
      },
      {
        "task_id": "task-id-2",
        "state": "PENDING",
        "worker": "celery@hostname",
        "type": "scheduled"
      }
    ]
  }
  ```

---

## **9. `/health` (GET)**
- **Description**: API health check endpoint.
- **Rate Limit**: `5/minute`.
- **Request**:
  ```http
  GET /health
  ```
- **Response**:
  ```json
  {
    "status": "healthy",
    "redis": "connected",
    "uptime": "00:10:30"
  }
  ```

--- 

# **Features**

### **Rate Limiting**
- **Purpose**: Protects API endpoints from abuse by limiting request rates.
- **Example**: `@limiter.limit("5/minute")` restricts to 5 requests per minute per client.

### **API Key Authentication**
- **Purpose**: Secures sensitive endpoints by requiring valid API keys.
- **Usage**: Include an `X-API-KEY` header with your requests.

### **Background Tasks**
- **Tool**: Celery
- **Functionality**: Asynchronous task execution with Redis as the broker.

### **Health Check**
- **Purpose**: Provides real-time status of the API and its dependencies (e.g., Redis).


### **Logging**
- **Mechanism**: Uses `RotatingFileHandler` and `structlog` for structured logs.
- **Configuration**: Logs are stored in a specified directory with a maximum size of 15MB per file and up to 5 backup files.

### **Environment-Specific Configuration**
- **Development**: Configured using `DevelopmentConfig`.
- **Production**: Configured using `ProductionConfig`.
- **Critical Variables**:
  - `HOST`: API host address.
  - `PORT`: API port.
  - `LIMITER_STORAGE`: Redis URL for rate limiter storage.

---

# **Example API Key Header**

For routes requiring API key authentication, include the following header:

```http
X-API-KEY: your-api-key-here
```

---

# **Error Handling**

### **Common Error Responses**

1. **Invalid Input**:
   - **Status Code**: `400 Bad Request`
   - **Response**:
     ```json
     {
       "error": "Invalid input, please provide num1 and num2"
     }
     ```

2. **Unauthorized Access**:
   - **Status Code**: `401 Unauthorized`
   - **Response**:
     ```json
     {
       "error": "Unauthorized, invalid API key"
     }
     ```

3. **Rate Limit Exceeded**:
   - **Status Code**: `429 Too Many Requests`
   - **Response**:
     ```json
     {
       "error": "Rate limit exceeded"
     }
     ```

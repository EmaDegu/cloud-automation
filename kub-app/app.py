#from flask import Flask
#pp = Flask(__name__)

#@app.route("/")
#def home():
 #   return "Internal application for employees of the company"

#app.run(host="0.0.0.0", port=5000)





from flask import Flask, request, jsonify
import os
import socket
import time
import uuid
import json
import traceback
from datetime import datetime, timezone

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "cs3-hrm-app")
ENVIRONMENT = os.getenv("ENVIRONMENT", "local")
PORT = int(os.getenv("PORT", "5000"))

def utc_iso():
    return datetime.now(timezone.utc).isoformat()

def log_json(level: str, event: str, **fields):
    """
    Emit one JSON log line to stdout. This is container/Kubernetes friendly.
    """
    payload = {
        "timestamp": utc_iso(),
        "level": level,
        "event": event,
        "app": APP_NAME,
        "environment": ENVIRONMENT,
        **fields,
    }
    print(json.dumps(payload, ensure_ascii=False))

@app.before_request
def start_request():
    # 1) Request ID: accept upstream one if present, else generate.
    request_id = request.headers.get("X-Request-Id") or str(uuid.uuid4())
    g.request_id = request_id

    # 2) Start timer
    g.start_time = time.time()

@app.after_request
def log_request(response):
    # 3) Log one request-completed line per request
    duration_ms = int((time.time() - g.start_time) * 1000)

    log_json(
        "INFO",
        "request_completed",
        request_id=g.request_id,
        method=request.method,
        path=request.path,
        status=response.status_code,
        duration_ms=duration_ms,
        client_ip=request.remote_addr,
        user_agent=request.headers.get("User-Agent"),
        hostname=socket.gethostname(),
    )

    # 4) Return request id to client for correlation (optional but strong)
    response.headers["X-Request-Id"] = g.request_id
    return response

@app.errorhandler(Exception)
def handle_exception(e):
    # 5) Log exception with stack trace
    log_json(
        "ERROR",
        "unhandled_exception",
        request_id=getattr(g, "request_id", None),
        method=request.method if request else None,
        path=request.path if request else None,
        error=str(e),
        stacktrace=traceback.format_exc()
    )

    # Return generic error response (don’t leak internals)
    return jsonify({"error": "internal_server_error"}), 500

@app.get("/")
def home():
    return jsonify({
        "message": "CS3 Flask App is running",
        "hostname": socket.gethostname(),
        "time_utc": utc_iso(),
        "request_id": g.request_id
    })

@app.get("/health")
def health():
    return "ok", 200

@app.get("/error-demo")
def error_demo():
    # Trigger an exception to prove error logging works
    raise RuntimeError("Demo error for logging pipeline")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)

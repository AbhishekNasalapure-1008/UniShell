"""UniShell web application (Flask).

The CLI (unishell.sh) is untouched and still works on its own. This app adds a
REST API over the same data files and serves the static frontend, so both
interfaces share one source of truth.

Start it from the project root:

    backend/.venv/bin/python -m backend.app

Every API route answers with JSON. No endpoint runs a shell command: the
services use the standard library only, and every file operation is confined to
./sandbox.
"""

from pathlib import Path

from flask import Flask, jsonify, send_from_directory

from backend.routes.commands import commands_bp
from backend.routes.files import files_bp
from backend.routes.permissions import permissions_bp
from backend.routes.quiz import quiz_bp

BASE_DIR = Path(__file__).resolve().parents[1]
FRONTEND_DIR = BASE_DIR / "frontend"

# The frontend is plain HTML/CSS/JS served from the same origin as the API, so
# the browser needs no CORS setup. Assets are requested under /static.
app = Flask(__name__, static_folder=str(FRONTEND_DIR), static_url_path="/static")

for blueprint in (commands_bp, files_bp, permissions_bp, quiz_bp):
    app.register_blueprint(blueprint)

ENDPOINTS = {
    "commands": [
        "GET /api/commands?q=&category=",
        "GET /api/commands/search?q=",
        "GET /api/commands/categories",
        "GET /api/commands/<name>",
    ],
    "files": [
        "GET /api/files?path=",
        "GET /api/files/content?path=",
        "GET /api/files/stats",
        "POST /api/files {path, content}",
        "POST /api/files/directory {path, parents}",
        "PUT /api/files/content {path, content, confirm}",
        "POST /api/files/rename {path, new_name}",
        "DELETE /api/files {path, confirm}",
    ],
    "permissions": [
        "GET /api/permissions/list?path=",
        "GET /api/permissions/explain",
        "GET /api/permissions?path=",
        "PUT /api/permissions {path, mode}",
    ],
    "quiz": [
        "GET /api/quiz/info",
        "GET /api/quiz/questions",
        "POST /api/quiz/submit {answers}",
    ],
    "system": [
        "GET /api/health",
    ],
}


@app.route("/")
def home():
    """Serve the dashboard."""
    return send_from_directory(FRONTEND_DIR, "index.html")


@app.route("/api")
def api_index():
    """Describe the API, so the old JSON entry point is still available."""
    return jsonify({
        "application": "UniShell Web API",
        "status": "running",
        "message": "Welcome to the UniShell REST API",
        "endpoints": ENDPOINTS,
    })


@app.route("/api/health")
def health():
    return jsonify({
        "success": True,
        "status": "healthy"
    })


@app.errorhandler(404)
def not_found(error):
    return jsonify({
        "success": False,
        "message": "Not found"
    }), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        "success": False,
        "message": "Internal server error"
    }), 500


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)

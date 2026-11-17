"""Small helpers shared by the API blueprints.

Every endpoint must answer with JSON, even when something goes wrong, so the
frontend never has to parse an HTML error page. The service layer raises
errors that already carry the status code the API should return; anything else
is reported as a plain 500.
"""

from functools import wraps

from flask import jsonify


def error_response(message, status):
    """Build the standard error body: {"success": false, "message": ...}."""
    return jsonify({"success": False, "message": message}), status


def handle_errors(view):
    """Turn an exception raised by a service function into a JSON response."""

    @wraps(view)
    def wrapper(*args, **kwargs):
        try:
            return view(*args, **kwargs)
        except Exception as exc:  # the API must always answer with JSON
            status = getattr(exc, "status", None)
            message = getattr(exc, "message", None)
            if status and message:
                return error_response(message, status)
            if isinstance(exc, OSError):
                return error_response(
                    "The operation failed: " + (exc.strerror or "unknown error"), 500
                )
            return error_response("Internal server error", 500)

    return wrapper

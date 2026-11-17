"""Quiz endpoints.

    GET  /api/quiz/info        how many questions there are and their topics
    GET  /api/quiz/questions   the questions, without the answers
    POST /api/quiz/submit      score an attempt {answers: {"q1": "B", ...}}

The answers and the explanations are only returned by /submit, so the browser
cannot read them before an attempt has been made. Scoring happens here, not in
the browser, which is why the same numbers can be trusted.
"""

from flask import Blueprint, jsonify, request

from backend.routes.api_utils import handle_errors
from backend.services import quiz_service

quiz_bp = Blueprint("quiz", __name__, url_prefix="/api/quiz")


@quiz_bp.route("/info", methods=["GET"])
@handle_errors
def info():
    return jsonify({"success": True, **quiz_service.get_info()})


@quiz_bp.route("/questions", methods=["GET"])
@handle_errors
def questions():
    items = quiz_service.get_questions()

    return jsonify({"success": True, "total": len(items), "questions": items})


@quiz_bp.route("/submit", methods=["POST"])
@handle_errors
def submit():
    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({"success": False, "message": "A JSON body is required."}), 400

    result = quiz_service.grade(data.get("answers"))

    return jsonify({"success": True, **result})

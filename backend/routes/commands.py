"""Command library endpoints.

    GET /api/commands                 every command, with optional filters
    GET /api/commands/search?q=       names that contain the query
    GET /api/commands/categories      the syllabus categories that exist
    GET /api/commands/<name>          one command, with its fields and its
                                      original text block

The endpoints and the response keys used before are kept, so the older
frontend code keeps working; the "items" key adds the parsed fields.
"""

from flask import Blueprint, jsonify, request

from backend.routes.api_utils import handle_errors
from backend.services.command_service import (
    count_commands,
    filter_commands,
    get_all_commands,
    get_categories,
    get_command,
    get_command_details,
    search_commands,
)

commands_bp = Blueprint("commands", __name__, url_prefix="/api/commands")


@commands_bp.route("", methods=["GET"])
@handle_errors
def list_commands():
    query = request.args.get("q", "")
    category = request.args.get("category", "")

    records = filter_commands(query=query, category=category)
    names = get_all_commands()

    return jsonify({
        "success": True,
        "total": len(names),
        "returned": len(records),
        "commands": names,
        "items": records,
        "filters": {"q": query, "category": category},
    })


@commands_bp.route("/search", methods=["GET"])
@handle_errors
def search():
    query = request.args.get("q", "")

    return jsonify({
        "success": True,
        "query": query,
        "results": search_commands(query),
        "items": filter_commands(query=query),
    })


@commands_bp.route("/categories", methods=["GET"])
@handle_errors
def categories():
    details = get_categories()

    return jsonify({
        "success": True,
        "categories": [item["name"] for item in details],
        "details": details,
        "total_commands": count_commands(),
    })


@commands_bp.route("/<name>", methods=["GET"])
@handle_errors
def explain_command(name):
    command = get_command(name)

    if command is None:
        return jsonify({
            "success": False,
            "message": "Command not found"
        }), 404

    return jsonify({
        "success": True,
        "command": name,
        "fields": command,
        "details": get_command_details(name),
    })

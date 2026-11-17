"""File management endpoints, all confined to ./sandbox.

    GET    /api/files?path=        list a directory
    GET    /api/files/content?path= read one file
    POST   /api/files              create a file          {path, content?}
    POST   /api/files/directory    create a directory     {path, parents?}
    PUT    /api/files/content      write a file           {path, content, confirm?}
    POST   /api/files/rename       rename an entry        {path, new_name}
    DELETE /api/files              delete an entry        {path, confirm: true}
    GET    /api/files/stats        counts for the dashboard

Every path is validated inside file_service before anything is touched, and no
endpoint ever runs a shell command.
"""

from flask import Blueprint, jsonify, request

from backend.routes.api_utils import handle_errors
from backend.services import file_service

files_bp = Blueprint("files", __name__, url_prefix="/api/files")


def _body():
    """Read the JSON body, treating a missing or invalid body as empty."""
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


@files_bp.route("", methods=["GET"])
@handle_errors
def list_entries():
    listing = file_service.list_dir(request.args.get("path", ""))

    return jsonify({"success": True, **listing})


@files_bp.route("/content", methods=["GET"])
@handle_errors
def read_entry():
    path = request.args.get("path", "")

    if not path:
        return jsonify({"success": False, "message": "A path is required."}), 400

    content = file_service.read_file(path)

    return jsonify({"success": True, **content})


@files_bp.route("", methods=["POST"])
@handle_errors
def create_entry():
    data = _body()
    result = file_service.create_file(data.get("path", ""), data.get("content", ""))

    return jsonify({
        "success": True,
        "message": "Created %s." % result["entry"]["path"],
        **result,
    }), 201


@files_bp.route("/directory", methods=["POST"])
@handle_errors
def create_directory():
    data = _body()
    result = file_service.create_dir(
        data.get("path", ""), parents=bool(data.get("parents", False))
    )

    return jsonify({
        "success": True,
        "message": "Created the directory %s." % result["entry"]["path"],
        **result,
    }), 201


@files_bp.route("/content", methods=["PUT"])
@handle_errors
def write_entry():
    data = _body()

    if "content" not in data:
        return jsonify({"success": False, "message": "Content is required."}), 400

    result = file_service.write_file(
        data.get("path", ""),
        data.get("content", ""),
        confirm=bool(data.get("confirm", False)),
    )

    return jsonify({
        "success": True,
        "message": ("Saved %s." % result["entry"]["path"]) if result["created"]
                   else ("Replaced the content of %s." % result["entry"]["path"]),
        **result,
    })


@files_bp.route("/rename", methods=["POST"])
@handle_errors
def rename_entry():
    data = _body()
    result = file_service.rename(data.get("path", ""), data.get("new_name", ""))

    return jsonify({
        "success": True,
        "message": "Renamed %s to %s." % (result["from"], result["entry"]["name"]),
        **result,
    })


@files_bp.route("", methods=["DELETE"])
@handle_errors
def delete_entry():
    data = _body()
    result = file_service.delete(
        data.get("path", ""), confirm=bool(data.get("confirm", False))
    )

    return jsonify({
        "success": True,
        "message": "Deleted %s." % result["path"],
        **result,
    })


@files_bp.route("/stats", methods=["GET"])
@handle_errors
def sandbox_stats():
    return jsonify({"success": True, **file_service.stats()})

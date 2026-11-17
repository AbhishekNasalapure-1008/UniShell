"""Permission endpoints, all confined to ./sandbox.

    GET /api/permissions/list?path=   every entry with its mode, for the list
    GET /api/permissions/explain      how ls -l, stat and the bits work
    GET /api/permissions?path=        the mode of one entry
    PUT /api/permissions              apply a mode  {path, mode: "644"}

The mode must be three octal digits and the path must resolve inside ./sandbox,
which is the same limit modules/permissions.sh keeps in the CLI. chown is
explained by /explain but never executed.
"""

from flask import Blueprint, jsonify, request

from backend.routes.api_utils import handle_errors
from backend.services import permission_service

permissions_bp = Blueprint("permissions", __name__, url_prefix="/api/permissions")


def _body():
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


@permissions_bp.route("/list", methods=["GET"])
@handle_errors
def list_entries():
    listing = permission_service.list_permissions(request.args.get("path", ""))

    return jsonify({"success": True, **listing})


@permissions_bp.route("/explain", methods=["GET"])
@handle_errors
def explain_permissions():
    return jsonify({"success": True, **permission_service.explain()})


@permissions_bp.route("", methods=["GET"])
@handle_errors
def one_entry():
    path = request.args.get("path", "")

    if not path:
        return jsonify({"success": False, "message": "A path is required."}), 400

    info = permission_service.permission_info(path)

    return jsonify({"success": True, **info})


@permissions_bp.route("", methods=["PUT"])
@handle_errors
def change_mode():
    data = _body()
    result = permission_service.set_mode(data.get("path", ""), data.get("mode", ""))

    message = (
        "Mode changed from %s to %s."
        % (result["before"]["octal"], result["after"]["octal"])
        if result["changed"]
        else "The mode was already %s." % result["after"]["octal"]
    )

    return jsonify({"success": True, "message": message, **result})

"""Permission information and safe chmod for the UniShell web interface.

This is the web twin of modules/permissions.sh. It reports exactly what the CLI
reports - the symbolic mode from ls -l, the numeric mode from stat, the owner
and the group - and it explains the read/write/execute bits in the same words.

Two deliberate limits are kept from the CLI:

  * chmod only ever runs on a path inside ./sandbox, and never on the sandbox
    folder itself;
  * chown is explained but never executed, because changing an owner normally
    needs root.

No shell is started: os.chmod is called directly, and the mode must be three
octal digits.
"""

import grp
import os
import pwd
import re
import stat as stat_module

from backend.services.file_service import (
    SANDBOX,
    FileServiceError,
    list_dir,
    rel_of,
    resolve_path,
)

_MODE_RE = re.compile(r"^[0-7]{3}$")

RIGHTS = ("read", "write", "execute")
WHO_LABELS = {
    "owner": "The owner",
    "group": "The group",
    "others": "Everyone else",
}


def _names(uid, gid):
    try:
        owner = pwd.getpwuid(uid).pw_name
    except KeyError:
        owner = str(uid)

    try:
        group = grp.getgrgid(gid).gr_name
    except KeyError:
        group = str(gid)

    return owner, group


def _kind(mode):
    if stat_module.S_ISDIR(mode):
        return "directory"
    if stat_module.S_ISLNK(mode):
        return "symlink"
    if stat_module.S_ISREG(mode):
        return "file"
    return "other"


def _triple(digit):
    return {
        "read": bool(digit & 4),
        "write": bool(digit & 2),
        "execute": bool(digit & 1),
    }


def describe(path):
    """Return the symbolic mode, numeric mode, owner, group and bits of a path."""
    info = path.lstat()
    mode = stat_module.S_IMODE(info.st_mode)
    owner, group = _names(info.st_uid, info.st_gid)

    return {
        "path": rel_of(path),
        "name": path.name,
        "type": _kind(info.st_mode),
        "symbolic": stat_module.filemode(info.st_mode),
        "octal": format(mode, "03o"),
        "owner": owner,
        "group": group,
        "size": info.st_size,
        "bits": {
            "owner": _triple((mode >> 6) & 7),
            "group": _triple((mode >> 3) & 7),
            "others": _triple(mode & 7),
        },
    }


def _join(words):
    if len(words) == 1:
        return words[0]
    if len(words) == 2:
        return words[0] + " and " + words[1]
    return ", ".join(words[:-1]) + " and " + words[-1]


def summarise(bits):
    """Plain-English reading of the three groups of rights."""
    lines = []

    for who in ("owner", "group", "others"):
        allowed = [right for right in RIGHTS if bits[who][right]]
        if allowed:
            lines.append("%s may %s." % (WHO_LABELS[who], _join(allowed)))
        else:
            lines.append("%s has no rights." % WHO_LABELS[who])

    return lines


def permission_info(rel):
    """Permissions of one entry inside the sandbox."""
    path = resolve_path(rel)

    if not path.exists():
        raise FileServiceError("There is nothing at that path.", 404)

    info = describe(path)
    info["summary"] = summarise(info["bits"])
    return info


def list_permissions(rel=""):
    """Every entry of a directory with its mode, for the visual list."""
    listing = list_dir(rel)
    entries = []

    for item in listing["entries"]:
        if item["type"] == "symlink":
            entries.append({
                "name": item["name"],
                "path": item["path"],
                "type": item["type"],
                "symbolic": "l" + item["mode"],
                "octal": item["mode"],
                "bits": None,
                "owner": None,
                "group": None,
            })
            continue

        info = describe(resolve_path(item["path"]))
        entries.append({
            "name": info["name"],
            "path": info["path"],
            "type": info["type"],
            "symbolic": info["symbolic"],
            "octal": info["octal"],
            "bits": info["bits"],
            "owner": info["owner"],
            "group": info["group"],
        })

    return {"path": listing["path"], "entries": entries, "count": len(entries)}


def set_mode(rel, mode):
    """Apply one numeric mode (three octal digits) to a path inside the sandbox."""
    if not isinstance(mode, str) or not _MODE_RE.match(mode):
        raise FileServiceError(
            "The mode must be three octal digits, for example 644.", 400
        )

    path = resolve_path(rel)

    if path == SANDBOX:
        raise FileServiceError("The sandbox folder's own mode is left alone.", 400)
    if not path.exists():
        raise FileServiceError("There is nothing at that path.", 404)

    before = describe(path)
    os.chmod(path, int(mode, 8))
    after = describe(path)

    return {
        "before": before,
        "after": after,
        "changed": before["octal"] != after["octal"],
    }


def explain():
    """The teaching text, mirroring what the CLI prints in its demos."""
    return {
        "ls_l": {
            "example": "-rw-r--r--",
            "parts": [
                {"chars": "1", "meaning": "the type: - a file, d a directory, l a symbolic link"},
                {"chars": "2-4", "meaning": "the OWNER's read, write and execute rights"},
                {"chars": "5-7", "meaning": "the GROUP's read, write and execute rights"},
                {"chars": "8-10", "meaning": "OTHERS' read, write and execute rights"},
            ],
        },
        "rights": [
            {"letter": "r", "name": "read", "file": "open and read the file",
             "directory": "list the names inside"},
            {"letter": "w", "name": "write", "file": "change the file's content",
             "directory": "create and remove entries"},
            {"letter": "x", "name": "execute", "file": "run it as a program",
             "directory": "enter the directory"},
        ],
        "numeric": [
            {"value": 4, "right": "read"},
            {"value": 2, "right": "write"},
            {"value": 1, "right": "execute"},
        ],
        "rules": [
            "A dash means the right is refused; a letter means it is allowed.",
            "Add the values for each group, so 6 = read + write and 7 = read + write + execute.",
            "644 gives the owner read and write, while the group and everyone else may only read.",
            "755 gives the owner everything, and the group and everyone else read plus execute.",
            "umask is subtracted from the maximum: files start from 666 and directories from 777.",
            "A directory also needs x, otherwise you cannot enter it even when you may read its name.",
            "chown changes the owner or the group and normally needs root, so it is explained but never run here.",
        ],
    }

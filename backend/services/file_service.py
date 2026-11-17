"""Sandboxed file operations for the UniShell web interface.

The rules are the ones modules/files.sh already enforces in the CLI:

  * an absolute path is refused up front;
  * every part of a relative path must pass is_safe_name() - no slash inside a
    part, no space, no leading dash, and never "." or "..";
  * the resolved path must still live inside ./sandbox, checked a second time
    after symlinks have been followed.

Nothing in this module starts a shell or runs anything a user typed: the
standard library performs every operation. Destructive actions are never
automatic - deleting requires an explicit confirmation flag.
"""

import os
import re
import stat
from datetime import datetime
from pathlib import Path

# Locate the UniShell project directory (backend/services/ -> project root).
BASE_DIR = Path(__file__).resolve().parents[2]
SANDBOX = (BASE_DIR / "sandbox").resolve()

# Never stream a whole large file into a JSON response.
MAX_READ_BYTES = 256 * 1024

# Keeps the empty folder visible to git, exactly as the CLI does.
KEEP_NAME = ".gitkeep"

_BANNED_CHARS = "/\\"
_DRIVE_RE = re.compile(r"^[A-Za-z]:")


class FileServiceError(Exception):
    """An error that already carries the HTTP status the API should return."""

    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status


# ------------------------------------------------------------
# Path safety
# ------------------------------------------------------------

def is_safe_name(name):
    """Mirror of is_safe_name() from lib/common.sh."""
    if not isinstance(name, str):
        return False
    if name == "" or name in (".", ".."):
        return False
    if name.startswith("-"):
        return False
    if any(ch in _BANNED_CHARS for ch in name):
        return False
    if any(ch.isspace() for ch in name):
        return False
    if any(not ch.isprintable() for ch in name):
        return False
    return len(name) <= 64


def ensure_sandbox():
    """Create ./sandbox when it is missing, like ensure_runtime_dirs() does."""
    SANDBOX.mkdir(parents=True, exist_ok=True)


def _ensure_inside(path):
    """Second, independent check: the resolved path must be inside ./sandbox."""
    real = Path(path).resolve()
    root = str(SANDBOX)
    if str(real) != root and not str(real).startswith(root + os.sep):
        raise FileServiceError("Refused: that path is not inside ./sandbox.", 403)
    return real


def resolve_path(rel, allow_root=False):
    """Return the real path of a relative path inside ./sandbox.

    Raises FileServiceError(400) for missing or absolute paths and
    FileServiceError(403) for anything that tries to leave the sandbox.
    """
    if rel is None:
        rel = ""
    if not isinstance(rel, str):
        raise FileServiceError("The path must be text.", 400)

    rel = rel.strip()

    if rel == "":
        if allow_root:
            return SANDBOX
        raise FileServiceError("A path is required.", 400)

    if rel.startswith("/") or rel.startswith("\\") or _DRIVE_RE.match(rel):
        raise FileServiceError(
            "Absolute paths are refused. Use a path inside ./sandbox.", 400
        )

    for part in rel.split("/"):
        if not is_safe_name(part):
            raise FileServiceError(
                "That is not a safe relative path inside ./sandbox.", 403
            )

    return _ensure_inside(SANDBOX / rel)


def rel_of(path):
    """Return the 'sandbox/...' style path used in every API response."""
    path = Path(path)
    if path == SANDBOX:
        return ""
    try:
        return path.relative_to(SANDBOX).as_posix()
    except ValueError:
        return path.name


# ------------------------------------------------------------
# Reading
# ------------------------------------------------------------

def _entry_type(path):
    if path.is_symlink():
        return "symlink"
    if path.is_dir():
        return "directory"
    if path.is_file():
        return "file"
    return "other"


def _entry(path):
    """Describe one directory entry for the file browser."""
    try:
        info = path.lstat()
    except OSError:
        return {"name": path.name, "path": rel_of(path), "type": "unknown"}

    kind = _entry_type(path)

    return {
        "name": path.name,
        "path": rel_of(path),
        "type": kind,
        "size": None if kind == "directory" else info.st_size,
        "mode": format(stat.S_IMODE(info.st_mode), "03o"),
        "modified": datetime.fromtimestamp(info.st_mtime).isoformat(timespec="seconds"),
    }


def list_dir(rel=""):
    """List the entries of a directory inside the sandbox."""
    ensure_sandbox()
    path = resolve_path(rel, allow_root=True)

    if not path.exists():
        raise FileServiceError("There is nothing at that path.", 404)
    if not path.is_dir():
        raise FileServiceError("That path is a file, not a directory.", 400)

    entries = [_entry(child) for child in path.iterdir()]
    entries.sort(key=lambda item: (item["type"] != "directory", item["name"].lower()))

    return {
        "path": rel_of(path),
        "is_root": path == SANDBOX,
        "parent": "" if path == SANDBOX else rel_of(path.parent),
        "entries": entries,
        "count": len(entries),
    }


def read_file(rel):
    """Return the text content of one file inside the sandbox."""
    path = resolve_path(rel)

    if not path.exists():
        raise FileServiceError("There is no file at that path.", 404)
    if path.is_dir():
        raise FileServiceError(
            "That path is a directory. Open it to list what is inside.", 400
        )

    size = path.stat().st_size

    with path.open("rb") as handle:
        data = handle.read(MAX_READ_BYTES)

    truncated = size > len(data)

    if b"\x00" in data[:4096]:
        return {
            "path": rel_of(path),
            "size": size,
            "binary": True,
            "content": None,
            "lines": None,
            "truncated": truncated,
            "message": "This looks like a binary file, so it is not shown as text.",
        }

    text = data.decode("utf-8", errors="replace")

    return {
        "path": rel_of(path),
        "size": size,
        "binary": False,
        "content": text,
        "lines": text.count("\n"),
        "truncated": truncated,
        "message": (
            "Only the first %s bytes are shown." % MAX_READ_BYTES if truncated else None
        ),
    }


def stats():
    """Counts of the top level of the sandbox, for the dashboard statistics."""
    ensure_sandbox()
    files = 0
    directories = 0

    for child in SANDBOX.iterdir():
        if child.is_dir():
            directories += 1
        else:
            files += 1

    return {"entries": files + directories, "files": files, "directories": directories}


# ------------------------------------------------------------
# Writing
# ------------------------------------------------------------

def _check_parent(path, rel):
    if not path.parent.is_dir():
        raise FileServiceError(
            "The folder '%s' does not exist." % (rel_of(path.parent) or "sandbox"), 404
        )


def _check_new_name(path, kind):
    """An existing name is never written over silently."""
    if path.is_dir():
        raise FileServiceError(
            "'%s' is already a directory, so a %s cannot use that name."
            % (path.name, kind),
            409,
        )
    if path.exists():
        raise FileServiceError(
            "'%s' already exists, so nothing was changed." % path.name, 409
        )


def create_file(rel, content=""):
    """Create a new file. An existing name is refused, exactly like the CLI."""
    ensure_sandbox()
    path = resolve_path(rel)

    if content is None:
        content = ""
    if not isinstance(content, str):
        raise FileServiceError("The content must be text.", 400)

    _check_parent(path, rel)
    _check_new_name(path, "file")

    path.write_text(content, encoding="utf-8")

    return {"entry": _entry(path), "created": True, "lines": content.count("\n")}


def create_dir(rel, parents=False):
    """Create a directory, optionally with every missing parent (mkdir -p)."""
    ensure_sandbox()
    path = resolve_path(rel)

    if path.exists():
        if path.is_dir():
            raise FileServiceError(
                "'%s' already exists as a directory, so nothing was changed."
                % path.name,
                409,
            )
        raise FileServiceError(
            "'%s' already exists as a file, so a directory cannot use that name."
            % path.name,
            409,
        )

    if not parents:
        _check_parent(path, rel)

    path.mkdir(parents=bool(parents))

    return {"entry": _entry(path), "created": True, "parents": bool(parents)}


def write_file(rel, content, confirm=False):
    """Write or replace a file's content, but only with explicit confirmation."""
    ensure_sandbox()
    path = resolve_path(rel)

    if not isinstance(content, str):
        raise FileServiceError("The content must be text.", 400)

    if path.is_dir():
        raise FileServiceError(
            "'%s' is a directory, so a file cannot use that name." % path.name, 409
        )

    existed = path.exists()

    if existed and not confirm:
        raise FileServiceError(
            "'%s' already exists. Confirm to replace its content." % path.name, 409
        )

    if not existed:
        _check_parent(path, rel)

    path.write_text(content, encoding="utf-8")

    return {
        "entry": _entry(path),
        "created": not existed,
        "lines": content.count("\n"),
    }


def rename(rel, new_name):
    """Rename an entry inside its own directory, like mv does."""
    src = resolve_path(rel)

    if not src.exists():
        raise FileServiceError("There is nothing at that path.", 404)
    if src == SANDBOX:
        raise FileServiceError("The sandbox folder itself cannot be renamed.", 400)

    if not is_safe_name(new_name):
        raise FileServiceError(
            "That is not a safe name. Use letters, digits, dot, dash or underscore.",
            400,
        )
    if new_name == src.name:
        raise FileServiceError("The new name is the same as the old one.", 400)

    dst = _ensure_inside(src.parent / new_name)

    if dst.exists():
        raise FileServiceError("'%s' already exists." % new_name, 409)

    src.rename(dst)

    return {"from": rel_of(src), "to": rel_of(dst), "entry": _entry(dst)}


def delete(rel, confirm=False):
    """Delete one file, or one empty directory, after an explicit confirmation."""
    if not confirm:
        raise FileServiceError("Deleting needs confirmation. Send confirm: true.", 400)

    path = resolve_path(rel)

    if path == SANDBOX:
        raise FileServiceError("The sandbox folder itself cannot be deleted.", 400)

    if path.name == KEEP_NAME:
        raise FileServiceError(
            "Refused: .gitkeep keeps the empty folder visible to git.", 403
        )

    if not path.exists():
        raise FileServiceError("There is nothing at that path.", 404)

    if path.is_dir():
        try:
            path.rmdir()
        except OSError:
            raise FileServiceError(
                "The directory is not empty. Remove what is inside it first.", 409
            )
        kind = "directory"
    else:
        path.unlink()
        kind = "file"

    return {"path": rel_of(path), "type": kind}

"""Read data/command_library.txt for the web interface.

The library is the same plain text file the CLI uses (modules/commands.sh), so
the web interface never duplicates the data. Each entry is a block:

    ### echo
    SYLLABUS : Module 1 - Unix Basics
    PURPOSE  : Write text, or the value of a variable, to standard output.
    SYNTAX   : echo [option] [string ...]
    EXAMPLE  : echo "Hello, UniShell"
    OUTPUT   : Hello, UniShell
    USES     : Printing messages, showing variable values, building script output.
    NOTES    : -n suppresses the trailing newline; -e turns on the \\n and \\t escapes.

Nothing here runs a shell command or executes text typed by a user: the file is
only read and parsed.
"""

import re
from pathlib import Path

# Locate the UniShell project directory (backend/services/ -> project root).
BASE_DIR = Path(__file__).resolve().parents[2]
COMMAND_FILE = BASE_DIR / "data" / "command_library.txt"

# Field name in the file -> key used in the JSON response.
FIELD_KEYS = {
    "SYLLABUS": "syllabus",
    "PURPOSE": "purpose",
    "SYNTAX": "syntax",
    "EXAMPLE": "example",
    "OUTPUT": "output",
    "USES": "uses",
    "NOTES": "notes",
}

_BLOCK_RE = re.compile(r"^###\s+(\S+)\s*$")
_FIELD_RE = re.compile(r"^([A-Z][A-Z ]*?)\s*:\s*(.*)$")
_MODULE_PREFIX_RE = re.compile(r"^Module\s+\d+\s*-\s*")


def _read_lines():
    if not COMMAND_FILE.exists():
        raise FileNotFoundError("Command library not found")
    return COMMAND_FILE.read_text(encoding="utf-8").splitlines()


def _is_valid_name(name):
    """Accept a plain command name only, so a name can never be a path."""
    return bool(name) and isinstance(name, str) and name.replace("_", "").isalnum()


def _category_label(syllabus):
    """'Module 1 - Unix Basics' -> 'Unix Basics'."""
    label = _MODULE_PREFIX_RE.sub("", (syllabus or "").strip())
    return label or "General"


def _records():
    """Parse the whole file into one dictionary per command."""
    records = []
    current = None

    for line in _read_lines():
        block = _BLOCK_RE.match(line)
        if block:
            current = {"name": block.group(1)}
            records.append(current)
            continue

        # Comments and blank lines between the fields are ignored.
        if current is None or not line.strip() or line.startswith("#"):
            continue

        field = _FIELD_RE.match(line)
        if not field:
            continue

        key = FIELD_KEYS.get(field.group(1).strip())
        if key:
            current[key] = field.group(2).strip()

    return records


def get_all_commands():
    """Return every command name (kept for the original API shape)."""
    return [record["name"] for record in _records()]


def get_command_details(name):
    """Return the complete raw text block of one command, or None."""
    if not _is_valid_name(name):
        return None

    result = []
    found = False

    for line in _read_lines():
        block = _BLOCK_RE.match(line)
        if block:
            if found:
                break
            if block.group(1) == name:
                found = True

        if found:
            result.append(line)

    return "\n".join(result) if found else None


def get_command(name):
    """Return one command as a dictionary of fields, or None."""
    if not _is_valid_name(name):
        return None

    for record in _records():
        if record["name"] == name:
            return record

    return None


def search_commands(query):
    """Return the names that contain the query (kept for the original API)."""
    query = (query or "").strip().lower()

    if not query:
        return []

    return [name for name in get_all_commands() if query in name.lower()]


def filter_commands(query="", category=None):
    """Return the full records that match a text query and/or a category."""
    query = (query or "").strip().lower()
    wanted = _category_label(category) if category else None
    matches = []

    for record in _records():
        if wanted and _category_label(record.get("syllabus")) != wanted:
            continue

        if query:
            haystack = " ".join(
                str(record.get(key, ""))
                for key in ("name", "purpose", "syntax", "uses", "notes")
            ).lower()
            if query not in haystack:
                continue

        matches.append(record)

    return matches


def get_categories():
    """Return the syllabus categories that really appear in the file."""
    counts = {}

    for record in _records():
        label = _category_label(record.get("syllabus"))
        counts[label] = counts.get(label, 0) + 1

    return [{"name": name, "count": counts[name]} for name in sorted(counts)]


def count_commands():
    """Number of commands in the library (used by the dashboard statistics)."""
    return len(_records())

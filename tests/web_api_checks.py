#!/usr/bin/env python3
"""Endpoint checks for the UniShell web API.

This file is run by tests/test_11_web_api.sh, which is picked up by "make test"
in the same way as every other test script. It talks to the Flask application
through its test client, so no port has to be opened and no server has to be
left running.

Two rules are followed on purpose:

  * every expected value is read from the real project data
    (data/command_library.txt and data/quiz_questions.txt), never hard coded,
    so the test proves the API reads the same files the CLI reads;
  * everything the test creates lives in ./sandbox and is removed again before
    the script ends, including when a check has failed.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from backend.app import app  # noqa: E402  (import after sys.path is prepared)

SANDBOX = ROOT / "sandbox"
COMMAND_FILE = ROOT / "data" / "command_library.txt"
QUIZ_FILE = ROOT / "data" / "quiz_questions.txt"

CREATED = []  # sandbox entries made by this run, removed again at the end
passed = 0
failed = 0


def ok(name):
    global passed
    passed += 1
    print("  [PASS] %s" % name)


def bad(name, detail=""):
    global failed
    failed += 1
    print("  [FAIL] %s%s" % (name, (" - " + detail) if detail else ""))


def check(condition, name, detail=""):
    if condition:
        ok(name)
    else:
        bad(name, detail)


def blocks(path):
    """Names of the '### name' blocks in a data file."""
    return [
        line[4:].strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith("### ")
    ]


def quiz_answer_key():
    """The ANSWER letter of every question, read straight from the data file."""
    answers = []
    for line in QUIZ_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("### "):
            answers.append("")
        elif line.startswith("ANSWER:"):
            answers[-1] = line.split(":", 1)[1].strip()
    return [answer for answer in answers if answer]


print("Web API checks - project root: %s" % ROOT)

client = app.test_client()


def post_json(url, payload):
    return client.post(url, json=payload)


# ------------------------------------------------------------
print("\n1. Health and API index")
# ------------------------------------------------------------
response = client.get("/api/health")
check(response.status_code == 200, "GET /api/health returns 200", str(response.status_code))
check(response.get_json().get("status") == "healthy", "GET /api/health reports healthy")

response = client.get("/api")
body = response.get_json()
check(response.status_code == 200, "GET /api returns 200", str(response.status_code))
check("endpoints" in body, "GET /api lists the available endpoints")

# ------------------------------------------------------------
print("\n2. Command library")
# ------------------------------------------------------------
expected_commands = blocks(COMMAND_FILE)

response = client.get("/api/commands")
body = response.get_json()
check(response.status_code == 200, "GET /api/commands returns 200")
check(body.get("total") == len(expected_commands),
      "GET /api/commands counts every command in the data file",
      "%s != %s" % (body.get("total"), len(expected_commands)))
check(body.get("commands") == expected_commands,
      "GET /api/commands returns the same names as the data file")
check(len(body.get("items", [])) == len(expected_commands),
      "GET /api/commands returns a parsed record per command")
check(all(item.get("purpose") for item in body.get("items", [])),
      "every parsed command has a purpose")

response = client.get("/api/commands?q=pwd")
check(len(response.get_json().get("items", [])) == 1,
      "GET /api/commands?q=pwd finds exactly one command")

response = client.get("/api/commands?category=Unix Basics")
items = response.get_json().get("items", [])
check(len(items) > 0 and all(item["syllabus"].startswith("Module 1") for item in items),
      "GET /api/commands?category= filters by syllabus")

response = client.get("/api/commands/search?q=ls")
results = response.get_json().get("results", [])
check("ls" in results, "GET /api/commands/search finds ls")

response = client.get("/api/commands/categories")
body = response.get_json()
check(response.status_code == 200, "GET /api/commands/categories returns 200")
check(len(body.get("categories", [])) == 4, "the command library has four categories",
      str(body.get("categories")))

response = client.get("/api/commands/pwd")
body = response.get_json()
check(response.status_code == 200, "GET /api/commands/pwd returns 200")
check(body.get("fields", {}).get("syntax"), "GET /api/commands/pwd includes the syntax")
check((body.get("details") or "").startswith("### pwd"),
      "GET /api/commands/pwd includes the original text block")

response = client.get("/api/commands/not_a_real_command")
check(response.status_code == 404, "GET /api/commands/<unknown> returns 404",
      str(response.status_code))

# ------------------------------------------------------------
print("\n3. File management inside the sandbox")
# ------------------------------------------------------------
response = client.get("/api/files")
body = response.get_json()
check(response.status_code == 200, "GET /api/files returns 200")
check(body.get("is_root") is True, "GET /api/files starts at the sandbox root")
check(isinstance(body.get("entries"), list), "GET /api/files returns a list of entries")

response = post_json("/api/files", {"path": "api_test.txt", "content": "hello\nworld\n"})
check(response.status_code == 201, "POST /api/files creates a file",
      str(response.status_code))
CREATED.append("api_test.txt")

response = post_json("/api/files", {"path": "api_test.txt", "content": "again"})
check(response.status_code == 409, "POST /api/files refuses an existing name",
      str(response.status_code))

response = client.get("/api/files/content?path=api_test.txt")
body = response.get_json()
check(response.status_code == 200, "GET /api/files/content reads the file back")
check(body.get("content") == "hello\nworld\n", "the content round-trips exactly",
      repr(body.get("content")))
check(body.get("lines") == 2, "the line count is right", str(body.get("lines")))

response = client.put("/api/files/content",
                      json={"path": "api_test.txt", "content": "one\n"})
check(response.status_code == 409, "PUT /api/files/content needs confirmation to replace",
      str(response.status_code))

response = client.put("/api/files/content",
                      json={"path": "api_test.txt", "content": "one\n", "confirm": True})
check(response.status_code == 200, "PUT /api/files/content replaces when confirmed",
      str(response.status_code))
check(response.get_json().get("created") is False, "the replacement is not reported as new")

response = post_json("/api/files/directory", {"path": "api_dir"})
check(response.status_code == 201, "POST /api/files/directory creates a directory",
      str(response.status_code))
CREATED.append("api_dir")

response = post_json("/api/files/directory", {"path": "api_dir"})
check(response.status_code == 409, "POST /api/files/directory refuses an existing name",
      str(response.status_code))

response = post_json("/api/files/directory", {"path": "api_nested/deep", "parents": True})
check(response.status_code == 201, "POST /api/files/directory creates missing parents",
      str(response.status_code))
CREATED.append("api_nested")

response = client.get("/api/files?path=api_nested")
body = response.get_json()
check(body.get("count") == 1 and body["entries"][0]["name"] == "deep",
      "GET /api/files lists a subdirectory",
      str(body.get("entries")))

response = post_json("/api/files/rename",
                     {"path": "api_test.txt", "new_name": "api_renamed.txt"})
check(response.status_code == 200, "POST /api/files/rename renames a file",
      str(response.status_code))
CREATED.remove("api_test.txt")
CREATED.append("api_renamed.txt")

response = client.get("/api/files/content?path=api_test.txt")
check(response.status_code == 404, "the old name is gone after the rename",
      str(response.status_code))

# ------------------------------------------------------------
print("\n4. The sandbox cannot be left")
# ------------------------------------------------------------
for bad_path, label in (
    ("../unishell.sh", "a path that climbs out with .."),
    ("/etc/passwd", "an absolute path"),
    ("api_dir/../../unishell.sh", "a .. in the middle of a path"),
    ("a b/notes.txt", "a part with a space"),
    ("-rf", "a name that looks like an option"),
):
    response = client.get("/api/files/content?path=" + bad_path.replace(" ", "%20"))
    check(response.status_code in (400, 403),
          "GET /api/files/content refuses %s" % label,
          "%s %s" % (response.status_code, response.get_json()))

response = post_json("/api/files", {"path": "../escape.txt"})
check(response.status_code in (400, 403), "POST /api/files refuses to escape the sandbox",
      str(response.status_code))
check(not (ROOT.parent / "escape.txt").exists(), "no file was created outside the sandbox")

response = client.delete("/api/files", json={"path": "api_renamed.txt"})
check(response.status_code == 400, "DELETE /api/files needs confirmation",
      str(response.status_code))

response = client.delete("/api/files", json={"path": ".gitkeep", "confirm": True})
check(response.status_code == 403, "DELETE /api/files protects .gitkeep",
      str(response.status_code))

# a directory that still holds something cannot be removed, like rmdir
post_json("/api/files", {"path": "api_dir/inside.txt"})
response = client.delete("/api/files", json={"path": "api_dir", "confirm": True})
check(response.status_code == 409, "DELETE /api/files refuses a directory that is not empty",
      str(response.status_code))

response = client.delete("/api/files", json={"path": "api_dir/inside.txt", "confirm": True})
check(response.status_code == 200, "DELETE /api/files removes a file",
      str(response.status_code))

response = client.delete("/api/files", json={"path": "api_dir", "confirm": True})
check(response.status_code == 200, "DELETE /api/files removes the empty directory",
      str(response.status_code))
CREATED.remove("api_dir")

response = client.delete("/api/files", json={"path": "api_renamed.txt", "confirm": True})
check(response.status_code == 200, "DELETE /api/files removes the renamed file",
      str(response.status_code))
CREATED.remove("api_renamed.txt")

response = client.delete("/api/files", json={"path": "api_renamed.txt", "confirm": True})
check(response.status_code == 404, "deleting a missing entry reports 404",
      str(response.status_code))

response = client.get("/api/files/stats")
check(response.status_code == 200 and "entries" in response.get_json(),
      "GET /api/files/stats reports sandbox counts")

# ------------------------------------------------------------
print("\n5. Permissions")
# ------------------------------------------------------------
response = client.get("/api/permissions/explain")
body = response.get_json()
check(response.status_code == 200, "GET /api/permissions/explain returns 200")
check(len(body.get("rights", [])) == 3, "the explanation covers r, w and x")
check(len(body.get("numeric", [])) == 3, "the explanation covers 4, 2 and 1")
check(len(body.get("rules", [])) >= 5, "the explanation lists the reading rules")

response = post_json("/api/files", {"path": "api_perm.txt", "content": "x\n"})
CREATED.append("api_perm.txt")

response = client.get("/api/permissions?path=api_perm.txt")
body = response.get_json()
check(response.status_code == 200, "GET /api/permissions describes a file",
      str(response.status_code))
check(len(body.get("symbolic", "")) == 10, "the symbolic mode has ten characters",
      body.get("symbolic"))
check(body.get("bits", {}).get("owner", {}).get("read") is True,
      "a new file is readable by its owner")
check(body.get("summary"), "the response explains the rights in words")

response = client.put("/api/permissions", json={"path": "api_perm.txt", "mode": "600"})
body = response.get_json()
check(response.status_code == 200, "PUT /api/permissions applies a mode",
      str(response.status_code))
check(body.get("after", {}).get("octal") == "600", "the mode really became 600",
      str(body.get("after", {}).get("octal")))

response = client.get("/api/permissions?path=api_perm.txt")
check(response.get_json().get("octal") == "600", "reading it back agrees with the change")

response = client.put("/api/permissions", json={"path": "api_perm.txt", "mode": "777"})
check(response.status_code == 200 and response.get_json()["after"]["octal"] == "777",
      "a second mode change is applied")

for bad_mode, label in (("999", "a digit that is not octal"),
                        ("64", "too few digits"),
                        ("rwx", "letters instead of digits")):
    response = client.put("/api/permissions",
                          json={"path": "api_perm.txt", "mode": bad_mode})
    check(response.status_code == 400, "PUT /api/permissions refuses %s" % label,
          "%s %s" % (response.status_code, response.get_json()))

response = client.put("/api/permissions", json={"path": "../unishell.sh", "mode": "600"})
check(response.status_code == 403, "PUT /api/permissions refuses a path outside the sandbox",
      str(response.status_code))

response = client.get("/api/permissions/list")
body = response.get_json()
check(response.status_code == 200, "GET /api/permissions/list returns 200")
check(all("symbolic" in entry and "octal" in entry for entry in body.get("entries", [])),
      "every listed entry carries its mode")

client.delete("/api/files", json={"path": "api_perm.txt", "confirm": True})
CREATED.remove("api_perm.txt")

# ------------------------------------------------------------
print("\n6. Quiz")
# ------------------------------------------------------------
expected_key = quiz_answer_key()

response = client.get("/api/quiz/info")
body = response.get_json()
check(response.status_code == 200, "GET /api/quiz/info returns 200")
check(body.get("total") == len(expected_key), "the quiz has every question in the data file",
      "%s != %s" % (body.get("total"), len(expected_key)))

response = client.get("/api/quiz/questions")
body = response.get_json()
questions = body.get("questions", [])
check(len(questions) == len(expected_key), "GET /api/quiz/questions returns every question")
check(all(len(question["options"]) == 4 for question in questions),
      "every question offers four options")
check(all("answer" not in question and "explanation" not in question
          for question in questions),
      "the questions do not leak the answer or the explanation")

ids = [question["id"] for question in questions]
perfect = dict(zip(ids, expected_key))

response = post_json("/api/quiz/submit", {"answers": perfect})
body = response.get_json()
check(response.status_code == 200, "POST /api/quiz/submit scores an attempt",
      str(response.status_code))
check(body.get("correct") == len(expected_key), "a perfect attempt scores every question",
      str(body.get("correct")))
check(body.get("percent") == 100, "a perfect attempt is 100 percent", str(body.get("percent")))
check(body.get("performance", {}).get("band") == "Excellent",
      "the performance summary is reported")
check(all(item.get("explanation") for item in body.get("results", [])),
      "the explanations come back with the result")

all_a = {question_id: "A" for question_id in ids}
response = post_json("/api/quiz/submit", {"answers": all_a})
body = response.get_json()
expected_all_a = sum(1 for letter in expected_key if letter == "A")
check(body.get("correct") == expected_all_a,
      "answering A everywhere scores exactly the questions whose answer is A",
      "%s != %s" % (body.get("correct"), expected_all_a))
check(body.get("answered") == len(expected_key), "every question counts as answered")

partial = dict(perfect)
first = ids[0]
partial[first] = "A" if expected_key[0] != "A" else "B"
response = post_json("/api/quiz/submit", {"answers": partial})
body = response.get_json()
check(body.get("correct") == len(expected_key) - 1,
      "one wrong answer loses exactly one point", str(body.get("correct")))
check(body.get("wrong") == 1, "the wrong count is reported", str(body.get("wrong")))

second = ids[1]
del partial[second]
response = post_json("/api/quiz/submit", {"answers": partial})
body = response.get_json()
check(body.get("unanswered") == 1, "a question that was left out is counted as unanswered",
      str(body.get("unanswered")))

response = post_json("/api/quiz/submit", {"answers": {ids[0]: "E"}})
check(response.status_code == 400, "POST /api/quiz/submit refuses a letter that is not A-D",
      str(response.status_code))

response = post_json("/api/quiz/submit", {"answers": {"q999": "A"}})
check(response.status_code == 400, "POST /api/quiz/submit refuses an unknown question id",
      str(response.status_code))

response = post_json("/api/quiz/submit", {})
check(response.status_code == 400, "POST /api/quiz/submit refuses a body without answers",
      str(response.status_code))

# ------------------------------------------------------------
print("\n7. The frontend is served")
# ------------------------------------------------------------
response = client.get("/")
check(response.status_code == 200, "GET / returns the dashboard",
      str(response.status_code))
check(b"UniShell" in response.data, "the dashboard mentions UniShell")

for asset in ("style.css", "script.js"):
    response = client.get("/static/" + asset)
    check(response.status_code == 200, "GET /static/%s is served" % asset,
          str(response.status_code))

# ------------------------------------------------------------
print("\n8. Cleanup")
# ------------------------------------------------------------
# Remove the deepest entry first: the API refuses to delete a directory that
# still holds something (it mirrors rmdir), so api_nested/deep has to go before
# api_nested itself.
for entry in ("api_test.txt", "api_renamed.txt", "api_perm.txt",
              "api_dir/inside.txt", "api_dir",
              "api_nested/deep", "api_nested"):
    client.delete("/api/files", json={"path": entry, "confirm": True})

for entry in list(CREATED):
    client.delete("/api/files", json={"path": entry, "confirm": True})

remaining = []
for entry in ("api_test.txt", "api_renamed.txt", "api_perm.txt", "api_dir", "api_nested"):
    if (SANDBOX / entry).exists():
        remaining.append(entry)

response = client.get("/api/files")
names = [entry["name"] for entry in response.get_json().get("entries", [])]
check(all(name == ".gitkeep" or "api_" not in name for name in names),
      "the test left nothing behind in the sandbox", str(remaining))

printf_summary = "web api test result: %d passed, %d failed" % (passed, failed)
print("\n" + printf_summary)
sys.exit(0 if failed == 0 else 1)

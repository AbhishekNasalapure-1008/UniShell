"""Read data/quiz_questions.txt and score one quiz attempt.

The question bank is the same plain text file the CLI uses (modules/quiz.sh), so
no question is duplicated for the web. Each question is a block:

    ### q1
    TOPIC: Unix Basics
    QUESTION: Which command prints the absolute path of the current directory?
    OPTION A: cd
    OPTION B: pwd
    OPTION C: ls
    OPTION D: path
    ANSWER: B
    HINT: The name is short for "print working directory".
    EXPLANATION: pwd asks the kernel for the current working directory ...

The answers and the explanations are never sent with the questions. They are
returned only by grade(), once an attempt has been submitted. Nothing typed by
a user is executed: an answer is a single letter that is compared with ANSWER.
"""

import re
from pathlib import Path

# Locate the UniShell project directory (backend/services/ -> project root).
BASE_DIR = Path(__file__).resolve().parents[2]
QUIZ_FILE = BASE_DIR / "data" / "quiz_questions.txt"

LETTERS = ("A", "B", "C", "D")

_BLOCK_RE = re.compile(r"^###\s+(\S+)\s*$")
_FIELD_RE = re.compile(
    r"^(TOPIC|QUESTION|OPTION A|OPTION B|OPTION C|OPTION D|ANSWER|HINT|EXPLANATION):[ ]?(.*)$"
)


class QuizServiceError(Exception):
    """An error that already carries the HTTP status the API should return."""

    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status


def _load():
    """Parse the bank into one dictionary per complete question."""
    if not QUIZ_FILE.exists():
        raise FileNotFoundError("Question bank not found")

    questions = []
    current = None

    for line in QUIZ_FILE.read_text(encoding="utf-8").splitlines():
        block = _BLOCK_RE.match(line)
        if block:
            current = {"id": block.group(1), "options": {}}
            questions.append(current)
            continue

        if current is None or line.startswith("#"):
            continue

        field = _FIELD_RE.match(line)
        if not field:
            continue

        key, value = field.group(1), field.group(2).strip()

        if key == "TOPIC":
            current["topic"] = value
        elif key == "QUESTION":
            current["question"] = value
        elif key.startswith("OPTION "):
            current["options"][key[-1]] = value
        elif key == "ANSWER":
            current["answer"] = value.upper()
        elif key == "HINT":
            current["hint"] = value
        elif key == "EXPLANATION":
            current["explanation"] = value

    return [
        question
        for question in questions
        if question.get("question")
        and question.get("answer") in LETTERS
        and len(question.get("options", {})) >= 2
    ]


def _public(question):
    """One question without the answer or the explanation."""
    return {
        "id": question["id"],
        "topic": question.get("topic", "General"),
        "question": question["question"],
        "hint": question.get("hint", ""),
        "options": [
            {"letter": letter, "text": question["options"][letter]}
            for letter in LETTERS
            if letter in question["options"]
        ],
    }


def get_questions():
    """Every question, safe to show before the attempt is submitted."""
    return [_public(question) for question in _load()]


def get_info():
    """How many questions there are, and how they are spread over the topics."""
    questions = _load()
    topics = {}

    for question in questions:
        label = question.get("topic", "General")
        topics[label] = topics.get(label, 0) + 1

    return {
        "total": len(questions),
        "topics": [{"name": name, "count": topics[name]} for name in sorted(topics)],
    }


def performance(percent):
    """A short summary of how an attempt went."""
    if percent >= 90:
        return {"band": "Excellent", "message": "Nearly every answer was right."}
    if percent >= 70:
        return {"band": "Good", "message": "A solid result - review the ones you missed."}
    if percent >= 50:
        return {"band": "Fair", "message": "Half way there. Read the explanations and try again."}
    return {"band": "Keep practising", "message": "Read the explanations, then restart the quiz."}


def grade(answers):
    """Score an attempt and reveal the answers of every question.

    answers is a dictionary of question id -> letter, for example
    {"q1": "B", "q2": "A"}. Questions left out are counted as unanswered.
    """
    if not isinstance(answers, dict):
        raise QuizServiceError("Send an object of answers, keyed by question id.", 400)

    questions = _load()

    if not questions:
        raise QuizServiceError("The question bank is empty.", 500)

    known = {question["id"] for question in questions}

    for key, value in answers.items():
        if key not in known:
            raise QuizServiceError("That question id is not in the bank.", 400)
        if not isinstance(value, str) or value.strip().upper() not in LETTERS:
            raise QuizServiceError("Every answer must be A, B, C or D.", 400)

    results = []
    correct = 0
    answered = 0

    for question in questions:
        chosen = answers.get(question["id"])
        chosen = chosen.strip().upper() if isinstance(chosen, str) else None
        is_correct = chosen == question["answer"]

        if chosen:
            answered += 1
        if is_correct:
            correct += 1

        results.append({
            "id": question["id"],
            "topic": question.get("topic", "General"),
            "question": question["question"],
            "options": [
                {"letter": letter, "text": question["options"][letter]}
                for letter in LETTERS
                if letter in question["options"]
            ],
            "selected": chosen,
            "answer": question["answer"],
            "correct": is_correct,
            "explanation": question.get("explanation", ""),
        })

    total = len(questions)
    percent = round(correct * 100 / total)

    return {
        "total": total,
        "answered": answered,
        "correct": correct,
        "wrong": answered - correct,
        "unanswered": total - answered,
        "percent": percent,
        "performance": performance(percent),
        "results": results,
    }

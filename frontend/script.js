/* ============================================================
   UniShell web frontend
   Four modules: Unix Commands, File Management, Permissions, Quiz.
   Plain JavaScript only - the Flask API does all the work, and the
   browser never runs a shell command.
   ============================================================ */

const API = "/api";

/* ---------- small helpers ---------- */

// Build an element without ever using innerHTML, so text from the server
// (file names, contents, questions) can never be treated as HTML.
function el(tag, options = {}) {
    const node = document.createElement(tag);

    if (options.className) node.className = options.className;
    if (options.text !== undefined) node.textContent = options.text;

    if (options.attrs) {
        for (const [key, value] of Object.entries(options.attrs)) {
            node.setAttribute(key, value);
        }
    }
    if (options.children) {
        options.children.filter(Boolean).forEach(child => node.appendChild(child));
    }
    if (options.on) {
        node.addEventListener(options.on.event, options.on.handler);
    }
    return node;
}

function setStatus(node, text, isError) {
    if (!node) return;
    node.textContent = text || "";
    node.classList.toggle("error", Boolean(isError));
    node.classList.toggle("success", Boolean(text) && !isError);
}

async function apiGet(path) {
    const response = await fetch(API + path);
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data.success === false) {
        throw new Error(data.message || ("Request failed: " + response.status));
    }
    return data;
}

async function apiSend(method, path, body) {
    const response = await fetch(API + path, {
        method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body || {})
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data.success === false) {
        throw new Error(data.message || ("Request failed: " + response.status));
    }
    return data;
}

/* ============================================================
   MODULE 01 - Unix Commands
   ============================================================ */

const commandList = document.getElementById("commandList");
const commandDetails = document.getElementById("commandDetails");
const searchInput = document.getElementById("searchInput");

let allCommands = [];

async function loadCommands() {
    try {
        const data = await apiGet("/commands");
        allCommands = data.commands || [];
        displayCommands(allCommands);
    } catch (error) {
        commandList.replaceChildren(
            el("p", { className: "muted", text: "Unable to connect to the UniShell API. Is Flask running?" })
        );
        console.error(error);
    }
}

function displayCommands(commands) {
    commandList.replaceChildren();

    if (!commands.length) {
        commandList.appendChild(el("p", { className: "empty-message", text: "No commands found." }));
        return;
    }

    commands.forEach(name => {
        const button = el("button", {
            className: "command-item",
            text: name,
            attrs: { type: "button" }
        });
        button.addEventListener("click", () => {
            document.querySelectorAll(".command-item")
                .forEach(item => item.classList.remove("active"));
            button.classList.add("active");
            loadCommandDetails(name);
        });
        commandList.appendChild(button);
    });
}

const COMMAND_FIELDS = [
    ["syllabus", "Syllabus"],
    ["purpose", "Purpose"],
    ["syntax", "Syntax"],
    ["example", "Example"],
    ["output", "Expected output"],
    ["uses", "Where it is used"],
    ["notes", "Notes"]
];

async function loadCommandDetails(name) {
    try {
        commandDetails.replaceChildren(el("p", { className: "muted", text: "Loading..." }));

        const data = await apiGet("/commands/" + encodeURIComponent(name));
        const fields = data.fields || {};

        const list = el("dl", { className: "field-list" });
        COMMAND_FIELDS.forEach(([key, label]) => {
            if (!fields[key]) return;
            list.appendChild(el("dt", { text: label }));
            const dd = el("dd");
            if (key === "syntax" || key === "example" || key === "output") {
                dd.appendChild(el("code", { text: fields[key] }));
            } else {
                dd.textContent = fields[key];
            }
            list.appendChild(dd);
        });

        commandDetails.replaceChildren(
            el("h3", { text: name }),
            list
        );
    } catch (error) {
        commandDetails.replaceChildren(
            el("p", { className: "muted", text: "Unable to load command details." })
        );
        console.error(error);
    }
}

searchInput.addEventListener("input", () => {
    const query = searchInput.value.trim().toLowerCase();
    displayCommands(allCommands.filter(name => name.toLowerCase().includes(query)));
});

/* ============================================================
   MODULE 02 - File Management
   ============================================================ */

const filePathBar = document.getElementById("filePathBar");
const fileList = document.getElementById("fileList");
const fileViewer = document.getElementById("fileViewer");
const fileViewerTitle = document.getElementById("fileViewerTitle");
const fileStatus = document.getElementById("fileStatus");

let currentDir = "";

async function loadFiles(path = currentDir) {
    setStatus(fileStatus, "");
    try {
        const data = await apiGet("/files?path=" + encodeURIComponent(path));
        currentDir = data.path || "";
        renderBreadcrumb(data);
        renderFileList(data);
    } catch (error) {
        fileList.replaceChildren(el("p", { className: "muted", text: error.message }));
    }
}

function renderBreadcrumb(data) {
    filePathBar.replaceChildren();

    filePathBar.appendChild(el("button", {
        className: "crumb",
        text: "sandbox",
        attrs: { type: "button" },
        on: { event: "click", handler: () => loadFiles("") }
    }));

    let accumulated = "";
    (data.path || "").split("/").filter(Boolean).forEach(part => {
        accumulated = accumulated ? accumulated + "/" + part : part;
        const target = accumulated;
        filePathBar.appendChild(el("span", { className: "crumb-sep", text: "/" }));
        filePathBar.appendChild(el("button", {
            className: "crumb",
            text: part,
            attrs: { type: "button" },
            on: { event: "click", handler: () => loadFiles(target) }
        }));
    });
}

function fileRow(entry) {
    const nameButton = el("button", {
        className: "entry-name",
        text: entry.name,
        attrs: { type: "button" }
    });

    if (entry.type === "directory") {
        nameButton.addEventListener("click", () => loadFiles(entry.path));
    } else {
        nameButton.addEventListener("click", () => openFile(entry.path));
    }

    const meta = el("span", {
        className: "entry-meta",
        text: entry.type === "directory"
            ? "folder"
            : (entry.size !== null ? entry.size + " bytes" : entry.type)
    });

    const actions = el("div", { className: "entry-actions" });
    actions.appendChild(el("button", {
        className: "mini-btn",
        text: "Rename",
        attrs: { type: "button" },
        on: { event: "click", handler: () => renameEntry(entry) }
    }));
    actions.appendChild(el("button", {
        className: "mini-btn danger",
        text: "Delete",
        attrs: { type: "button" },
        on: { event: "click", handler: () => deleteEntry(entry) }
    }));

    return el("div", {
        className: "entry-row " + entry.type,
        children: [nameButton, meta, actions]
    });
}

function renderFileList(data) {
    fileList.replaceChildren();

    if (!data.is_root) {
        fileList.appendChild(el("div", {
            className: "entry-row up",
            children: [
                el("button", {
                    className: "entry-name",
                    text: ".. (up)",
                    attrs: { type: "button" },
                    on: { event: "click", handler: () => loadFiles(data.parent || "") }
                })
            ]
        }));
    }

    if (!data.entries.length) {
        fileList.appendChild(el("p", { className: "muted", text: "This folder is empty." }));
        return;
    }

    data.entries.forEach(entry => fileList.appendChild(fileRow(entry)));
}

async function openFile(path) {
    fileViewerTitle.textContent = path;
    fileViewer.replaceChildren(el("p", { className: "muted", text: "Loading..." }));

    try {
        const data = await apiGet("/files/content?path=" + encodeURIComponent(path));

        if (data.binary) {
            fileViewer.replaceChildren(
                el("p", { className: "muted", text: data.message || "Binary file." })
            );
            return;
        }

        const area = el("textarea", {
            className: "editor",
            attrs: { rows: "14", spellcheck: "false" }
        });
        area.value = data.content || "";

        const saveButton = el("button", {
            className: "ghost-btn",
            text: "Save",
            attrs: { type: "button" }
        });
        saveButton.addEventListener("click", async () => {
            if (!window.confirm("Replace the content of " + path + "?")) return;
            try {
                const result = await apiSend("PUT", "/files/content", {
                    path, content: area.value, confirm: true
                });
                setStatus(fileStatus, result.message || "Saved.", false);
                loadFiles(currentDir);
            } catch (error) {
                setStatus(fileStatus, error.message, true);
            }
        });

        fileViewer.replaceChildren(
            el("p", { className: "muted", text: data.size + " bytes, " + (data.lines || 0) + " lines" }),
            area,
            saveButton
        );
    } catch (error) {
        fileViewer.replaceChildren(el("p", { className: "muted", text: error.message }));
    }
}

async function renameEntry(entry) {
    const newName = window.prompt("New name for " + entry.name + ":", entry.name);
    if (!newName || newName === entry.name) return;

    try {
        const result = await apiSend("POST", "/files/rename", {
            path: entry.path, new_name: newName
        });
        setStatus(fileStatus, result.message || "Renamed.", false);
        loadFiles(currentDir);
    } catch (error) {
        setStatus(fileStatus, error.message, true);
    }
}

async function deleteEntry(entry) {
    const kind = entry.type === "directory" ? "folder" : "file";
    if (!window.confirm("Delete the " + kind + " '" + entry.name + "'?")) return;

    try {
        const result = await apiSend("DELETE", "/files", {
            path: entry.path, confirm: true
        });
        setStatus(fileStatus, result.message || "Deleted.", false);
        loadFiles(currentDir);
    } catch (error) {
        setStatus(fileStatus, error.message, true);
    }
}

async function createFile() {
    const path = document.getElementById("createPath").value.trim();
    const content = document.getElementById("createContent").value;

    try {
        const result = await apiSend("POST", "/files", { path, content });
        setStatus(fileStatus, result.message || "Created.", false);
        document.getElementById("createPath").value = "";
        document.getElementById("createContent").value = "";
        loadFiles(currentDir);
    } catch (error) {
        setStatus(fileStatus, error.message, true);
    }
}

async function createDirectory() {
    const path = document.getElementById("createPath").value.trim();
    const parents = document.getElementById("createParents").checked;

    try {
        const result = await apiSend("POST", "/files/directory", { path, parents });
        setStatus(fileStatus, result.message || "Created.", false);
        document.getElementById("createPath").value = "";
        loadFiles(currentDir);
    } catch (error) {
        setStatus(fileStatus, error.message, true);
    }
}

document.getElementById("createFileBtn").addEventListener("click", createFile);
document.getElementById("createDirBtn").addEventListener("click", createDirectory);
document.getElementById("fileRefresh").addEventListener("click", () => loadFiles(currentDir));

/* ============================================================
   MODULE 03 - Permissions
   ============================================================ */

const permList = document.getElementById("permList");
const permDetail = document.getElementById("permDetail");
const permStatus = document.getElementById("permStatus");

async function loadPermissions(path = "") {
    setStatus(permStatus, "");
    try {
        const data = await apiGet("/permissions/list?path=" + encodeURIComponent(path));
        renderPermissionList(data);
    } catch (error) {
        permList.replaceChildren(el("p", { className: "muted", text: error.message }));
    }
}

function renderPermissionList(data) {
    permList.replaceChildren();

    if (!data.entries.length) {
        permList.appendChild(el("p", { className: "muted", text: "This folder is empty." }));
        return;
    }

    data.entries.forEach(entry => {
        const row = el("button", {
            className: "perm-row",
            attrs: { type: "button" },
            children: [
                el("code", { text: entry.symbolic }),
                el("span", { className: "perm-octal", text: entry.octal }),
                el("span", { className: "perm-name", text: entry.name })
            ]
        });
        row.addEventListener("click", () => selectPermission(entry.path));
        permList.appendChild(row);
    });
}

async function selectPermission(path) {
    document.getElementById("permPath").value = path;
    permDetail.replaceChildren(el("p", { className: "muted", text: "Loading..." }));

    try {
        const info = await apiGet("/permissions?path=" + encodeURIComponent(path));

        const list = el("dl", { className: "field-list" });
        list.appendChild(el("dt", { text: "Symbolic" }));
        list.appendChild(el("dd", { children: [el("code", { text: info.symbolic })] }));
        list.appendChild(el("dt", { text: "Numeric" }));
        list.appendChild(el("dd", { children: [el("code", { text: info.octal })] }));
        list.appendChild(el("dt", { text: "Owner" }));
        list.appendChild(el("dd", { text: info.owner }));
        list.appendChild(el("dt", { text: "Group" }));
        list.appendChild(el("dd", { text: info.group }));

        const summary = el("ul", { className: "perm-summary" });
        (info.summary || []).forEach(line => summary.appendChild(el("li", { text: line })));

        permDetail.replaceChildren(el("h4", { text: info.name }), list, summary);
    } catch (error) {
        permDetail.replaceChildren(el("p", { className: "muted", text: error.message }));
    }
}

async function applyMode() {
    const path = document.getElementById("permPath").value.trim();
    const mode = document.getElementById("permMode").value.trim();

    try {
        const result = await apiSend("PUT", "/permissions", { path, mode });
        setStatus(permStatus, result.message || "Mode applied.", false);
        loadPermissions("");
        selectPermission(path);
    } catch (error) {
        setStatus(permStatus, error.message, true);
    }
}

async function loadPermissionExplain() {
    const box = document.getElementById("permExplain");
    try {
        const data = await apiGet("/permissions/explain");

        const list = el("ul", { className: "explain-list" });
        (data.rules || []).forEach(rule => list.appendChild(el("li", { text: rule })));

        const rights = el("dl", { className: "field-list" });
        (data.rights || []).forEach(right => {
            rights.appendChild(el("dt", { text: right.letter + " - " + right.name }));
            rights.appendChild(el("dd", { text: "file: " + right.file + "; directory: " + right.directory }));
        });

        box.replaceChildren(
            el("p", { className: "muted", text: "Numeric values: 4 = read, 2 = write, 1 = execute." }),
            rights,
            list
        );
    } catch (error) {
        box.replaceChildren(el("p", { className: "muted", text: error.message }));
    }
}

document.getElementById("permApply").addEventListener("click", applyMode);

/* ============================================================
   MODULE 04 - Quiz
   ============================================================ */

const quizForm = document.getElementById("quizForm");
const quizResult = document.getElementById("quizResult");
const quizMeta = document.getElementById("quizMeta");

let quizQuestions = [];

async function loadQuiz() {
    try {
        const info = await apiGet("/quiz/info");
        quizMeta.textContent = info.total + " questions across "
            + (info.topics || []).map(topic => topic.name + " (" + topic.count + ")").join(", ");

        const data = await apiGet("/quiz/questions");
        quizQuestions = data.questions || [];
        renderQuizForm(quizQuestions);
        quizResult.replaceChildren();
    } catch (error) {
        quizForm.replaceChildren(el("p", { className: "muted", text: error.message }));
    }
}

function renderQuizForm(questions) {
    quizForm.replaceChildren();

    questions.forEach(question => {
        const fieldset = el("fieldset", { className: "quiz-question" });

        fieldset.appendChild(el("legend", { text: question.question }));
        fieldset.appendChild(el("span", { className: "topic-badge", text: question.topic }));

        question.options.forEach(option => {
            const input = el("input", {
                attrs: {
                    type: "radio",
                    name: "q_" + question.id,
                    value: option.letter
                }
            });
            const label = el("label", {
                className: "quiz-option",
                children: [input, el("span", { text: option.letter + ". " + option.text })]
            });
            fieldset.appendChild(label);
        });

        if (question.hint) {
            const hint = el("p", { className: "quiz-hint", text: "Hint: " + question.hint });
            hint.hidden = true;
            const toggle = el("button", {
                className: "mini-btn",
                text: "Show hint",
                attrs: { type: "button" }
            });
            toggle.addEventListener("click", () => {
                hint.hidden = !hint.hidden;
                toggle.textContent = hint.hidden ? "Show hint" : "Hide hint";
            });
            fieldset.appendChild(toggle);
            fieldset.appendChild(hint);
        }

        quizForm.appendChild(fieldset);
    });
}

function collectAnswers() {
    const answers = {};
    quizQuestions.forEach(question => {
        const chosen = document.querySelector("input[name='q_" + question.id + "']:checked");
        if (chosen) answers[question.id] = chosen.value;
    });
    return answers;
}

async function submitQuiz() {
    const answers = collectAnswers();

    if (Object.keys(answers).length === 0) {
        quizResult.replaceChildren(
            el("p", { className: "quiz-score", text: "Choose at least one answer before submitting." })
        );
        return;
    }

    try {
        const result = await apiSend("POST", "/quiz/submit", { answers });
        renderQuizResult(result);
    } catch (error) {
        quizResult.replaceChildren(el("p", { className: "quiz-score", text: error.message }));
    }
}

function renderQuizResult(result) {
    const summary = el("div", { className: "quiz-summary" });
    summary.appendChild(el("p", {
        className: "quiz-score",
        text: result.correct + " / " + result.total + " correct (" + result.percent + "%)"
    }));
    summary.appendChild(el("p", { className: "muted", text: result.performance.band + " - " + result.performance.message }));
    summary.appendChild(el("p", {
        className: "muted",
        text: "Correct: " + result.correct + " | Wrong: " + result.wrong + " | Unanswered: " + result.unanswered
    }));

    const reviews = el("div", { className: "quiz-review" });

    result.results.forEach(item => {
        const card = el("div", { className: "review-card " + (item.correct ? "good" : "bad") });
        card.appendChild(el("p", {
            className: "review-question",
            text: item.question
        }));
        card.appendChild(el("p", {
            className: "muted",
            text: "Your answer: " + (item.selected || "none") + " | Correct answer: " + item.answer
        }));
        if (item.explanation) {
            card.appendChild(el("p", { className: "review-explanation", text: item.explanation }));
        }
        reviews.appendChild(card);
    });

    quizResult.replaceChildren(summary, reviews);
}

document.getElementById("quizSubmit").addEventListener("click", submitQuiz);
document.getElementById("quizReset").addEventListener("click", () => {
    renderQuizForm(quizQuestions);
    quizResult.replaceChildren();
});

/* ============================================================
   Start
   ============================================================ */

loadCommands();
loadFiles("");
loadPermissions("");
loadPermissionExplain();
loadQuiz();

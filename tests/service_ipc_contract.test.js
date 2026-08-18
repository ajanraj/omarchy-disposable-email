const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const service = fs.readFileSync(path.join(__dirname, "..", "Service.qml"), "utf8")
const ipcTarget = "io.github.ajanraj.disposable-email"

const handlerStart = service.indexOf("IpcHandler")
assert.notEqual(handlerStart, -1, "Service.qml must declare an IpcHandler")
const handler = service.slice(handlerStart)

assert.match(
    handler,
    new RegExp(`target\\s*:\\s*[\"']${ipcTarget.replaceAll(".", "\\.")}[\"']`),
    "the IPC handler must use the plugin target"
)

assert.match(
    handler,
    /function\s+temporary\s*\(\s*provider\s*:\s*string\s*\)\s*:\s*string\s*\{/,
    "the IPC handler must expose temporary(provider: string): string"
)
for (const method of ["duckduckgo", "simplelogin"]) {
    assert.match(
        handler,
        new RegExp(`function\\s+${method}\\s*\\(\\s*\\)\\s*:\\s*string\\s*\\{`),
        `the IPC handler must expose ${method}(): string`
    )
}

const notificationArrays = [
    ...service.matchAll(/Quickshell\.execDetached\s*\(\s*(\[[\s\S]*?omarchy-notification-send[\s\S]*?\])\s*\)/g)
]
const notificationVariables = [
    ...service.matchAll(/\b(?:var|let|const)\s+([A-Za-z_$][\w$]*)\s*=\s*(\[[\s\S]*?omarchy-notification-send[\s\S]*?\])/g)
]
assert.notEqual(
    notificationArrays.length + notificationVariables.length,
    0,
    "notifications must use omarchy-notification-send"
)

for (const [, argv] of notificationArrays) {
    assert.match(argv.split(",", 1)[0], /omarchy-notification-send/)
    assert.doesNotMatch(argv, /\[\s*[\"'](?:bash|sh|zsh)[\"']\s*,/)
}
for (const [, variable, argv] of notificationVariables) {
    assert.match(argv.split(",", 1)[0], /omarchy-notification-send/)
    assert.match(
        service,
        new RegExp(`Quickshell\\.execDetached\\s*\\(\\s*${variable}\\s*\\)`),
        "the notification argv must be passed to execDetached"
    )
    assert.doesNotMatch(argv, /\[\s*[\"'](?:bash|sh|zsh)[\"']\s*,/)
}

assert.doesNotMatch(
    service,
    /Quickshell\.execDetached\s*\(\s*(?!\[|[A-Za-z_$][\w$]*\s*\))[\s\S]{0,300}omarchy-notification-send/,
    "notification commands must be passed as an argv array"
)

function withoutStringLiterals(value) {
    return value
        .replace(/"(?:\\.|[^"\\])*"/g, "")
        .replace(/'(?:\\.|[^'\\])*'/g, "")
}

const generatedValue = /\b(?:result|alias|payload)\s*(?:\.\s*(?:address|email|token)|\[\s*[\"'](?:address|email|token)[\"']\s*\])\b|\b(?:address|email|token)\b/
for (const [, argv] of notificationArrays.map(match => [match[0], match[1]])
    .concat(notificationVariables.map(match => [match[0], match[2]]))) {
    assert.doesNotMatch(
        withoutStringLiterals(argv),
        generatedValue,
        "notification text must not contain a generated address, email, or token"
    )
}

for (const [, args] of service.matchAll(/\b(?:_?notify|notifyToast|sendNotification|showToast|toast)\s*\(([^)]*)\)/gs)) {
    assert.doesNotMatch(
        withoutStringLiterals(args),
        generatedValue,
        "toast calls must not receive a generated address, email, or token"
    )
}

console.log("Service IPC contract tests passed")

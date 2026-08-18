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
    new RegExp(`target\\s*:\\s*["']${ipcTarget.replaceAll(".", "\\.")}["']`)
)
assert.match(handler, /function\s+temporary\s*\(\s*provider\s*:\s*string\s*\)\s*:\s*string\s*\{/)
for (const method of ["duckduckgo", "simplelogin"]) {
    assert.match(handler, new RegExp(`function\\s+${method}\\s*\\(\\s*\\)\\s*:\\s*string\\s*\\{`))
}

const notifyStart = service.indexOf("function _notify")
const notifyEnd = service.indexOf("function _quickBusy", notifyStart)
const notify = service.slice(notifyStart, notifyEnd)
assert.match(notify, /Quickshell\.execDetached\s*\(\s*\[/)
assert.match(notify, /omarchy-notification-send/)
assert.doesNotMatch(notify, /["'](?:bash|sh|zsh)["']/)

assert.match(service, /if \(selected === ""\) selected = temporaryProvider/)
assert.match(service, /selected !== "maildrop" && selected !== "harakiri"/)
assert.equal(
    [...service.matchAll(/if \(actionBusy \|\| _quickCreate !== null\) return _quickBusy\(\)/g)].length,
    3,
    "every IPC create path must reject repeated requests"
)

assert.match(service, /if \(exitCode === 0\)[\s\S]*?quick\.noun \+ " copied"/)
assert.match(service, /Could not copy to the clipboard/)
assert.match(service, /credential unavailable/)
assert.doesNotMatch(
    service,
    /_notify\([^)]*(?:result\.address|alias\.email|token)/s,
    "toast calls must not receive a generated address or token"
)

assert.match(service, /_quickMatches\("duckduckgo", "duck-generate"\)[^\n]*_copyQuick\(result\.address\)/)
assert.match(service, /else root\.copyText\(result\.address\)/)
assert.match(service, /_quickMatches\("simplelogin", "simple-random"\)[^\n]*_copyQuick\(alias\.email\)/)
assert.match(service, /else root\.copyText\(alias\.email\)/)

console.log("Service IPC contract tests passed")

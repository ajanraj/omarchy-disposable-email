const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

function read(name) {
    return fs.readFileSync(path.join(__dirname, "..", "ui", name), "utf8")
}

const views = ["TemporaryView.qml", "DuckView.qml", "SimpleLoginView.qml"]

for (const view of views) {
    const source = read(view)
    assert.match(source, /AddressHistoryCard\s*{/)
    assert.match(source, /reserveSpace:\s*true/)
    assert.doesNotMatch(source, /text:\s*"Working\.\.\."/)
}

assert.doesNotMatch(read("DuckView.qml"), /Unofficial integration/)

console.log("UI contract tests passed")

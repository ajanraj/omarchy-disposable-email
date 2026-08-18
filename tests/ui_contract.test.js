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

const panel = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8")
assert.doesNotMatch(panel, /\bFlickable\s*{/, "Panel.qml must not own the provider history scroll")
assert.match(panel, /\bLoader\s*{[\s\S]*anchors\.fill:\s*parent[\s\S]*sourceComponent:/)

const historySource = read("ScrollableHistory.qml")
const listIndex = historySource.indexOf("ListView {")
assert.ok(listIndex > 0, "shared history component must define a ListView")
assert.match(historySource, /\bPanelSectionHeader\s*{/, "shared history component must own the history title")
assert.match(historySource, /\bproperty\s+string\s+emptyText\b/, "shared history component must expose an empty state")
assert.match(historySource, /\bText\s*{[\s\S]*\bemptyText\b/, "shared history component must render its empty state")
assert.ok(historySource.indexOf("PanelSectionHeader {") < listIndex, "history title must remain fixed above the list")
assert.ok(historySource.indexOf("id: emptyState") < listIndex, "empty state must remain fixed above the list")

const controlsBeforeHistory = {
    "TemporaryView.qml": ["TEMPORARY ADDRESS", "Create"],
    "DuckView.qml": ["DUCKDUCKGO EMAIL PROTECTION", "Create Alias"],
    "SimpleLoginView.qml": ["SIMPLELOGIN", "Random Alias", "Custom Alias"]
}

for (const view of views) {
    const source = read(view)
    const historyIndex = source.indexOf("ScrollableHistory {")

    assert.equal((source.match(/\bScrollableHistory\s*{/g) || []).length, 1, `${view} must use one shared history component`)
    assert.doesNotMatch(source, /\bFlickable\s*{/, `${view} must not add a second scroll container`)
    assert.doesNotMatch(source, /\bListView\s*{/, `${view} must leave scrolling to the shared history component`)
    assert.doesNotMatch(source, /\bRepeater\s*{/, `${view} must not render history cards outside the shared component`)
    for (const text of controlsBeforeHistory[view]) {
        assert.ok(
            source.indexOf(text) < historyIndex,
            `${view} fixed control ${JSON.stringify(text)} must remain above the history list`
        )
    }

    if (view === "SimpleLoginView.qml") {
        for (const text of ["Previous", "Next", "Disconnect SimpleLogin"]) {
            assert.ok(
                source.indexOf(text) > historyIndex,
                `SimpleLogin ${text} control must remain outside the scrolling alias list`
            )
        }
    }
}

console.log("UI contract tests passed")

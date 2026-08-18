const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

function read(name) {
    return fs.readFileSync(path.join(__dirname, "..", "ui", name), "utf8")
}

const uiDirectory = path.join(__dirname, "..", "ui")

function matchingBrace(source, openIndex) {
    let depth = 0
    let quote = ""
    let escaped = false
    let lineComment = false
    let blockComment = false

    for (let index = openIndex; index < source.length; index++) {
        const character = source[index]
        const next = source[index + 1]

        if (lineComment) {
            if (character === "\n") lineComment = false
            continue
        }
        if (blockComment) {
            if (character === "*" && next === "/") {
                blockComment = false
                index++
            }
            continue
        }
        if (quote) {
            if (escaped) {
                escaped = false
            } else if (character === "\\") {
                escaped = true
            } else if (character === quote) {
                quote = ""
            }
            continue
        }
        if ((character === "\"" || character === "'") && !quote) {
            quote = character
        } else if (character === "/" && next === "/") {
            lineComment = true
            index++
        } else if (character === "/" && next === "*") {
            blockComment = true
            index++
        } else if (character === "{") {
            depth++
        } else if (character === "}" && --depth === 0) {
            return index
        }
    }

    return -1
}

function blocks(source, expression) {
    const result = []
    const matcher = new RegExp(expression.source, expression.flags.includes("g") ? expression.flags : `${expression.flags}g`)
    for (const match of source.matchAll(matcher)) {
        const openIndex = source.indexOf("{", match.index)
        const closeIndex = matchingBrace(source, openIndex)
        assert.notEqual(closeIndex, -1, `unclosed QML block for ${match[0]}`)
        result.push({ start: match.index, end: closeIndex + 1, text: source.slice(match.index, closeIndex + 1) })
    }
    return result
}

function oneBlock(source, expression, message) {
    const result = blocks(source, expression)
    assert.equal(result.length, 1, message || `expected one ${expression} block`)
    return result[0]
}

function isInside(inner, outer) {
    return inner.start > outer.start && inner.end <= outer.end
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
const viewLoader = oneBlock(panel, /\bLoader\s*{/, "Panel.qml must use one provider view Loader")
assert.match(viewLoader.text, /anchors\.fill:\s*parent/)
assert.match(viewLoader.text, /sourceComponent:/)

const scrollableFiles = fs.readdirSync(uiDirectory)
    .filter(name => name.endsWith(".qml"))
    .filter(name => /\bListView\s*{/.test(read(name)))
assert.equal(
    scrollableFiles.length,
    1,
    "provider histories must share one ListView component instead of defining one per view"
)

const historyFile = scrollableFiles[0]
const historySource = read(historyFile)
const historyName = historyFile.slice(0, -4)
const listView = oneBlock(historySource, /\bListView\s*{/, "shared history component must define one ListView")
assert.match(historySource, /\bPanelSectionHeader\s*{/, "shared history component must own the history title")
assert.match(historySource, /\bproperty\s+string\s+emptyText\b/, "shared history component must expose an empty state")
assert.match(historySource, /\bText\s*{[\s\S]*\bemptyText\b/, "shared history component must render its empty state")
assert.match(historySource, /\bmodel\s*:/, "shared history component must accept a history model")
assert.match(historySource, /\bdelegate\s*:/, "shared history component must render card delegates")
assert.doesNotMatch(historySource, /\bFlickable\s*{/, "history should use one bounded card list")

const emptyState = blocks(historySource, /\bText\s*{/).find(block => /\bemptyText\b/.test(block.text))
assert.ok(emptyState, "shared history component must have a Text empty state")
assert.equal(isInside(emptyState, listView), false, "history empty state must remain outside the scrolling ListView")
const title = oneBlock(historySource, /\bPanelSectionHeader\s*{/, "shared history component must have one fixed title")
assert.equal(isInside(title, listView), false, "history title must remain outside the scrolling ListView")

const controlsBeforeHistory = {
    "TemporaryView.qml": ["TEMPORARY ADDRESS", "Create"],
    "DuckView.qml": ["DUCKDUCKGO EMAIL PROTECTION", "Create Alias"],
    "SimpleLoginView.qml": ["SIMPLELOGIN", "Random Alias", "Custom Alias"]
}

for (const view of views) {
    const source = read(view)
    const historyInstances = blocks(source, new RegExp(`\\b${historyName}\\s*{`))
    assert.equal(historyInstances.length, 1, `${view} must use the shared ${historyName} component exactly once`)
    const historyInstance = historyInstances[0]

    assert.doesNotMatch(source, /\bFlickable\s*{/, `${view} must not add a second scroll container`)
    assert.doesNotMatch(source, /\bRepeater\s*{/, `${view} must not render history cards outside ${historyName}`)
    for (const text of controlsBeforeHistory[view]) {
        assert.ok(
            source.indexOf(text) < historyInstance.start,
            `${view} fixed control ${JSON.stringify(text)} must remain above the history list`
        )
    }

    if (view === "SimpleLoginView.qml") {
        for (const text of ["Previous", "Next", "Disconnect SimpleLogin"]) {
            assert.ok(
                source.indexOf(text, historyInstance.end) !== -1,
                `SimpleLogin ${text} control must remain outside the scrolling alias list`
            )
        }
    }
}

console.log("UI contract tests passed")

#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const providersDir = path.resolve(__dirname, "..")
const fixturesDir = path.join(__dirname, "fixtures")

function source(name) {
    return fs.readFileSync(path.join(providersDir, name), "utf8")
        .replace(/^\.import .*$/gm, "")
}

function helper(name, dependencies = {}) {
    const context = vm.createContext({
        Array,
        Boolean,
        JSON,
        Math,
        Number,
        Object,
        RegExp,
        String,
        encodeURIComponent,
        isFinite,
        ...dependencies
    })
    vm.runInContext(source(name), context, { filename: name })
    return context
}

function fixture(name) {
    return fs.readFileSync(path.join(fixturesDir, name), "utf8").trimEnd()
}

const Http = helper("Http.js")
const Temporary = helper("TemporaryAddress.js")
const Duck = helper("DuckDuckGo.js", { Http })
const SimpleLogin = helper("SimpleLogin.js", { Http })

const temporary = Temporary.fromRandom("maildrop", "YWJjZGVmZ2hpamts\n")
assert.equal(temporary.ok, true)
assert.equal(temporary.value.address, "YWJjZGVmZ2hpam@maildrop.cc")
assert.equal(temporary.value.inboxUrl, "https://maildrop.cc/inbox/?mailbox=YWJjZGVmZ2hpam")
assert.equal(Temporary.fromRandom("harakiri", "Ab+/CdEfGhIjKw==").value.localPart, "Ab-_CdEfGhIjKw")
assert.equal(Temporary.fromRandom("unknown", "YWJjZGVmZ2hpamts").ok, false)
assert.equal(Temporary.fromRandom("maildrop", "too-short").ok, false)

const duckRequest = Duck.request("status", "not-a-real-token", "Name@duck.com", false)
assert.equal(duckRequest.ok, true)
assert.match(duckRequest.config, /Authorization: Bearer not-a-real-token/)
assert.match(duckRequest.config, /header = "User-Agent: Mozilla\/5\.0"/)
assert.match(duckRequest.config, /address=name/)
const duckToggle = Duck.request("setActive", "not-a-real-token", "Name@duck.com", false)
assert.match(duckToggle.config, /request = \"PUT\"/)
assert.match(duckToggle.config, /active=false/)
const generated = Duck.parse("generate", fixture("duck-generate-success.txt"), "", false)
assert.equal(generated.ok, true)
assert.equal(generated.value.address, "sample_alias@duck.com")
assert.equal(Duck.parse("generate", fixture("unauthorized.txt"), "", false).status, 401)
assert.match(Duck.parse("generate", fixture("malformed.txt"), "", false).error, /malformed JSON/)

const custom = SimpleLogin.customRequest(
    "not-a-real-key", "orders", "signed-suffix", [1, 2], "Orders", ""
)
assert.equal(custom.ok, true)
assert.match(custom.config, /Created with Disposable Email/)
assert.match(custom.config, /\\"name\\":\\"Orders\\"/)

const aliases = SimpleLogin.aliasesRequest("not-a-real-key", "shop", "disabled", 2)
assert.equal(aliases.ok, true)
assert.match(aliases.config, /request = "POST"/)
assert.match(aliases.config, /request = \"POST\"/)
assert.match(aliases.config, /page_id=2&disabled=true/)
assert.match(aliases.config, /\\"query\\":\\"shop\\"/)
assert.equal(SimpleLogin.aliasesRequest("key", "", "invalid", 0).ok, false)
assert.match(SimpleLogin.pinnedRequest("key", 42, true).config, /request = \"PATCH\"/)
assert.match(SimpleLogin.pinnedRequest("key", 42, true).config, /\\"pinned\\":true/)
assert.match(SimpleLogin.toggleRequest("key", 42).config, /aliases\/42\/toggle/)

const options = SimpleLogin.parseCustomOptions(fixture("simple-options-success.txt"))
assert.equal(options.ok, true)
assert.equal(options.value.mailboxes.length, 1)
assert.equal(options.value.mailboxes[0].id, 1)
assert.equal(options.value.prefixSuggestion, "shop")
assert.equal(options.value.suffixes[0].value, "signed")
assert.equal(options.value.suffixes[0].label, ".cat@simplelogin.com")

const normalizedAlias = SimpleLogin.parseAlias(fixture("simple-alias-success.txt"))
assert.equal(normalizedAlias.ok, true)
assert.equal(normalizedAlias.value.email, "orders@example.com")
assert.equal(normalizedAlias.value.mailboxes[0].email, "owner@example.com")
assert.equal(normalizedAlias.value.counters, "3 fwd, 2 replied, 1 blocked")

const normalizedAliases = SimpleLogin.parseAliases(fixture("simple-aliases-success.txt"))
assert.equal(normalizedAliases.ok, true)
assert.equal(normalizedAliases.value.length, 1)
assert.equal(normalizedAliases.value[0].enabled, false)
assert.equal(normalizedAliases.value[0].pinned, true)

const unauthorized = SimpleLogin.parse(fixture("unauthorized.txt"))
assert.equal(unauthorized.status, 401)
assert.equal(unauthorized.error, "Invalid API key")
const planLimit = SimpleLogin.parse(fixture("plan-limit.txt"))
assert.equal(SimpleLogin.isPlanLimit(planLimit), true)
assert.match(SimpleLogin.parse(fixture("malformed.txt")).error, /malformed JSON/)

assert.deepEqual(
    Array.from(Duck.localPart("alias@duck.com@duck.com")),
    Array.from("")
)

console.log("provider helper tests passed")

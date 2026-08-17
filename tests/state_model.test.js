const assert = require("node:assert/strict")
const StateModel = require("../lib/StateModel.js")

function temporary(provider = "maildrop") {
    return {
        provider,
        localPart: "abc123",
        address: provider === "maildrop" ? "abc123@maildrop.cc" : "abc123@harakirimail.com",
        inboxUrl: provider === "maildrop"
            ? "https://maildrop.cc/inbox/?mailbox=abc123"
            : "https://harakirimail.com/inbox/abc123"
    }
}

function alias(address = "alias@duck.com", active = true) {
    return { address, active }
}

function testDefaults() {
    assert.deepEqual(StateModel.defaults(), {
        version: 1,
        lastTab: "temporary",
        temporaryProvider: "maildrop",
        temporaryAddress: null,
        knownDuckAliases: []
    })
}

function testRoundTrip() {
    const input = {
        version: 1,
        lastTab: "duckduckgo",
        temporaryProvider: "harakiri",
        temporaryAddress: temporary("harakiri"),
        knownDuckAliases: [alias("Alias@Duck.com", false)],
        credentials: { duckduckgo: "must-not-survive" },
        unknown: "ignored"
    }
    const serialized = StateModel.serialize(input)
    const parsed = StateModel.parse(serialized)

    assert.deepEqual(parsed, {
        version: 1,
        lastTab: "duckduckgo",
        temporaryProvider: "harakiri",
        temporaryAddress: temporary("harakiri"),
        knownDuckAliases: [{ address: "alias@duck.com", localPart: "alias", active: false }]
    })
    assert.equal(serialized, StateModel.serialize(parsed))
    assert.equal(serialized.includes("must-not-survive"), false)
}

function testMalformedInput() {
    const malformed = ["", "{", "[]", "null", null, undefined, 7, { version: 2 }, { version: "1" }]
    for (const value of malformed)
        assert.deepEqual(StateModel.parse(value), StateModel.defaults())
}

function testValidation() {
    const parsed = StateModel.parse({
        version: 1,
        lastTab: "not-a-tab",
        temporaryProvider: "not-a-provider",
        temporaryAddress: {
            provider: "maildrop",
            localPart: "wrong",
            address: "not-an-address",
            inboxUrl: "file:///tmp/inbox"
        },
        knownDuckAliases: [
            alias("valid@duck.com"),
            alias("bad@example.com"),
            { address: "missing-at" },
            { address: "valid@duck.com", active: "yes" }
        ]
    })

    assert.equal(parsed.lastTab, "temporary")
    assert.equal(parsed.temporaryProvider, "maildrop")
    assert.equal(parsed.temporaryAddress, null)
    assert.deepEqual(parsed.knownDuckAliases, [
        { address: "valid@duck.com", localPart: "valid", active: true }
    ])
    assert.equal(StateModel.isValidProvider("harakiri"), true)
    assert.equal(StateModel.isValidProvider("credentials"), false)
    assert.equal(StateModel.isValidTemporaryAddress(temporary()), true)
    assert.equal(StateModel.isValidTemporaryAddress({}), false)
    assert.equal(StateModel.isValidDuckAlias(alias()), true)
    assert.equal(StateModel.isValidDuckAlias(alias("not-an-email")), false)
}

function testDeduplication() {
    const parsed = StateModel.parse({
        version: 1,
        knownDuckAliases: [
            alias("One@duck.com", false),
            alias("one@DUCK.COM", true),
            alias("two@duck.com", false)
        ]
    })

    assert.deepEqual(parsed.knownDuckAliases, [
        { address: "one@duck.com", localPart: "one", active: false },
        { address: "two@duck.com", localPart: "two", active: false }
    ])
}

function testResetAndMutations() {
    let state = StateModel.defaults()
    state = StateModel.setLastTab(state, "simplelogin")
    state = StateModel.setTemporaryProvider(state, "harakiri")
    state = StateModel.setTemporaryAddress(state, temporary("harakiri"))
    state = StateModel.addDuckAlias(state, alias())
    state = StateModel.updateDuckAlias(state, "alias@duck.com", false)
    assert.equal(state.lastTab, "simplelogin")
    assert.equal(state.temporaryAddress.provider, "harakiri")
    assert.equal(state.knownDuckAliases[0].active, false)

    state = StateModel.removeDuckAlias(state, "ALIAS@DUCK.COM")
    state = StateModel.clearTemporaryAddress(state)
    assert.equal(state.knownDuckAliases.length, 0)
    assert.equal(state.temporaryAddress, null)
    assert.deepEqual(StateModel.reset(), StateModel.defaults())
}

function testProviderPreferenceDoesNotForgetCurrentAddress() {
    let state = StateModel.defaults()
    state = StateModel.setTemporaryAddress(state, temporary("maildrop"))
    state = StateModel.setTemporaryProvider(state, "harakiri")
    assert.equal(state.temporaryProvider, "harakiri")
    assert.equal(state.temporaryAddress.address, "abc123@maildrop.cc")
}

testDefaults()
testRoundTrip()
testMalformedInput()
testValidation()
testDeduplication()
testResetAndMutations()
testProviderPreferenceDoesNotForgetCurrentAddress()
console.log("StateModel tests passed")

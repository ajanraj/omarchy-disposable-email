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
        version: 2,
        lastTab: "temporary",
        temporaryProvider: "maildrop",
        temporaryAddresses: [],
        knownDuckAliases: []
    })
}

function testRoundTrip() {
    const input = {
        version: 2,
        lastTab: "duckduckgo",
        temporaryProvider: "harakiri",
        temporaryAddresses: [temporary("harakiri"), temporary("maildrop")],
        knownDuckAliases: [alias("Alias@Duck.com", false)],
        credentials: { duckduckgo: "must-not-survive" },
        unknown: "ignored"
    }
    const serialized = StateModel.serialize(input)
    const parsed = StateModel.parse(serialized)

    assert.deepEqual(parsed, {
        version: 2,
        lastTab: "duckduckgo",
        temporaryProvider: "harakiri",
        temporaryAddresses: [temporary("harakiri"), temporary("maildrop")],
        knownDuckAliases: [{ address: "alias@duck.com", localPart: "alias", active: false }]
    })
    assert.equal(serialized, StateModel.serialize(parsed))
    assert.equal(serialized.includes("must-not-survive"), false)
}

function testVersionOneMigration() {
    const parsed = StateModel.parse({
        version: 1,
        lastTab: "temporary",
        temporaryProvider: "harakiri",
        temporaryAddress: temporary("maildrop"),
        knownDuckAliases: [alias()]
    })

    assert.equal(parsed.version, 2)
    assert.deepEqual(parsed.temporaryAddresses, [temporary("maildrop")])
    assert.equal(parsed.temporaryProvider, "harakiri")
    assert.equal(parsed.knownDuckAliases.length, 1)
}

function testMalformedInput() {
    const malformed = ["", "{", "[]", "null", null, undefined, 7, { version: 3 }, { version: "1" }]
    for (const value of malformed)
        assert.deepEqual(StateModel.parse(value), StateModel.defaults())
}

function testValidation() {
    const parsed = StateModel.parse({
        version: 2,
        lastTab: "not-a-tab",
        temporaryProvider: "not-a-provider",
        temporaryAddresses: [
            temporary("maildrop"),
            temporary("maildrop"),
            { provider: "maildrop", localPart: "wrong", address: "not-an-address", inboxUrl: "file:///tmp/inbox" }
        ],
        knownDuckAliases: [
            alias("valid@duck.com"),
            alias("bad@example.com"),
            { address: "missing-at" },
            { address: "valid@duck.com", active: "yes" }
        ]
    })

    assert.equal(parsed.lastTab, "temporary")
    assert.equal(parsed.temporaryProvider, "maildrop")
    assert.deepEqual(parsed.temporaryAddresses, [temporary("maildrop")])
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
        version: 2,
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
    state = StateModel.addTemporaryAddress(state, temporary("harakiri"))
    state = StateModel.addTemporaryAddress(state, temporary("maildrop"))
    state = StateModel.addDuckAlias(state, alias())
    state = StateModel.updateDuckAlias(state, "alias@duck.com", false)
    assert.equal(state.lastTab, "simplelogin")
    assert.deepEqual(state.temporaryAddresses.map(item => item.provider), ["maildrop", "harakiri"])
    assert.equal(state.knownDuckAliases[0].active, false)

    state = StateModel.removeDuckAlias(state, "ALIAS@DUCK.COM")
    state = StateModel.removeTemporaryAddress(state, "abc123@maildrop.cc")
    assert.equal(state.knownDuckAliases.length, 0)
    assert.deepEqual(state.temporaryAddresses, [temporary("harakiri")])
    assert.deepEqual(StateModel.reset(), StateModel.defaults())
}

function testProviderPreferenceDoesNotForgetHistory() {
    let state = StateModel.defaults()
    state = StateModel.addTemporaryAddress(state, temporary("maildrop"))
    state = StateModel.setTemporaryProvider(state, "harakiri")
    assert.equal(state.temporaryProvider, "harakiri")
    assert.equal(state.temporaryAddresses[0].address, "abc123@maildrop.cc")
}

testDefaults()
testRoundTrip()
testVersionOneMigration()
testMalformedInput()
testValidation()
testDeduplication()
testResetAndMutations()
testProviderPreferenceDoesNotForgetHistory()
console.log("StateModel tests passed")

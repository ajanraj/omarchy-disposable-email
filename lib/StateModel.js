// Pure, credential-free state normalization for the Disposable Email service.
// The module is also CommonJS-compatible so the same seam can be tested with
// the local Node runtime without introducing a test-only implementation.

var VERSION = 1

var TABS = ["temporary", "duckduckgo", "simplelogin"]
var TEMPORARY_PROVIDERS = ["maildrop", "harakiri"]
var PROVIDERS = ["maildrop", "harakiri", "duckduckgo", "simplelogin"]

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function isNonEmptyString(value) {
    return typeof value === "string" && value.trim().length > 0
}

function contains(values, value) {
    for (var i = 0; i < values.length; i++) {
        if (values[i] === value)
            return true
    }
    return false
}

function isTab(value) {
    return typeof value === "string" && contains(TABS, value)
}

function isProvider(value) {
    return typeof value === "string" && contains(PROVIDERS, value)
}

function isTemporaryProvider(value) {
    return typeof value === "string" && contains(TEMPORARY_PROVIDERS, value)
}

function copy(value) {
    if (!isObject(value))
        return value

    var result = {}
    for (var key in value) {
        if (Object.prototype.hasOwnProperty.call(value, key))
            result[key] = value[key]
    }
    return result
}

function temporaryAddressRecord(value) {
    if (!isObject(value) || !isTemporaryProvider(value.provider))
        return null

    var localPart = isNonEmptyString(value.localPart) ? value.localPart.trim().toLowerCase() : ""
    var address = isNonEmptyString(value.address) ? value.address.trim().toLowerCase() : ""
    var expectedDomain = value.provider === "maildrop" ? "maildrop.cc" : "harakirimail.com"
    var addressPattern = new RegExp("^[a-z0-9][a-z0-9._-]*@" + expectedDomain.replace(".", "\\.") + "$")

    if (!addressPattern.test(address))
        return null

    var addressLocalPart = address.slice(0, address.length - expectedDomain.length - 1)
    if (!/^[a-z0-9][a-z0-9._-]*$/.test(addressLocalPart))
        return null
    if (localPart && localPart !== addressLocalPart)
        return null

    var inboxUrl = isNonEmptyString(value.inboxUrl) ? value.inboxUrl.trim() : ""
    var expectedInboxUrl = value.provider === "maildrop"
        ? "https://maildrop.cc/inbox/?mailbox=" + encodeURIComponent(addressLocalPart)
        : "https://harakirimail.com/inbox/" + encodeURIComponent(addressLocalPart)
    if (inboxUrl !== expectedInboxUrl)
        return null

    return {
        provider: value.provider,
        localPart: addressLocalPart,
        address: address,
        inboxUrl: inboxUrl
    }
}

function duckAliasRecord(value) {
    var source = value
    if (typeof source === "string")
        source = { address: source }
    if (!isObject(source))
        return null

    var addressValue = source.address
    if (!isNonEmptyString(addressValue))
        addressValue = source.alias
    if (!isNonEmptyString(addressValue))
        addressValue = source.email
    if (!isNonEmptyString(addressValue))
        return null

    var address = addressValue.trim().toLowerCase()
    var match = /^([a-z0-9][a-z0-9._-]*)@duck\.com$/.exec(address)
    if (!match)
        return null
    if (source.provider !== undefined && source.provider !== "duckduckgo")
        return null

    return {
        address: address,
        localPart: match[1],
        active: typeof source.active === "boolean"
            ? source.active
            : (typeof source.enabled === "boolean" ? source.enabled : true)
    }
}

function uniqueDuckAliases(values) {
    if (!Array.isArray(values))
        return []

    var result = []
    var seen = {}
    for (var i = 0; i < values.length; i++) {
        var alias = duckAliasRecord(values[i])
        if (!alias || seen[alias.address])
            continue
        seen[alias.address] = true
        result.push(alias)
    }
    return result
}

function defaults() {
    return {
        version: VERSION,
        lastTab: "temporary",
        temporaryProvider: "maildrop",
        temporaryAddress: null,
        knownDuckAliases: []
    }
}

function parse(raw) {
    var input = raw
    if (typeof input === "string") {
        if (input.trim().length === 0)
            return defaults()
        try {
            input = JSON.parse(input)
        } catch (error) {
            return defaults()
        }
    }

    if (!isObject(input) || input.version !== VERSION)
        return defaults()

    var result = defaults()
    if (isTab(input.lastTab))
        result.lastTab = input.lastTab
    if (isTemporaryProvider(input.temporaryProvider))
        result.temporaryProvider = input.temporaryProvider

    result.temporaryAddress = temporaryAddressRecord(input.temporaryAddress)
    result.knownDuckAliases = uniqueDuckAliases(input.knownDuckAliases)
    return result
}

function normalize(value) {
    if (typeof value === "string")
        return parse(value)

    var input = isObject(value) ? copy(value) : defaults()
    input.version = VERSION
    return parse(input)
}

function serialize(value) {
    var state = normalize(value)
    return JSON.stringify(state, null, 2)
}

function setLastTab(value, tab) {
    var state = normalize(value)
    if (isTab(tab))
        state.lastTab = tab
    return state
}

function setTemporaryProvider(value, provider) {
    var state = normalize(value)
    if (!isTemporaryProvider(provider))
        return state

    state.temporaryProvider = provider
    return state
}

function setTemporaryAddress(value, address) {
    var state = normalize(value)
    var normalized = temporaryAddressRecord(address)
    if (normalized && normalized.provider === state.temporaryProvider)
        state.temporaryAddress = normalized
    else if (!normalized)
        state.temporaryAddress = null
    return state
}

function clearTemporaryAddress(value) {
    var state = normalize(value)
    state.temporaryAddress = null
    return state
}

function addDuckAlias(value, alias) {
    var state = normalize(value)
    var normalized = duckAliasRecord(alias)
    if (!normalized)
        return state

    var next = []
    var replaced = false
    for (var i = 0; i < state.knownDuckAliases.length; i++) {
        var existing = state.knownDuckAliases[i]
        if (existing.address === normalized.address) {
            next.push(normalized)
            replaced = true
        } else {
            next.push(existing)
        }
    }
    if (!replaced)
        next.push(normalized)
    state.knownDuckAliases = next
    return state
}

function removeDuckAlias(value, address) {
    var state = normalize(value)
    var target = isNonEmptyString(address) ? address.trim().toLowerCase() : ""
    if (!target)
        return state
    var next = []
    for (var i = 0; i < state.knownDuckAliases.length; i++) {
        if (state.knownDuckAliases[i].address !== target)
            next.push(state.knownDuckAliases[i])
    }
    state.knownDuckAliases = next
    return state
}

function updateDuckAlias(value, address, active) {
    var state = normalize(value)
    var target = isNonEmptyString(address) ? address.trim().toLowerCase() : ""
    if (!target || typeof active !== "boolean")
        return state
    for (var i = 0; i < state.knownDuckAliases.length; i++) {
        if (state.knownDuckAliases[i].address === target)
            state.knownDuckAliases[i].active = active
    }
    return state
}

function reset() {
    return defaults()
}

function isValidTab(value) {
    return isTab(value)
}

function isValidProvider(value) {
    return isProvider(value)
}

function isValidTemporaryAddress(value) {
    return temporaryAddressRecord(value) !== null
}

function isValidDuckAlias(value) {
    return duckAliasRecord(value) !== null
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        VERSION: VERSION,
        TABS: TABS,
        PROVIDERS: PROVIDERS,
        TEMPORARY_PROVIDERS: TEMPORARY_PROVIDERS,
        defaults: defaults,
        parse: parse,
        normalize: normalize,
        serialize: serialize,
        reset: reset,
        setLastTab: setLastTab,
        setTemporaryProvider: setTemporaryProvider,
        setTemporaryAddress: setTemporaryAddress,
        clearTemporaryAddress: clearTemporaryAddress,
        addDuckAlias: addDuckAlias,
        removeDuckAlias: removeDuckAlias,
        updateDuckAlias: updateDuckAlias,
        isValidTab: isValidTab,
        isValidProvider: isValidProvider,
        isValidTemporaryAddress: isValidTemporaryAddress,
        isValidDuckAlias: isValidDuckAlias
    }
}

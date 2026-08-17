.import "Http.js" as Http

var API_URL = "https://app.simplelogin.io/api"
var DEFAULT_NOTE = "Created with Disposable Email"

function auth(token) {
    if (!Http.isSafeCredential(token))
        return { ok: false, error: "SimpleLogin API key is missing or invalid" }
    return { ok: true, header: "Authentication: " + token }
}

function validId(id) {
    return typeof id === "number" && isFinite(id) && Math.floor(id) === id && id > 0
}

function normalizeMailbox(mailbox) {
    if (!mailbox || typeof mailbox !== "object" || !validId(Number(mailbox.id))
            || typeof mailbox.email !== "string" || mailbox.email.length === 0)
        return null
    return {
        id: Number(mailbox.id),
        email: mailbox.email,
        default: mailbox.default === true
    }
}

function normalizeSuffix(suffix) {
    if (!suffix || typeof suffix !== "object" || typeof suffix.signed_suffix !== "string"
            || suffix.signed_suffix.length === 0 || typeof suffix.suffix !== "string")
        return null
    return {
        value: suffix.signed_suffix,
        label: suffix.suffix,
        premium: suffix.is_premium === true,
        custom: suffix.is_custom === true
    }
}

function normalizeAlias(alias) {
    if (!alias || typeof alias !== "object" || !validId(Number(alias.id))
            || typeof alias.email !== "string" || alias.email.length === 0)
        return null

    var sourceMailboxes = Array.isArray(alias.mailboxes) ? alias.mailboxes
        : alias.mailbox ? [alias.mailbox] : []
    var mailboxes = []
    for (var i = 0; i < sourceMailboxes.length; i++) {
        var mailbox = normalizeMailbox(sourceMailboxes[i])
        if (mailbox) mailboxes.push(mailbox)
    }

    var forwarded = Number(alias.nb_forward) || 0
    var replied = Number(alias.nb_reply) || 0
    var blocked = Number(alias.nb_block) || 0
    return {
        id: Number(alias.id),
        email: alias.email,
        name: typeof alias.name === "string" ? alias.name : "",
        enabled: alias.enabled !== false,
        pinned: alias.pinned === true,
        mailboxes: mailboxes,
        nbForward: forwarded,
        nbReply: replied,
        nbBlock: blocked,
        counters: forwarded + " fwd, " + replied + " replied, " + blocked + " blocked"
    }
}

function build(token, method, path, body) {
    var authentication = auth(token)
    if (!authentication.ok)
        return authentication
    return {
        ok: true,
        config: Http.buildConfig(method, API_URL + path, authentication.header, body)
    }
}

function randomRequest(token) {
    return build(token, "POST", "/alias/random/new", { note: DEFAULT_NOTE })
}

function optionsRequest(token) {
    return build(token, "GET", "/v5/alias/options")
}

function mailboxesRequest(token) {
    return build(token, "GET", "/v2/mailboxes")
}

function customOptionsRequest(token) {
    var options = optionsRequest(token)
    var mailboxes = mailboxesRequest(token)
    if (!options.ok)
        return options
    if (!mailboxes.ok)
        return mailboxes
    return {
        ok: true,
        config: options.config + "next\n" + mailboxes.config
    }
}

function customRequest(token, prefix, suffix, mailboxIds, name, note) {
    if (typeof prefix !== "string" || prefix.trim().length === 0)
        return { ok: false, error: "Alias prefix is required" }
    if (typeof suffix !== "string" || suffix.length === 0)
        return { ok: false, error: "Alias suffix is required" }
    if (!Array.isArray(mailboxIds) || mailboxIds.length === 0 || !mailboxIds.every(validId))
        return { ok: false, error: "At least one valid mailbox is required" }

    var body = {
        alias_prefix: prefix.trim(),
        signed_suffix: suffix,
        mailbox_ids: mailboxIds,
        note: typeof note === "string" && note.length > 0 ? note : DEFAULT_NOTE
    }
    if (typeof name === "string" && name.trim().length > 0)
        body.name = name.trim()
    return build(token, "POST", "/v3/alias/custom/new", body)
}

function aliasesRequest(token, query, filter, page) {
    var supportedFilters = ["all", "enabled", "disabled", "pinned"]
    if (supportedFilters.indexOf(filter) === -1)
        return { ok: false, error: "Unknown alias filter" }
    if (typeof page !== "number" || !isFinite(page) || Math.floor(page) !== page || page < 0)
        return { ok: false, error: "Alias page must be a non-negative integer" }

    var path = "/v2/aliases?page_id=" + page
    if (filter !== "all")
        path += "&" + filter + "=true"
    var trimmedQuery = typeof query === "string" ? query.trim() : ""
    var body = trimmedQuery.length > 0 ? { query: trimmedQuery } : null
    return build(token, "POST", path, body)
}

function pinnedRequest(token, aliasId, pinned) {
    if (!validId(aliasId))
        return { ok: false, error: "Alias ID is invalid" }
    return build(token, "PATCH", "/aliases/" + aliasId, { pinned: Boolean(pinned) })
}

function toggleRequest(token, aliasId) {
    if (!validId(aliasId))
        return { ok: false, error: "Alias ID is invalid" }
    return build(token, "POST", "/aliases/" + aliasId + "/toggle")
}

function parse(output) {
    var response = Http.parseResponse(output)
    if (!response.ok)
        response.error = response.error || Http.errorMessage(response, "SimpleLogin request failed")
    return response
}

function parseAlias(output) {
    var response = parse(output)
    if (!response.ok)
        return response
    var alias = normalizeAlias(response.body)
    if (!alias)
        return { ok: false, status: response.status, error: "SimpleLogin returned an invalid alias" }
    response.value = alias
    return response
}

function parseOptions(output) {
    return parseOptionsFromResponse(Http.parseResponse(output))
}

function parseMailboxes(output) {
    return parseMailboxesFromResponse(Http.parseResponse(output))
}

function parseCustomOptions(output) {
    var combined = Http.parseResponses(output, 2)
    if (!combined.ok)
        return combined

    var options = parseOptionsFromResponse(combined.responses[0])
    if (!options.ok)
        return options
    var mailboxResponse = parseMailboxesFromResponse(combined.responses[1])
    if (!mailboxResponse.ok)
        return mailboxResponse

    var suffixes = []
    for (var i = 0; i < options.value.suffixes.length; i++) {
        var suffix = normalizeSuffix(options.value.suffixes[i])
        if (!suffix)
            return { ok: false, error: "SimpleLogin returned an invalid alias suffix" }
        suffixes.push(suffix)
    }

    var mailboxes = []
    for (var j = 0; j < mailboxResponse.value.length; j++) {
        var mailbox = normalizeMailbox(mailboxResponse.value[j])
        if (!mailbox)
            return { ok: false, error: "SimpleLogin returned an invalid mailbox" }
        mailboxes.push(mailbox)
    }

    return {
        ok: true,
        value: {
            canCreate: options.value.can_create !== false,
            prefixSuggestion: options.value.prefix_suggestion || "",
            suffixes: suffixes,
            recommendation: options.value.recommendation || null,
            mailboxes: mailboxes
        }
    }
}

function parseOptionsFromResponse(response) {
    if (!response.ok) {
        response.error = response.error || Http.errorMessage(response, "SimpleLogin request failed")
        return response
    }
    if (!response.body || typeof response.body !== "object" || !Array.isArray(response.body.suffixes))
        return { ok: false, status: response.status, error: "SimpleLogin returned invalid alias options" }
    response.value = response.body
    return response
}

function parseMailboxesFromResponse(response) {
    if (!response.ok) {
        response.error = response.error || Http.errorMessage(response, "SimpleLogin request failed")
        return response
    }
    if (!response.body || !Array.isArray(response.body.mailboxes))
        return { ok: false, status: response.status, error: "SimpleLogin returned invalid mailboxes" }
    response.value = response.body.mailboxes.filter(function(mailbox) {
        return mailbox && mailbox.verified === true
    })
    return response
}

function parseAliases(output) {
    var response = parse(output)
    if (!response.ok)
        return response
    var aliases = Array.isArray(response.body) ? response.body
        : response.body && Array.isArray(response.body.aliases) ? response.body.aliases : null
    if (aliases === null)
        return { ok: false, status: response.status, error: "SimpleLogin returned an invalid alias list" }
    var normalized = []
    for (var i = 0; i < aliases.length; i++) {
        var alias = normalizeAlias(aliases[i])
        if (!alias)
            return { ok: false, status: response.status, error: "SimpleLogin returned an invalid alias list" }
        normalized.push(alias)
    }
    response.value = normalized
    return response
}

function parsePinned(output, aliasId, pinned) {
    var response = parse(output)
    if (!response.ok)
        return response
    response.value = { id: aliasId, pinned: Boolean(pinned) }
    return response
}

function parseToggle(output, aliasId) {
    var response = parse(output)
    if (!response.ok)
        return response
    if (!response.body || typeof response.body.enabled !== "boolean")
        return { ok: false, status: response.status, error: "SimpleLogin returned an invalid alias status" }
    response.value = { id: aliasId, enabled: response.body.enabled }
    return response
}

function isPlanLimit(response) {
    if (!response || response.ok || [400, 402, 403].indexOf(response.status) === -1)
        return false
    return /(limit|quota|premium|upgrade|free (plan|account)|paid plan|maximum number of aliases)/i.test(response.error || "")
}

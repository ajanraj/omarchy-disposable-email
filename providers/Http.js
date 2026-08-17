var STATUS_MARKER = "\n__OMARCHY_DISPOSABLE_EMAIL_HTTP_614e7d__:"

function isSafeCredential(value) {
    return typeof value === "string" && value.length > 0
        && value.indexOf("\r") === -1 && value.indexOf("\n") === -1
}

function quoteConfig(value) {
    return String(value)
        .replace(/\\/g, "\\\\")
        .replace(/\"/g, "\\\"")
        .replace(/\r/g, "\\r")
        .replace(/\n/g, "\\n")
        .replace(/\t/g, "\\t")
}

function buildConfig(method, url, authenticationHeader, body) {
    var lines = [
        "silent",
        "show-error",
        "connect-timeout = 10",
        "max-time = 30",
        "request = \"" + quoteConfig(method) + "\"",
        "url = \"" + quoteConfig(url) + "\"",
        "header = \"Accept: application/json\"",
        "header = \"" + quoteConfig(authenticationHeader) + "\"",
        "write-out = \"" + quoteConfig(STATUS_MARKER + "%{http_code}") + "\""
    ]

    if (body !== undefined && body !== null) {
        lines.push("header = \"Content-Type: application/json\"")
        lines.push("data = \"" + quoteConfig(JSON.stringify(body)) + "\"")
    }

    return lines.join("\n") + "\n"
}

function parseResponse(output) {
    var markerIndex = output.lastIndexOf(STATUS_MARKER)
    if (markerIndex < 0)
        return { ok: false, error: "Response did not include an HTTP status" }

    var statusText = output.slice(markerIndex + STATUS_MARKER.length).trim()
    if (!/^\d{3}$/.test(statusText))
        return { ok: false, error: "Response included an invalid HTTP status" }

    var bodyText = output.slice(0, markerIndex).trim()
    var body = null
    if (bodyText.length > 0) {
        try {
            body = JSON.parse(bodyText)
        } catch (exception) {
            return {
                ok: false,
                status: Number(statusText),
                error: "Server returned malformed JSON"
            }
        }
    }

    var status = Number(statusText)
    return {
        ok: status >= 200 && status < 300,
        status: status,
        body: body
    }
}

function parseResponses(output, expectedCount) {
    var responses = []
    var offset = 0
    while (responses.length < expectedCount) {
        var markerIndex = output.indexOf(STATUS_MARKER, offset)
        if (markerIndex < 0)
            return { ok: false, error: "Response did not include every HTTP status" }
        var statusEnd = markerIndex + STATUS_MARKER.length + 3
        responses.push(parseResponse(output.slice(offset, statusEnd)))
        offset = statusEnd
    }
    if (output.slice(offset).trim().length > 0)
        return { ok: false, error: "Response included unexpected trailing data" }
    return { ok: true, responses: responses }
}

function errorMessage(response, fallback) {
    if (response && response.body && typeof response.body.error === "string")
        return response.body.error
    if (response && response.body && typeof response.body.message === "string")
        return response.body.message
    return fallback
}

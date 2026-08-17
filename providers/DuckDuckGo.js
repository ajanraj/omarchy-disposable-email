.import "Http.js" as Http

var API_URL = "https://quack.duckduckgo.com/api/email/addresses"

function localPart(address) {
    var value = String(address).trim().toLowerCase()
    if (value.slice(-9) === "@duck.com")
        value = value.slice(0, -9)
    if (!/^[a-z0-9._-]+$/.test(value))
        return ""
    return value
}

function request(operation, token, address, active) {
    if (!Http.isSafeCredential(token))
        return { ok: false, error: "DuckDuckGo token is missing or invalid" }

    var method = "POST"
    var url = API_URL
    var part = ""
    if (operation !== "generate") {
        part = localPart(address)
        if (part.length === 0)
            return { ok: false, error: "Duck address is invalid" }
        url += "?address=" + encodeURIComponent(part)
        if (operation === "setActive")
            url += "&active=" + (active ? "true" : "false")
        method = operation === "status" ? "GET" : "PUT"
    }

    return {
        ok: true,
        localPart: part,
        config: Http.buildConfig(method, url, "Authorization: Bearer " + token)
    }
}

function parse(operation, output, requestedPart, requestedActive) {
    var response = Http.parseResponse(output)
    if (!response.ok) {
        response.error = response.error || Http.errorMessage(response, "DuckDuckGo request failed")
        return response
    }

    if (!response.body || typeof response.body !== "object")
        return { ok: false, status: response.status, error: "DuckDuckGo returned an invalid response" }

    if (operation === "generate") {
        var part = localPart(response.body.address)
        if (part.length === 0)
            return { ok: false, status: response.status, error: "DuckDuckGo returned an invalid address" }
        return { ok: true, status: response.status, value: { localPart: part, address: part + "@duck.com" } }
    }

    if (typeof response.body.active !== "boolean")
        return { ok: false, status: response.status, error: "DuckDuckGo returned an invalid alias status" }

    return {
        ok: true,
        status: response.status,
        value: {
            localPart: requestedPart,
            address: requestedPart + "@duck.com",
            active: response.body.active,
            requestedActive: operation === "setActive" ? requestedActive : undefined
        }
    }
}

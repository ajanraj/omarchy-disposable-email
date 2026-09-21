var NANO_ID_LENGTH = 14
var NANO_ID_PATTERN = new RegExp("^[A-Za-z0-9_-]{" + NANO_ID_LENGTH + ",}$")

function fromRandom(provider, rawRandom) {
    var randomText = String(rawRandom).trim()
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/, "")
    if (!NANO_ID_PATTERN.test(randomText))
        return { ok: false, error: "openssl returned invalid random data" }
    var nanoId = randomText.slice(0, NANO_ID_LENGTH)

    if (provider === "maildrop") {
        return {
            ok: true,
            value: {
                provider: provider,
                localPart: nanoId,
                address: nanoId + "@maildrop.cc",
                inboxUrl: "https://maildrop.cc/inbox/?mailbox=" + encodeURIComponent(nanoId)
            }
        }
    }

    if (provider === "harakiri") {
        return {
            ok: true,
            value: {
                provider: provider,
                localPart: nanoId,
                address: nanoId + "@harakirimail.com",
                inboxUrl: "https://harakirimail.com/inbox/" + encodeURIComponent(nanoId)
            }
        }
    }

    return { ok: false, error: "Unknown temporary address provider" }
}

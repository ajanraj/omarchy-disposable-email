function fromRandom(provider, rawRandom) {
    var randomText = String(rawRandom).trim()
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/, "")
    if (!/^[A-Za-z0-9_-]{14,}$/.test(randomText))
        return { ok: false, error: "openssl returned invalid random data" }
    var nanoId = randomText.slice(0, 14)

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

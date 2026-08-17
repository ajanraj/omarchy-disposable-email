function fromUuid(provider, rawUuid) {
    var uuid = String(rawUuid).trim().toLowerCase()
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(uuid))
        return { ok: false, error: "uuidgen returned an invalid UUID" }

    if (provider === "maildrop") {
        return {
            ok: true,
            value: {
                provider: provider,
                localPart: uuid,
                address: uuid + "@maildrop.cc",
                inboxUrl: "https://maildrop.cc/inbox/?mailbox=" + encodeURIComponent(uuid)
            }
        }
    }

    if (provider === "harakiri") {
        return {
            ok: true,
            value: {
                provider: provider,
                localPart: uuid,
                address: uuid + "@harakirimail.com",
                inboxUrl: "https://harakirimail.com/inbox/" + encodeURIComponent(uuid)
            }
        }
    }

    return { ok: false, error: "Unknown temporary address provider" }
}

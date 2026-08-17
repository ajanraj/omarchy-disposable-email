import QtQml
import Quickshell.Io
import "SimpleLogin.js" as SimpleLoginHelper

QtObject {
    id: root

    readonly property bool busy: curlProcess.running
    readonly property string operation: _operation
    readonly property int targetAliasId: _aliasId
    property string error: ""
    property string _operation: ""
    property string _config: ""
    property int _aliasId: 0
    property bool _pinned: false

    signal randomCreated(var alias)
    signal customOptionsLoaded(var options)
    signal customCreated(var alias)
    signal aliasesLoaded(var aliases)
    signal aliasPatched(var result)
    signal aliasToggled(var result)
    signal unauthorized()
    signal planLimit(string message)

    function createRandom(token) {
        return _start("random", SimpleLoginHelper.randomRequest(token))
    }

    function loadCustomOptions(token) {
        return _start("options", SimpleLoginHelper.customOptionsRequest(token))
    }

    function createCustom(token, prefix, suffix, mailboxIds, name, note) {
        return _start("custom", SimpleLoginHelper.customRequest(
            token, prefix, suffix, mailboxIds, name, note
        ))
    }

    function searchAliases(token, query, filter, page) {
        return _start("aliases", SimpleLoginHelper.aliasesRequest(token, query, filter, page))
    }

    function setPinned(token, aliasId, pinned) {
        return _start("pinned", SimpleLoginHelper.pinnedRequest(token, aliasId, pinned), aliasId, pinned)
    }

    function toggle(token, aliasId) {
        return _start("toggle", SimpleLoginHelper.toggleRequest(token, aliasId), aliasId, false)
    }

    function _start(operation, built, aliasId, pinned) {
        if (busy) {
            error = "A SimpleLogin request is already in progress"
            return false
        }
        if (!built.ok) {
            error = built.error
            return false
        }

        error = ""
        _operation = operation
        _aliasId = aliasId || 0
        _pinned = Boolean(pinned)
        _config = built.config
        curlProcess.stdinEnabled = true
        curlProcess.running = true
        return true
    }

    function _handleFailure(parsed) {
        error = parsed.error
        if (parsed.status === 401)
            unauthorized()
        else if (SimpleLoginHelper.isPlanLimit(parsed))
            planLimit(parsed.error)
    }

    function _finish(output, exitCode) {
        var operation = _operation
        _operation = ""
        if (exitCode !== 0) {
            error = "SimpleLogin request failed"
            return
        }

        var parsed
        if (operation === "random" || operation === "custom")
            parsed = SimpleLoginHelper.parseAlias(output)
        else if (operation === "options")
            parsed = SimpleLoginHelper.parseCustomOptions(output)
        else if (operation === "aliases")
            parsed = SimpleLoginHelper.parseAliases(output)
        else if (operation === "pinned")
            parsed = SimpleLoginHelper.parsePinned(output, _aliasId, _pinned)
        else
            parsed = SimpleLoginHelper.parseToggle(output, _aliasId)

        if (!parsed.ok) {
            _handleFailure(parsed)
            return
        }

        if (operation === "options") {
            if (!parsed.value.canCreate)
                planLimit("Your SimpleLogin plan cannot create another alias")
            customOptionsLoaded(parsed.value)
        } else if (operation === "random") {
            randomCreated(parsed.value)
        } else if (operation === "custom") {
            customCreated(parsed.value)
        } else if (operation === "aliases") {
            aliasesLoaded(parsed.value)
        } else if (operation === "pinned") {
            aliasPatched(parsed.value)
        } else {
            aliasToggled(parsed.value)
        }
    }

    property Process curlProcess: Process {
        command: ["/usr/bin/curl", "-q", "--config", "-"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onStarted: {
            var config = root._config
            root._config = ""
            try {
                write(config)
            } finally {
                config = ""
                stdinEnabled = false
            }
        }

        onRunningChanged: {
            if (!running && root._operation !== "") {
                root._config = ""
                root._operation = ""
                root.error = "Could not start curl"
            }
        }

        onExited: function(exitCode, exitStatus) {
            root._config = ""
            root._finish(stdout.text, exitCode)
        }
    }
}

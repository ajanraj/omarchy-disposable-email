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

    // Each operation pairs its response parser with the signal emitted on
    // success, so _finish runs one generic parse-then-emit step.
    readonly property var _operations: ({
        random: {
            parse: function(output) { return SimpleLoginHelper.parseAlias(output) },
            emit: function(value) { root.randomCreated(value) }
        },
        options: {
            parse: function(output) { return SimpleLoginHelper.parseCustomOptions(output) },
            emit: function(value) {
                if (!value.canCreate)
                    root.planLimit("Your SimpleLogin plan cannot create another alias")
                root.customOptionsLoaded(value)
            }
        },
        custom: {
            parse: function(output) { return SimpleLoginHelper.parseAlias(output) },
            emit: function(value) { root.customCreated(value) }
        },
        aliases: {
            parse: function(output) { return SimpleLoginHelper.parseAliases(output) },
            emit: function(value) { root.aliasesLoaded(value) }
        },
        pinned: {
            parse: function(output) {
                return SimpleLoginHelper.parsePinned(output, root._aliasId, root._pinned)
            },
            emit: function(value) { root.aliasPatched(value) }
        },
        toggle: {
            parse: function(output) { return SimpleLoginHelper.parseToggle(output, root._aliasId) },
            emit: function(value) { root.aliasToggled(value) }
        }
    })

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

        var handler = _operations[operation] || _operations.toggle
        var parsed = handler.parse(output)
        if (!parsed.ok) {
            _handleFailure(parsed)
            return
        }
        handler.emit(parsed.value)
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

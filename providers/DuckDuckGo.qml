import QtQml
import Quickshell.Io
import "DuckDuckGo.js" as DuckHelper

QtObject {
    id: root

    readonly property bool busy: curlProcess.running
    property string error: ""
    property string _operation: ""
    property string _config: ""
    property string _localPart: ""
    property bool _requestedActive: false

    signal generated(var result)
    signal statusFetched(var result)
    signal activeChanged(var result)
    signal unauthorized()

    function generate(token) {
        return _start("generate", token, "", false)
    }

    function fetchStatus(token, address) {
        return _start("status", token, address, false)
    }

    function setActive(token, address, active) {
        return _start("setActive", token, address, active)
    }

    function _start(operation, token, address, active) {
        if (busy) {
            error = "A DuckDuckGo request is already in progress"
            return false
        }

        var built = DuckHelper.request(operation, token, address, active)
        if (!built.ok) {
            error = built.error
            return false
        }

        error = ""
        _operation = operation
        _localPart = built.localPart
        _requestedActive = active
        _config = built.config
        curlProcess.stdinEnabled = true
        curlProcess.running = true
        return true
    }

    function _finish(output, exitCode) {
        var operation = _operation
        var localPart = _localPart
        var requestedActive = _requestedActive
        _operation = ""
        _localPart = ""

        if (exitCode !== 0) {
            error = "DuckDuckGo request failed"
            return
        }

        var parsed = DuckHelper.parse(operation, output, localPart, requestedActive)
        if (!parsed.ok) {
            error = parsed.error
            if (parsed.status === 401)
                unauthorized()
            return
        }

        if (operation === "generate")
            generated(parsed.value)
        else if (operation === "status")
            statusFetched(parsed.value)
        else
            activeChanged(parsed.value)
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

        onErrorOccurred: {
            root._config = ""
            if (root._operation !== "") root._finish("", -1)
        }
    }
}

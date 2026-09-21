import QtQml
import Quickshell.Io
import "../lib"
import "DuckDuckGo.js" as DuckHelper

QtObject {
    id: root

    readonly property bool busy: curlRunner.busy
    readonly property string operation: _operation
    readonly property string targetAddress: _localPart === "" ? "" : _localPart + "@duck.com"
    property string error: ""
    property string _operation: ""
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
        curlRunner.stdinData = built.config
        curlRunner.start()
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

    property ProcessRunner curlRunner: ProcessRunner {
        command: ["/usr/bin/curl", "-q", "--config", "-"]

        onFinished: function(stdoutText, stderrText, exitCode) {
            root._finish(stdoutText, exitCode)
        }

        onStartFailed: {
            root._operation = ""
            root.error = "Could not start curl"
        }
    }
}

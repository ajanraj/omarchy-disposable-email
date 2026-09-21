import QtQml
import Quickshell.Io

// Secret Service is the only credential store used by the plugin. Tokens are
// passed to secret-tool over stdin so they never appear in argv or logs.
QtObject {
    id: root

    readonly property string applicationAttribute: "io.github.ajanraj.disposable-email"
    readonly property bool busy: _operation !== "" || _runner.busy
    readonly property string operation: _operation
    property string _operation: ""
    property string _provider: ""
    property string _pendingToken: ""

    signal lookupSucceeded(string provider, string token)
    signal lookupFailed(string provider, string error)
    signal storeSucceeded(string provider, bool stored)
    signal storeFailed(string provider, string error)
    signal clearSucceeded(string provider, bool cleared)
    signal clearFailed(string provider, string error)
    signal operationRejected(string provider, string operation, string error)

    function _validProvider(provider) {
        return typeof provider === "string" && /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(provider)
    }

    function _failure(operation, provider, error) {
        if (operation === "lookup")
            lookupFailed(provider, error)
        else if (operation === "store")
            storeFailed(provider, error)
        else
            clearFailed(provider, error)
    }

    function _command(operation, provider) {
        var attributes = ["application", root.applicationAttribute, "provider", provider]
        if (operation === "lookup")
            return ["/usr/bin/secret-tool", "lookup"].concat(attributes)
        if (operation === "clear")
            return ["/usr/bin/secret-tool", "clear"].concat(attributes)
        return ["/usr/bin/secret-tool", "store", "--label", "Omarchy Disposable Email"].concat(attributes)
    }

    function _start(operation, provider) {
        if (root.busy) {
            operationRejected(provider, operation, "A credential operation is already in progress")
            return false
        }
        if (!_validProvider(provider)) {
            _failure(operation, provider, "Invalid credential provider")
            return false
        }

        root._operation = operation
        root._provider = provider
        root._runner.command = _command(operation, provider)
        root._runner.stdinData = operation === "store" ? root._pendingToken : ""
        root._pendingToken = ""
        root._runner.start()
        return true
    }

    function lookup(provider) {
        return _start("lookup", provider)
    }

    function store(provider, token) {
        if (typeof token !== "string" || token.length === 0) {
            storeFailed(provider, "Credential is empty")
            return false
        }
        if (!_validProvider(provider)) {
            storeFailed(provider, "Invalid credential provider")
            return false
        }
        if (root.busy) {
            operationRejected(provider, "store", "A credential operation is already in progress")
            return false
        }

        // Keep the token only until ProcessRunner writes it to stdin on launch.
        // It is cleared again on every completion/error path below.
        root._pendingToken = token
        return _start("store", provider)
    }

    function clear(provider) {
        return _start("clear", provider)
    }

    function _clearCurrent() {
        root._operation = ""
        root._provider = ""
        root._pendingToken = ""
    }

    function _stripFinalNewline(value) {
        var text = String(value || "")
        if (text.slice(-1) === "\n")
            text = text.slice(0, -1)
        if (text.slice(-1) === "\r")
            text = text.slice(0, -1)
        return text
    }

    function _finish(output, stderrText, exitCode) {
        if (root._operation === "")
            return

        var operation = root._operation
        var provider = root._provider
        var stderrClean = String(stderrText || "").trim()
        var error = stderrClean.length > 0 ? stderrClean : "Credential operation failed"

        if (exitCode !== 0) {
            // Clearing a missing item is already the desired end state.
            if (operation === "clear" && exitCode === 1 && stderrClean.length === 0) {
                clearSucceeded(provider, true)
                _clearCurrent()
                return
            }
            _failure(operation, provider, error)
            _clearCurrent()
            return
        }

        if (operation === "lookup") {
            var token = _stripFinalNewline(output)
            if (token.length === 0) {
                lookupFailed(provider, "Credential is not configured")
                _clearCurrent()
                return
            }
            // The token is emitted only to the in-memory consumer that asked
            // for it; it is never logged or written to a file by this module.
            lookupSucceeded(provider, token)
        } else if (operation === "store") {
            storeSucceeded(provider, true)
        } else {
            clearSucceeded(provider, true)
        }
        _clearCurrent()
    }

    property ProcessRunner _runner: ProcessRunner {
        onFinished: function(stdoutText, stderrText, exitCode) {
            root._finish(stdoutText, stderrText, exitCode)
        }
        onStartFailed: root._finish("", "", -1)
    }
}

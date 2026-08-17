import QtQml
import Quickshell.Io

// Secret Service is the only credential store used by the plugin. Tokens are
// passed to secret-tool over stdin so they never appear in argv or logs.
QtObject {
    id: root

    readonly property string applicationAttribute: "io.github.ajanraj.disposable-email"
    readonly property bool busy: _operation !== "" || _process.running
    readonly property string operation: _operation
    property string _operation: ""
    property string _provider: ""
    property string _pendingToken: ""
    property bool _handled: false

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
        root._handled = false
        root._process.command = _command(operation, provider)
        root._process.stdinEnabled = operation === "store"
        root._process.running = true
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

        // Keep the token only until Process.onStarted writes it to stdin. It
        // is cleared again on every completion/error path below.
        root._pendingToken = token
        return _start("store", provider)
    }

    function clear(provider) {
        return _start("clear", provider)
    }

    function _errorMessage(fallback) {
        var text = String(root._process.stderr.text || "").trim()
        return text.length > 0 ? text : fallback
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

    function _finish(exitCode) {
        if (root._handled || root._operation === "")
            return
        root._handled = true

        var operation = root._operation
        var provider = root._provider
        var output = root._process.stdout.text
        var stderrText = String(root._process.stderr.text || "").trim()
        var error = stderrText.length > 0 ? stderrText : "Credential operation failed"
        root._pendingToken = ""

        if (exitCode !== 0) {
            // Clearing a missing item is already the desired end state.
            if (operation === "clear" && exitCode === 1 && stderrText.length === 0) {
                clearSucceeded(provider)
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

    property Process _process: Process {
        command: []
        running: false
        stdinEnabled: true
        stdout: StdioCollector {
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }

        onStarted: {
            if (root._operation !== "store")
                return

            var token = root._pendingToken
            root._pendingToken = ""
            try {
                // Deliberately no newline: Secret Service receives the exact
                // token entered by the user and stdin is closed immediately.
                write(token)
            } finally {
                token = ""
                stdinEnabled = false
            }
        }

        onExited: function(exitCode, exitStatus) {
            root._pendingToken = ""
            root._finish(exitCode)
        }

        onRunningChanged: {
            if (running || root._operation === "" || root._handled)
                return

            // Process emits onExited for normal completion. Defer this check
            // one turn so a failed-to-start process still gets a result while
            // an ordinary exit is handled by onExited first.
            Qt.callLater(function() {
                if (!root._process.running && root._operation !== "" && !root._handled) {
                    root._pendingToken = ""
                    root._finish(-1)
                }
            })
        }
    }
}

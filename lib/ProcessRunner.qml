import QtQml
import Quickshell.Io

// Runs one external command at a time and delivers its result exactly once.
//
// Set `command` (an argv list, never a shell string) and optionally
// `stdinData`, which is written to the process's stdin exactly as given (no
// trailing newline) once it launches and is cleared on every outcome; stdin
// stays closed when stdinData is empty.
// `finished` reports a process that ran and exited; `startFailed` reports a
// process that never began running. A failed start is detected by a deferred
// re-check one turn after running flips false, so an ordinary exit is claimed
// by onExited first and callers see exactly one outcome per start().
QtObject {
    id: root

    property var command: []
    property string stdinData: ""

    // True from start() until finished or startFailed delivers the outcome.
    readonly property bool busy: _inFlight || _process.running

    property bool _inFlight: false
    property bool _handled: false

    signal finished(string stdoutText, string stderrText, int exitCode)
    signal startFailed()

    // Returns false when a command is already in flight.
    function start() {
        if (root.busy)
            return false
        root._inFlight = true
        root._handled = false
        root._process.command = root.command
        root._process.stdinEnabled = root.stdinData !== ""
        root._process.running = true
        return true
    }

    function _complete(exitCode) {
        if (!root._inFlight || root._handled)
            return
        root._handled = true
        root._inFlight = false
        var output = root._process.stdout.text
        var errors = root._process.stderr.text
        root.stdinData = ""
        root.finished(output, errors, exitCode)
    }

    function _failStart() {
        if (!root._inFlight || root._handled)
            return
        root._handled = true
        root._inFlight = false
        root.stdinData = ""
        root.startFailed()
    }

    property Process _process: Process {
        running: false

        stdout: StdioCollector {
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }

        onStarted: {
            var data = root.stdinData
            root.stdinData = ""
            if (data === "")
                return
            try {
                write(data)
            } finally {
                data = ""
                stdinEnabled = false
            }
        }

        onExited: function(exitCode, exitStatus) {
            root._complete(exitCode)
        }

        onRunningChanged: {
            if (running || !root._inFlight || root._handled)
                return
            // Process emits onExited for normal completion. Defer this check
            // one turn so a failed-to-start process still gets a result while
            // an ordinary exit is handled by onExited first.
            Qt.callLater(function() {
                if (!root._process.running)
                    root._failStart()
            })
        }
    }
}

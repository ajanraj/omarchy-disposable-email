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
// by onExited first; the re-check is bound to that run by a generation marker
// and skipped once onStarted fired, so callers see exactly one correct
// outcome per start() regardless of signal ordering.
QtObject {
    id: root

    property var command: []
    property string stdinData: ""

    // True from start() until finished or startFailed delivers the outcome.
    readonly property bool busy: _inFlight || _process.running

    property bool _inFlight: false
    property bool _handled: false
    property bool _started: false
    property int _generation: 0

    signal finished(string stdoutText, string stderrText, int exitCode)
    signal startFailed()

    // Returns false when a command is already in flight or unset.
    function start() {
        if (root.busy || !root.command || root.command.length === 0)
            return false
        root._generation += 1
        root._inFlight = true
        root._handled = false
        root._started = false
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
            root._started = true
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
            // an ordinary exit is handled by onExited first. The generation
            // and started markers bind the re-check to this run: a stale
            // callback cannot act on a later start(), and a process that did
            // launch is never misreported as a start failure.
            var generation = root._generation
            Qt.callLater(function() {
                if (generation === root._generation && !root._started
                        && !root._process.running)
                    root._failStart()
            })
        }
    }
}

import QtQml
import Quickshell
import Quickshell.Io
import "StateModel.js" as StateModel

// Persistent UI state only. Credentials are deliberately owned by
// CredentialStore and never pass through this object or its JSON file.
QtObject {
    id: root

    readonly property string _home: Quickshell.env("HOME")
    readonly property string _xdgStateHome: Quickshell.env("XDG_STATE_HOME")
    readonly property string stateHome: _xdgStateHome.length > 0
        ? _xdgStateHome
        : _home + "/.local/state"
    readonly property string stateDir: stateHome + "/io.github.ajanraj.disposable-email"
    readonly property string statePath: stateDir + "/state.json"

    property var state: StateModel.defaults()
    property bool ready: false
    property bool _directoryReady: false
    property bool _loadedOnce: false
    property bool _writeInFlight: false
    property var _pendingState: null
    property var _writingState: null

    signal loaded(var value)
    signal loadFailed(string error)
    signal saved(var value)
    signal saveFailed(string error)
    signal reset(var value)

    function _decode(raw) {
        var text = String(raw || "")
        if (text.trim().length === 0)
            return { value: StateModel.defaults(), valid: true }

        try {
            var parsed = JSON.parse(text)
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)
                    || (parsed.version !== 1 && parsed.version !== StateModel.VERSION))
                return { value: StateModel.defaults(), valid: false }
            return {
                value: StateModel.parse(parsed),
                valid: true,
                migrated: parsed.version !== StateModel.VERSION
            }
        } catch (error) {
            return { value: StateModel.defaults(), valid: false }
        }
    }

    function _publishLoaded(raw) {
        if (root._loadedOnce)
            return
        root._loadedOnce = true
        var decoded = _decode(raw)
        root.state = decoded.value
        root.ready = true
        if (!decoded.valid)
            loadFailed("State file is malformed; using defaults")
        loaded(root.state)
        if (decoded.migrated)
            Qt.callLater(function() { root.save(root.state) })
    }

    function _loadFailed(error) {
        // A missing state file is the normal first-run path. Keep the
        // default state and let a later save create it after mkdir completes.
        _publishLoaded("")
    }

    function load() {
        stateFile.reload()
    }

    function _flushPending() {
        if (!root._directoryReady || root._writeInFlight || root._pendingState === null)
            return

        var next = root._pendingState
        root._pendingState = null
        root._writingState = next
        root._writeInFlight = true
        stateFile.setText(StateModel.serialize(next) + "\n")
    }

    function save(next) {
        var normalized = StateModel.normalize(next === undefined ? root.state : next)
        root.state = normalized
        root._pendingState = normalized
        _flushPending()
        return true
    }

    function resetState() {
        var next = StateModel.reset()
        root.state = next
        root._pendingState = next
        reset(next)
        _flushPending()
        return next
    }

    property FileView stateFile: FileView {
        path: root.statePath
        watchChanges: false
        atomicWrites: true
        printErrors: false

        onLoaded: root._publishLoaded(text())
        onLoadFailed: function(error) { root._loadFailed(error) }
        onSaved: {
            var value = root._writingState
            root._writingState = null
            root._writeInFlight = false
            root.saved(value)
            root._flushPending()
        }
        onSaveFailed: function(error) {
            var value = root._writingState
            root._writingState = null
            root._writeInFlight = false
            if (value !== null)
                root._pendingState = value
            root.saveFailed("Could not save state")
        }
    }

    // mkdir receives the path as an argv element, never through a shell.
    property Process ensureDirectory: Process {
        command: ["/usr/bin/mkdir", "-p", root.stateDir]
        running: false

        onExited: function(exitCode, exitStatus) {
            root._directoryReady = exitCode === 0
            if (!root._directoryReady) {
                root.saveFailed("Could not create state directory")
                return
            }
            root._flushPending()
            if (!root._loadedOnce)
                root.load()
        }
    }

    Component.onCompleted: {
        ensureDirectory.running = true
        // FileView may try its initial read before mkdir has completed. The
        // missing-file path is harmless; reload after mkdir gives first-run
        // setups a deterministic load event.
        Qt.callLater(root.load)
    }
}

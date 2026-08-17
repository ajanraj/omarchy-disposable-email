import QtQml
import Quickshell.Io
import "TemporaryAddress.js" as TemporaryAddressHelper

QtObject {
    id: root

    readonly property bool busy: uuidProcess.running
    property string error: ""
    property string _provider: ""

    signal created(var result)

    function create(provider) {
        if (busy) {
            error = "A temporary address is already being created"
            return false
        }
        if (provider !== "maildrop" && provider !== "harakiri") {
            error = "Unknown temporary address provider"
            return false
        }

        error = ""
        _provider = provider
        uuidProcess.running = true
        return true
    }

    property Process uuidProcess: Process {
        command: ["/usr/bin/uuidgen"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onRunningChanged: {
            if (!running && root._provider !== "") {
                root.error = "Could not start uuidgen"
                root._provider = ""
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.error = "Could not create a UUID"
                root._provider = ""
                return
            }

            var parsed = TemporaryAddressHelper.fromUuid(root._provider, stdout.text)
            root._provider = ""
            if (!parsed.ok) {
                root.error = parsed.error
                return
            }
            root.created(parsed.value)
        }
    }
}

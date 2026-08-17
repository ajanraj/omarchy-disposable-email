import QtQml
import Quickshell.Io
import "TemporaryAddress.js" as TemporaryAddressHelper

QtObject {
    id: root

    readonly property bool busy: randomProcess.running
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
        randomProcess.running = true
        return true
    }

    property Process randomProcess: Process {
        command: ["/usr/bin/openssl", "rand", "-base64", "12"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onRunningChanged: {
            if (!running && root._provider !== "") {
                root.error = "Could not start openssl"
                root._provider = ""
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.error = "Could not create a short address ID"
                root._provider = ""
                return
            }

            var parsed = TemporaryAddressHelper.fromRandom(root._provider, stdout.text)
            root._provider = ""
            if (!parsed.ok) {
                root.error = parsed.error
                return
            }
            root.created(parsed.value)
        }
    }
}

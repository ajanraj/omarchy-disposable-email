import QtQml
import Quickshell.Io
import "../lib"
import "TemporaryAddress.js" as TemporaryAddressHelper

QtObject {
    id: root

    readonly property bool busy: randomRunner.busy
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
        randomRunner.start()
        return true
    }

    property ProcessRunner randomRunner: ProcessRunner {
        command: ["/usr/bin/openssl", "rand", "-base64", "12"]

        onFinished: function(stdoutText, stderrText, exitCode) {
            if (exitCode !== 0) {
                root.error = "Could not create a short address ID"
                root._provider = ""
                return
            }

            var parsed = TemporaryAddressHelper.fromRandom(root._provider, stdoutText)
            root._provider = ""
            if (!parsed.ok) {
                root.error = parsed.error
                return
            }
            root.created(parsed.value)
        }

        onStartFailed: {
            root.error = "Could not start openssl"
            root._provider = ""
        }
    }
}

import QtQuick
import QtQuick.Layouts
import qs.Commons

// Base for the credential-backed provider views (DuckDuckGo, SimpleLogin).
// The service only assigns credential states "loading", "connected",
// "disconnected", and "attention"; canAct is the single enablement guard
// ("connected and no action running") that action buttons bind to.
ColumnLayout {
  required property var service
  required property var requestConfirmation

  property string credentialState: ""

  width: parent ? parent.width : implicitWidth
  height: parent ? parent.height : implicitHeight
  spacing: Style.space(12)

  readonly property bool connected: credentialState === "connected"
  readonly property bool configured: connected || credentialState === "attention"
  readonly property bool canAct: connected && !service.actionBusy
}

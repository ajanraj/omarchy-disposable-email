import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var service
  required property var requestConfirmation
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  PanelSectionHeader { text: "PLUGIN SETTINGS" }

  Text {
    width: parent.width
    text: "Reset removes saved credentials, temporary address history, remembered Duck aliases, and local preferences. It never changes remote aliases or inboxes."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Button {
    text: "Reset Plugin Data"
    iconText: "󰆴"
    focusable: true
    enabled: !root.service.actionBusy
    foreground: Color.urgent
    onClicked: root.requestConfirmation("Reset all Disposable Email plugin data? This cannot be undone.", function() { root.service.resetPluginData() }, "Reset")
  }
}

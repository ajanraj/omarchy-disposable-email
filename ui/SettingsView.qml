import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var service
  required property var requestConfirmation
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  function configured(state) {
    var value = String(state || "")
    return value === "connected" || value === "available" || value === "ready" || value === "attention"
  }

  PanelSectionHeader { text: "CONNECTIONS" }

  Text {
    width: parent.width
    text: "Disconnecting removes the provider credential and keeps unrelated plugin data intact."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  StatusBanner {
    text: root.service && root.service.duckCredentialState === "attention"
      ? String(root.service.duckError || "DuckDuckGo credential needs attention") : ""
    error: true
  }

  StatusBanner {
    text: root.service && root.service.simpleCredentialState === "attention"
      ? String(root.service.simpleError || "SimpleLogin credential needs attention") : ""
    error: true
  }

  Button {
    width: parent.width
    visible: root.configured(root.service.duckCredentialState)
    enabled: !root.service.actionBusy
    text: "Disconnect DuckDuckGo"
    iconText: "󰌙"
    focusable: true
    leftAlign: true
    foreground: Color.urgent
    onClicked: root.requestConfirmation("Disconnect DuckDuckGo and remove its saved token?", function() { root.service.disconnectProvider("duckduckgo") }, "Disconnect")
  }

  Button {
    width: parent.width
    visible: root.configured(root.service.simpleCredentialState)
    enabled: !root.service.actionBusy
    text: "Disconnect SimpleLogin"
    iconText: "󰌙"
    focusable: true
    leftAlign: true
    foreground: Color.urgent
    onClicked: root.requestConfirmation("Disconnect SimpleLogin and remove its saved API key?", function() { root.service.disconnectProvider("simplelogin") }, "Disconnect")
  }

  Text {
    visible: !root.configured(root.service.duckCredentialState) && !root.configured(root.service.simpleCredentialState)
    width: parent.width
    text: "No providers are connected."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    horizontalAlignment: Text.AlignHCenter
  }

  PanelSeparator {}
  PanelSectionHeader { text: "PLUGIN DATA" }

  Text {
    width: parent.width
    text: "Reset removes credentials, remembered aliases, the temporary address, and local preferences."
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

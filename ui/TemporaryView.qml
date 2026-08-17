import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var service
  required property var requestConfirmation
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  readonly property var history: service ? service.temporaryAddresses : []

  function providerName(provider) {
    return provider === "harakiri" ? "Harakiri" : "Maildrop"
  }

  PanelSectionHeader { text: "TEMPORARY ADDRESS" }

  StatusBanner {
    reserveSpace: true
    text: root.service && root.service.temporaryError
      ? String(root.service.temporaryError)
      : "Public inboxes. Do not use them for sensitive email."
    error: root.service && root.service.temporaryError !== ""
    warning: !error
  }

  Row {
    width: parent.width
    spacing: Style.space(6)
    Dropdown {
      width: parent.width - createButton.width - parent.spacing
      showLabel: false
      value: root.service ? String(root.service.temporaryProvider || "maildrop") : "maildrop"
      options: [
        { value: "maildrop", label: "Maildrop" },
        { value: "harakiri", label: "Harakiri" }
      ]
      onChanged: function(value) { root.service.setTemporaryProvider(value) }
    }
    Button {
      id: createButton
      width: Style.space(116)
      text: root.service.temporaryBusy ? "Creating..." : "Create"
      iconText: root.service.temporaryBusy ? "󰦖" : "+"
      iconSpinning: root.service.temporaryBusy
      focusable: true
      enabled: !root.service.temporaryBusy
      onClicked: root.service.createTemporary()
    }
  }

  PanelSeparator {}
  PanelSectionHeader { text: "HISTORY" }

  Text {
    visible: !root.history || root.history.length === 0
    width: parent.width
    text: "Create an address to start your history."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    horizontalAlignment: Text.AlignHCenter
  }

  Repeater {
    model: root.history || []
    delegate: AddressHistoryCard {
      required property var modelData
      providerLabel: root.providerName(String(modelData.provider || ""))
      address: String(modelData.address || "")
      showOpen: true
      onCopyRequested: root.service.copyText(address)
      onOpenRequested: root.service.openUrl(String(modelData.inboxUrl || ""))
      onForgetRequested: root.requestConfirmation(
        "Forget " + address + "? The public inbox may continue to exist.",
        function() { root.service.forgetTemporary(address) },
        "Forget")
    }
  }
}

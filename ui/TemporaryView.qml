import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var service
  required property var requestConfirmation
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  readonly property var current: service ? service.temporaryAddress : null
  readonly property string address: current && current.address ? String(current.address) : ""
  readonly property string inboxUrl: current
    ? String(current.inboxUrl || current.url || "")
    : ""

  PanelSectionHeader { text: "TEMPORARY ADDRESS" }

  StatusBanner {
    text: root.service && root.service.temporaryError ? String(root.service.temporaryError) : ""
    error: true
  }

  Row {
    visible: root.service && root.service.temporaryBusy
    spacing: Style.space(8)
    Text { text: "󰦖"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.icon
      RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: parent.visible }
    }
    Text { text: "Working..."; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
  }

  Text {
    width: parent.width
    text: "Provider-hosted public inbox. Anyone who knows the address may be able to read its messages."
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Dropdown {
    width: parent.width
    label: "Provider"
    value: root.service ? String(root.service.temporaryProvider || "maildrop") : "maildrop"
    options: [
      { value: "maildrop", label: "Maildrop" },
      { value: "harakiri", label: "Harakiri" }
    ]
    onChanged: function(value) { root.service.setTemporaryProvider(value) }
  }

  Column {
    visible: root.address !== ""
    width: parent.width
    spacing: Style.space(8)

    Text {
      width: parent.width
      text: root.address
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
      elide: Text.ElideMiddle
    }

    Row {
      spacing: Style.space(6)
      Button {
        text: "Copy"
        iconText: ""
        focusable: true
        onClicked: root.service.copyText(root.address)
      }
      Button {
        text: "Open Inbox"
        iconText: ""
        focusable: true
        enabled: root.inboxUrl !== ""
        onClicked: root.service.openUrl(root.inboxUrl)
      }
    }
  }

  Text {
    visible: root.address === ""
    width: parent.width
    text: "No temporary address yet."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    horizontalAlignment: Text.AlignHCenter
  }

  Row {
    spacing: Style.space(6)
    Button {
      text: root.address === "" ? "Create Address" : "Replace Address"
      iconText: root.address === "" ? "+" : "󰑓"
      focusable: true
      enabled: !root.service.temporaryBusy
      onClicked: {
        if (root.address === "") root.service.createTemporary()
        else root.requestConfirmation(
          "Replace the current temporary address? The previous address will be forgotten by this plugin.",
          function() { root.service.replaceTemporary() },
          "Replace")
      }
    }
    Button {
      visible: root.address !== ""
      text: "Forget"
      iconText: "󰆴"
      focusable: true
      foreground: Color.urgent
      onClicked: root.requestConfirmation(
        "Forget this temporary address? The provider-hosted inbox may continue to exist.",
        function() { root.service.forgetTemporary() },
        "Forget")
    }
  }
}

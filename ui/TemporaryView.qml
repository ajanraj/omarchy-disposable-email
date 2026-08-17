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
      text: "Create"
      iconText: "+"
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
    delegate: Rectangle {
      required property var modelData
      width: root.width
      implicitHeight: historyRow.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Util.alpha(Color.foreground, 0.05)
      readonly property string address: String(modelData.address || "")
      readonly property string inboxUrl: String(modelData.inboxUrl || "")
      readonly property string providerLabel: root.providerName(String(modelData.provider || ""))

      Column {
        id: historyRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        Rectangle {
          implicitWidth: providerText.implicitWidth + Style.space(12)
          implicitHeight: providerText.implicitHeight + Style.space(5)
          radius: implicitHeight / 2
          color: Util.alpha(Color.accent, 0.14)
          Text {
            id: providerText
            anchors.centerIn: parent
            text: providerLabel
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Text {
          width: parent.width
          text: address
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideMiddle
        }

        Row {
          spacing: Style.space(4)
          Button { text: "Copy"; iconText: ""; focusable: true; onClicked: root.service.copyText(address) }
          Button { text: "Open"; iconText: ""; focusable: true; enabled: inboxUrl !== ""; onClicked: root.service.openUrl(inboxUrl) }
          Button {
            text: "Forget"
            focusable: true
            foreground: Color.urgent
            onClicked: root.requestConfirmation(
              "Forget " + address + "? The public inbox may continue to exist.",
              function() { root.service.forgetTemporary(address) },
              "Forget")
          }
        }
      }
    }
  }
}

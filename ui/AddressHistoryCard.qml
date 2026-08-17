import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  required property string providerLabel
  required property string address
  property string statusText: ""
  property color statusColor: Color.muted
  property string detailText: ""
  property bool showOpen: false
  property bool showForget: true
  property var actions: []

  signal copyRequested()
  signal openRequested()
  signal forgetRequested()
  signal actionRequested(string actionId)

  width: parent ? parent.width : implicitWidth
  implicitHeight: content.implicitHeight + Style.space(16)
  radius: Style.cornerRadius
  color: Util.alpha(Color.foreground, 0.05)

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Style.space(8)
    spacing: Style.space(6)

    Row {
      width: parent.width

      Rectangle {
        id: badge
        implicitWidth: providerText.implicitWidth + Style.space(12)
        implicitHeight: providerText.implicitHeight + Style.space(5)
        radius: implicitHeight / 2
        color: Util.alpha(Color.accent, 0.14)

        Text {
          id: providerText
          anchors.centerIn: parent
          text: root.providerLabel
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item { width: Math.max(0, parent.width - badge.width - status.implicitWidth); height: 1 }

      Text {
        id: status
        visible: root.statusText !== ""
        text: root.statusText
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      width: parent.width
      text: root.address
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideMiddle
    }

    Text {
      visible: root.detailText !== ""
      width: parent.width
      text: root.detailText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Row {
      spacing: Style.space(4)

      Button {
        width: Style.space(78)
        text: "Copy"
        iconText: ""
        focusable: true
        onClicked: root.copyRequested()
      }

      Button {
        visible: root.showOpen
        width: Style.space(78)
        text: "Open"
        iconText: ""
        focusable: true
        onClicked: root.openRequested()
      }

      Repeater {
        model: root.actions || []
        delegate: Button {
          required property var modelData
          text: String(modelData.text || "")
          width: Number(modelData.width || 0) > 0 ? Number(modelData.width) : implicitWidth
          iconText: String(modelData.icon || "")
          iconSpinning: modelData.busy === true
          focusable: true
          enabled: modelData.enabled !== false
          foreground: modelData.destructive === true ? Color.urgent : Color.foreground
          onClicked: root.actionRequested(String(modelData.id || ""))
        }
      }

      Button {
        visible: root.showForget
        width: Style.space(82)
        text: "Forget"
        focusable: true
        foreground: Color.urgent
        onClicked: root.forgetRequested()
      }
    }
  }
}

import QtQuick
import qs.Commons

Rectangle {
  id: root
  property string text: ""
  property bool error: false
  property bool warning: false
  property color foreground: Color.foreground

  visible: text !== ""
  width: parent ? parent.width : implicitWidth
  implicitHeight: message.implicitHeight + Style.space(16)
  radius: Style.cornerRadius
  color: error ? Util.alpha(Color.urgent, 0.16)
    : warning ? Util.alpha(Color.accent, 0.12)
    : Util.alpha(foreground, 0.07)

  Text {
    id: message
    anchors.fill: parent
    anchors.margins: Style.space(8)
    text: root.text
    color: root.error ? Color.urgent : root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }
}

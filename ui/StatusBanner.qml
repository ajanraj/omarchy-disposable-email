import QtQuick
import qs.Commons

import qs.Commons as Commons
Rectangle {
  id: root
  property string text: ""
  property bool error: false
  property bool warning: false
  property bool reserveSpace: false
  property color foreground: Commons.Color.foreground

  visible: reserveSpace || text !== ""
  width: parent ? parent.width : implicitWidth
  implicitHeight: reserveSpace ? Style.space(38) : message.implicitHeight + Style.space(16)
  radius: Style.cornerRadius
  color: error ? Util.alpha(Commons.Color.urgent, 0.16)
    : warning ? Util.alpha(Commons.Color.accent, 0.12)
    : Util.alpha(foreground, 0.07)

  Text {
    id: message
    anchors.fill: parent
    anchors.margins: Style.space(8)
    text: root.text
    color: root.error ? Commons.Color.urgent : root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    verticalAlignment: Text.AlignVCenter
    wrapMode: root.reserveSpace ? Text.NoWrap : Text.WordWrap
    elide: root.reserveSpace ? Text.ElideRight : Text.ElideNone
  }
}

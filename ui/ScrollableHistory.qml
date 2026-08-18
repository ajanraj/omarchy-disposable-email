import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root

  property string title: "HISTORY"
  property string emptyText: ""
  property var model: []
  property Component delegateComponent: null
  property real maximumImplicitHeight: Style.space(280)

  spacing: Style.space(8)

  implicitWidth: Math.max(titleHeader.implicitWidth, emptyMessage.implicitWidth)
  implicitHeight: titleHeader.implicitHeight + separator.implicitHeight + spacing * 2
    + (emptyState.visible
      ? emptyState.implicitHeight
      : Math.min(historyList.contentHeight, maximumImplicitHeight))

  PanelSeparator {
    id: separator
    Layout.fillWidth: true
  }

  PanelSectionHeader {
    id: titleHeader
    Layout.fillWidth: true
    text: root.title
  }

  Item {
    id: emptyState
    visible: !root.model || root.model.length === 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: implicitHeight
    implicitHeight: emptyMessage.implicitHeight

    Text {
      id: emptyMessage
      anchors.centerIn: parent
      width: parent.width
      text: root.emptyText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }

  ListView {
    id: historyList
    visible: !emptyState.visible
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 0
    implicitHeight: Math.min(contentHeight, root.maximumImplicitHeight)
    model: root.model || []
    delegate: root.delegateComponent
    spacing: Style.space(8)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    QQC.ScrollBar.vertical: QQC.ScrollBar {
      policy: QQC.ScrollBar.AsNeeded
    }
  }
}

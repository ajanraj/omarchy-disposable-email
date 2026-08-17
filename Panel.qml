import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "ui"

Panel {
  id: root
  moduleName: "io.github.ajanraj.disposable-email"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  property int activeTab: tabIndex(service ? service.lastTab : "temporary")
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function tabIndex(tab) {
    if (tab === "duck" || tab === "duckduckgo") return 1
    if (tab === "simple" || tab === "simplelogin") return 2
    return 0
  }

  function selectTab(index) {
    activeTab = Math.max(0, Math.min(2, index))
    if (!service) return
    var tabs = ["temporary", "duckduckgo", "simplelogin"]
    service.setLastTab(tabs[activeTab])
    if (opened) Qt.callLater(refreshActiveTab)
  }

  function refreshActiveTab() {
    if (!service || activeTab !== 2 || service.simpleCredentialState !== "connected") return
    var view = viewLoader.item
    if (view && typeof view.refresh === "function") view.refresh()
  }

  function open() {
    controller.show()
    Qt.callLater(refreshActiveTab)
  }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  onServiceChanged: if (service) activeTab = tabIndex(service.lastTab)

  Connections {
    target: root.service
    function onLastTabChanged() { root.activeTab = root.tabIndex(root.service.lastTab) }
    function onSimpleCredentialStateChanged() {
      if (root.opened && root.activeTab === 2) root.refreshActiveTab()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keySurface
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.cappedContentHeight(Style.space(680))

    Item {
      id: keySurface
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (confirmDialog.opened && confirmDialog.handleKey(event)) {
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Escape) {
          root.close()
          event.accepted = true
        }
      }

      Column {
        id: shell
        anchors.fill: parent
        spacing: Style.space(12)

        Row {
          id: tabs
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: [
              { label: "Temporary", icon: "󰇮" },
              { label: "DuckDuckGo", icon: "󰇰" },
              { label: "SimpleLogin", icon: "󰛳" }
            ]

            Button {
              required property var modelData
              required property int index
              width: (tabs.width - tabs.spacing * 2) / 3
              text: modelData.label
              iconText: modelData.icon
              selected: root.activeTab === index
              focusable: true
              horizontalPadding: Style.space(5)
              fontSize: Style.font.caption
              onClicked: root.selectTab(index)
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Item {
          width: parent.width
          height: shell.height - tabs.height - shell.spacing - Style.space(13)

          Text {
            anchors.centerIn: parent
            visible: !root.service
            width: parent.width
            text: "Disposable Email service is not available."
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Flickable {
            id: scroll
            anchors.fill: parent
            visible: !!root.service
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

            Column {
              id: contentColumn
              width: scroll.width
              spacing: Style.space(16)

              Loader {
                id: viewLoader
                width: parent.width
                sourceComponent: root.activeTab === 0 ? temporaryView
                  : root.activeTab === 1 ? duckView
                  : simpleView
              }

              PanelSeparator { foreground: root.foreground }
              SettingsView {
                width: parent.width
                service: root.service
                requestConfirmation: root.confirm
              }
            }
          }
        }
      }

      Component { id: temporaryView; TemporaryView { service: root.service; requestConfirmation: root.confirm } }
      Component { id: duckView; DuckView { service: root.service; requestConfirmation: root.confirm } }
      Component { id: simpleView; SimpleLoginView { service: root.service; requestConfirmation: root.confirm } }
      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        foreground: root.foreground
        background: Color.popups.background
        onCanceled: {
          opened = false
          root.pendingAction = null
        }
        onConfirmed: {
          opened = false
          var action = root.pendingAction
          root.pendingAction = null
          if (action) action()
        }
      }
    }
  }

  property var pendingAction: null
  function confirm(message, action, confirmText) {
    pendingAction = action
    confirmDialog.message = message
    confirmDialog.confirmText = confirmText || "Confirm"
    confirmDialog.selectedIndex = 0
    confirmDialog.opened = true
  }
}

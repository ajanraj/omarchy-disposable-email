import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var service
  required property var requestConfirmation
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  property bool customVisible: false
  property int page: 0
  property var selectedMailboxIds: []
  property bool controlsReady: false
  readonly property string credentialState: service ? String(service.simpleCredentialState || "") : ""
  readonly property bool connected: credentialState === "connected" || credentialState === "available" || credentialState === "ready"
  readonly property bool configured: connected || credentialState === "attention"

  Component.onCompleted: controlsReady = true

  function mailboxOptions() {
    var source = service.simpleMailboxes || []
    var out = []
    for (var i = 0; i < source.length; i++) {
      var item = source[i]
      out.push({
        value: String(item.id),
        label: String(item.email),
        description: ""
      })
    }
    return out
  }

  function mailboxText(value) {
    if (!value) return "Unknown mailbox"
    var labels = []
    for (var i = 0; i < value.length; i++)
      labels.push(String(value[i].email))
    return labels.join(", ")
  }

  function counterText(alias) {
    return String(alias.counters || "")
  }

  function refresh() {
    service.refreshSimpleLogin(searchField.text, filterDropdown.value, page)
  }

  PanelSectionHeader { text: "SIMPLELOGIN" }

  StatusBanner {
    text: root.service && root.service.simpleError ? String(root.service.simpleError) : ""
    error: true
  }

  StatusBanner {
    visible: root.configured && root.service.simpleStale
    text: "Showing cached aliases. Last successful refresh: " + String(root.service.simpleLastRefresh || "unknown")
    warning: true
  }

  Row {
    visible: root.service && root.service.simpleBusy
    spacing: Style.space(8)
    Text { text: "󰦖"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.icon
      RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: parent.visible }
    }
    Text { text: "Working..."; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
  }

  Column {
    visible: !root.connected
    width: parent.width
    spacing: Style.space(8)

    Text {
      width: parent.width
      text: "Open setup, create an API key, then paste it below. The key is handed directly to the service and cleared from this form."
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
    Button {
      text: "Open Setup"
      iconText: ""
      focusable: true
      onClicked: root.service.openUrl("https://app.simplelogin.io/dashboard/api_key")
    }
    TextField {
      id: apiKeyField
      width: parent.width
      placeholderText: "API key"
      password: true
      onAccepted: connect()
      function connect() {
        var value = text
        if (!value) return
        root.service.connectProvider("simplelogin", value)
        clear()
      }
    }
    Button {
      text: "Connect SimpleLogin"
      iconText: "󰌘"
      focusable: true
      enabled: apiKeyField.text.length > 0 && !root.service.actionBusy
      onClicked: apiKeyField.connect()
    }
  }

  Column {
    visible: root.configured
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(6)
      Button {
        text: "Random Alias"
        iconText: "+"
        focusable: true
        enabled: root.connected && root.service.simpleCanCreate && !root.service.simpleBusy
        onClicked: root.service.createSimpleRandom()
      }
      Button {
        text: root.customVisible ? "Cancel Custom" : "Custom Alias"
        iconText: "󰅖"
        focusable: true
        enabled: root.connected && root.service.simpleCanCreate && !root.service.simpleBusy
        onClicked: {
          root.customVisible = !root.customVisible
          if (root.customVisible) root.service.prepareSimpleCustom()
        }
      }
    }

    Column {
      visible: root.customVisible
      width: parent.width
      spacing: Style.space(8)

      Row {
        width: parent.width
        spacing: Style.space(6)
        TextField { id: prefixField; width: parent.width * 0.42; placeholderText: "Prefix" }
        Dropdown {
          id: suffixDropdown
          width: parent.width - prefixField.width - parent.spacing
          showLabel: false
          value: options.length > 0 ? String(options[0].value) : ""
          options: root.service.simpleAliasOptions ? root.service.simpleAliasOptions.suffixes : []
        }
      }
      MultiSelect {
        id: mailboxSelect
        width: parent.width
        label: "Forward to"
        values: root.selectedMailboxIds
        options: root.mailboxOptions()
        onChanged: function(values) { root.selectedMailboxIds = values }
      }
      TextField { id: nameField; width: parent.width; placeholderText: "Name (optional)" }
      TextField { id: noteField; width: parent.width; placeholderText: "Note (optional)" }
      Button {
        text: "Create Custom Alias"
        iconText: "+"
        focusable: true
        enabled: root.connected && prefixField.text.trim().length > 0 && suffixDropdown.value !== "" && root.selectedMailboxIds.length > 0 && !root.service.simpleBusy
        onClicked: {
          var mailboxIds = []
          for (var i = 0; i < root.selectedMailboxIds.length; i++)
            mailboxIds.push(Number(root.selectedMailboxIds[i]))
          root.service.createSimpleCustom(prefixField.text.trim(), suffixDropdown.value, mailboxIds, nameField.text.trim(), noteField.text.trim())
          prefixField.clear()
          nameField.clear()
          noteField.clear()
          root.selectedMailboxIds = []
          root.customVisible = false
        }
      }
    }

    PanelSeparator {}

    Row {
      width: parent.width
      spacing: Style.space(6)
      TextField {
        id: searchField
        width: parent.width - filterDropdown.width - refreshButton.width - parent.spacing * 2
        placeholderText: "Search aliases"
        enabled: root.connected
        onAccepted: { root.page = 0; root.refresh() }
      }
      Dropdown {
        id: filterDropdown
        width: Style.space(118)
        showLabel: false
        value: "all"
        options: [
          { value: "all", label: "All" },
          { value: "enabled", label: "Enabled" },
          { value: "disabled", label: "Disabled" },
          { value: "pinned", label: "Pinned" }
        ]
        onChanged: {
          if (!root.controlsReady || !root.connected) return
          root.page = 0
          root.refresh()
        }
      }
      PanelActionButton {
        id: refreshButton
        iconText: "󰑓"
        tooltipText: "Refresh aliases"
        focusable: true
        enabled: root.connected && !root.service.simpleBusy
        onClicked: root.refresh()
      }
    }

    Text {
      visible: !root.service.simpleAliases || root.service.simpleAliases.length === 0
      width: parent.width
      text: "No aliases found."
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
      model: root.service.simpleAliases || []
      delegate: Rectangle {
        required property var modelData
        width: root.width
        implicitHeight: aliasRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: Util.alpha(Color.foreground, 0.05)
        readonly property string address: String(modelData.email || "")
        readonly property bool enabledAlias: modelData.enabled === true
        readonly property bool pinnedAlias: modelData.pinned === true
        readonly property string mailbox: root.mailboxText(modelData.mailboxes || [])
        readonly property string counters: root.counterText(modelData)

        Column {
          id: aliasRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(8)
          spacing: Style.space(5)
          Row {
            width: parent.width
            Text { width: parent.width - stateText.width - Style.space(8); text: address; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideMiddle }
            Text { id: stateText; text: enabledAlias ? "Enabled" : "Disabled"; color: enabledAlias ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
          Text { width: parent.width; text: "Mailbox: " + mailbox + (counters ? "  |  " + counters : ""); color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
          Row {
            spacing: Style.space(4)
            Button { text: "Copy"; focusable: true; onClicked: root.service.copyText(address) }
            Button { text: pinnedAlias ? "Unpin" : "Pin"; focusable: true; enabled: root.connected; onClicked: root.service.setSimplePinned(modelData, !pinnedAlias) }
            Button {
              text: enabledAlias ? "Disable" : "Enable"
              focusable: true
              enabled: root.connected
              foreground: enabledAlias ? Color.urgent : Color.foreground
              onClicked: {
                if (!enabledAlias) root.service.toggleSimpleAlias(modelData)
                else root.requestConfirmation("Disable " + address + "? It will stop forwarding messages.", function() { root.service.toggleSimpleAlias(modelData) }, "Disable")
              }
            }
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(8)
      Button { text: "Previous"; focusable: true; enabled: root.connected && root.page > 0 && !root.service.simpleBusy; onClicked: { root.page--; root.refresh() } }
      Text { text: "Page " + (root.page + 1); color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
      Button { text: "Next"; focusable: true; enabled: root.connected && root.service.simpleAliases && root.service.simpleAliases.length === 20 && !root.service.simpleBusy; onClicked: { root.page++; root.refresh() } }
    }

    PanelSeparator {}
    Button {
      text: "Disconnect SimpleLogin"
      iconText: "󰌙"
      focusable: true
      enabled: !root.service.actionBusy
      foreground: Color.urgent
      onClicked: root.requestConfirmation(
        "Disconnect SimpleLogin and remove its saved API key? Cached aliases will be cleared.",
        function() { root.service.disconnectProvider("simplelogin") },
        "Disconnect")
    }
  }
}

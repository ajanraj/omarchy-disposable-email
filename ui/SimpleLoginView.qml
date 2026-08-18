import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root
  required property var service
  required property var requestConfirmation

  width: parent ? parent.width : implicitWidth
  height: parent ? parent.height : implicitHeight
  spacing: Style.space(12)

  property bool customVisible: false
  property int page: 0
  property var selectedMailboxIds: []
  property bool controlsReady: false
  readonly property string credentialState: service ? String(service.simpleCredentialState || "") : ""
  readonly property bool connected: credentialState === "connected" || credentialState === "available" || credentialState === "ready"
  readonly property bool configured: connected || credentialState === "attention"
  readonly property bool fullPanelHeight: root.configured

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

  PanelSectionHeader {
    Layout.fillWidth: true
    text: "SIMPLELOGIN"
  }

  StatusBanner {
    Layout.fillWidth: true
    reserveSpace: true
    text: root.service && root.service.simpleError
      ? String(root.service.simpleError)
      : root.service && root.service.simpleStale
        ? "Showing cached aliases. Refresh to try again."
        : root.connected ? "SimpleLogin connected." : "Connect an API key to manage aliases."
    error: root.service && root.service.simpleError !== ""
    warning: !error && root.service && root.service.simpleStale
  }

  ColumnLayout {
    visible: !root.connected
    Layout.fillWidth: true
    spacing: Style.space(8)

    Text {
      Layout.fillWidth: true
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
      Layout.fillWidth: true
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

  ColumnLayout {
    visible: root.configured
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 0
    spacing: Style.space(10)

    Row {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Button {
        readonly property bool creating: root.service.simpleOperation === "random"
        width: Style.space(132)
        text: creating ? "Creating..." : "Random Alias"
        iconText: creating ? "󰦖" : "+"
        iconSpinning: creating
        focusable: true
        enabled: root.connected && root.service.simpleCanCreate && !root.service.actionBusy
        onClicked: root.service.createSimpleRandom()
      }

      Button {
        readonly property bool loading: root.service.simpleOperation === "options"
        width: Style.space(132)
        text: loading ? "Loading..." : (root.customVisible ? "Cancel Custom" : "Custom Alias")
        iconText: loading ? "󰦖" : "󰅖"
        iconSpinning: loading
        focusable: true
        enabled: root.connected && root.service.simpleCanCreate && !root.service.actionBusy
        onClicked: {
          root.customVisible = !root.customVisible
          if (root.customVisible) root.service.prepareSimpleCustom()
        }
      }
    }

    ColumnLayout {
      visible: root.customVisible
      Layout.fillWidth: true
      spacing: Style.space(8)

      Row {
        Layout.fillWidth: true
        spacing: Style.space(6)

        TextField {
          id: prefixField
          width: parent.width * 0.42
          placeholderText: "Prefix"
        }

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
        Layout.fillWidth: true
        label: "Forward to"
        values: root.selectedMailboxIds
        options: root.mailboxOptions()
        onChanged: function(values) { root.selectedMailboxIds = values }
      }

      TextField {
        id: nameField
        Layout.fillWidth: true
        placeholderText: "Name (optional)"
      }

      TextField {
        id: noteField
        Layout.fillWidth: true
        placeholderText: "Note (optional)"
      }

      Button {
        readonly property bool creating: root.service.simpleOperation === "custom"
        width: Style.space(178)
        text: creating ? "Creating..." : "Create Custom Alias"
        iconText: creating ? "󰦖" : "+"
        iconSpinning: creating
        focusable: true
        enabled: root.connected && prefixField.text.trim().length > 0 && suffixDropdown.value !== "" && root.selectedMailboxIds.length > 0 && !root.service.actionBusy
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

    Row {
      Layout.fillWidth: true
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

      Button {
        id: refreshButton
        width: Style.space(36)
        text: ""
        iconText: "󰑓"
        iconSpinning: root.service.simpleOperation === "aliases"
        tooltipText: root.service.simpleOperation === "aliases" ? "Refreshing aliases" : "Refresh aliases"
        focusable: true
        enabled: root.connected && !root.service.actionBusy
        onClicked: root.refresh()
      }
    }

    ScrollableHistory {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      title: "ALIASES"
      emptyText: "No aliases found."
      model: root.service.simpleAliases || []
      delegateComponent: Component {
        AddressHistoryCard {
          required property var modelData
          width: ListView.view ? ListView.view.width : implicitWidth
          readonly property bool enabledAlias: modelData.enabled === true
          readonly property bool pinnedAlias: modelData.pinned === true
          readonly property string mailbox: root.mailboxText(modelData.mailboxes || [])
          readonly property string counters: root.counterText(modelData)
          readonly property bool savingPin: root.service.simpleOperation === "pinned"
            && root.service.simpleTargetAliasId === Number(modelData.id)
          readonly property bool updating: root.service.simpleOperation === "toggle"
            && root.service.simpleTargetAliasId === Number(modelData.id)
          providerLabel: "SimpleLogin"
          address: String(modelData.email || "")
          statusText: enabledAlias ? "Enabled" : "Disabled"
          statusColor: enabledAlias ? Color.accent : Color.muted
          detailText: "Mailbox: " + mailbox + (counters ? "  |  " + counters : "")
          showForget: false
          actions: [
            {
              id: "pin",
              width: Style.space(104),
              text: savingPin ? "Saving..." : (pinnedAlias ? "Unpin" : "Pin"),
              icon: savingPin ? "󰦖" : "",
              busy: savingPin,
              enabled: root.connected && !root.service.actionBusy
            },
            {
              id: "toggle",
              width: Style.space(112),
              text: updating ? "Updating..." : (enabledAlias ? "Disable" : "Enable"),
              icon: updating ? "󰦖" : "",
              busy: updating,
              destructive: enabledAlias,
              enabled: root.connected && !root.service.actionBusy
            }
          ]
          onCopyRequested: root.service.copyText(address)
          onActionRequested: function(actionId) {
            if (actionId === "pin") {
              root.service.setSimplePinned(modelData, !pinnedAlias)
            } else if (!enabledAlias) {
              root.service.toggleSimpleAlias(modelData)
            } else {
              root.requestConfirmation(
                "Disable " + address + "? It will stop forwarding messages.",
                function() { root.service.toggleSimpleAlias(modelData) },
                "Disable")
            }
          }
        }
      }
    }

    Row {
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.space(8)

      Button {
        text: "Previous"
        focusable: true
        enabled: root.connected && root.page > 0 && !root.service.actionBusy
        onClicked: { root.page--; root.refresh() }
      }

      Text {
        text: "Page " + (root.page + 1)
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Button {
        text: "Next"
        focusable: true
        enabled: root.connected && root.service.simpleAliases && root.service.simpleAliases.length === 20 && !root.service.actionBusy
        onClicked: { root.page++; root.refresh() }
      }
    }

    PanelSeparator {
      Layout.fillWidth: true
    }

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

import QtQuick
import Quickshell
import Quickshell.Io
import "lib"
import "lib/StateModel.js" as StateModel
import "providers"

// One state owner is shared by every per-monitor bar widget. It performs
// network work only in response to an explicit panel or IPC action.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string lastTab: stateStore.state ? stateStore.state.lastTab : "temporary"
  readonly property string temporaryProvider: stateStore.state ? stateStore.state.temporaryProvider : "maildrop"
  readonly property var temporaryAddresses: stateStore.state ? stateStore.state.temporaryAddresses : []
  readonly property var knownDuckAliases: stateStore.state ? stateStore.state.knownDuckAliases : []

  readonly property bool temporaryBusy: temporaryAdapter.busy
  readonly property string temporaryError: temporaryAdapter.error

  property string duckCredentialState: "loading"
  readonly property bool duckBusy: duckAdapter.busy
  readonly property string duckOperation: duckAdapter.operation !== ""
    ? duckAdapter.operation : _pendingDuckOperation()
  readonly property string duckTargetAddress: duckAdapter.targetAddress !== ""
    ? duckAdapter.targetAddress : _pendingDuckTarget()
  property bool duckRemoteAvailable: true
  property string _duckError: ""
  readonly property string duckError: _duckError !== "" ? _duckError : duckAdapter.error

  property string simpleCredentialState: "loading"
  readonly property bool simpleBusy: simpleAdapter.busy
  readonly property string simpleOperation: simpleAdapter.operation !== ""
    ? simpleAdapter.operation : _pendingSimpleOperation()
  readonly property int simpleTargetAliasId: simpleAdapter.operation !== ""
    ? simpleAdapter.targetAliasId : _pendingSimpleTarget()
  property string _simpleError: ""
  readonly property string simpleError: _simpleError !== "" ? _simpleError : simpleAdapter.error
  property bool simpleStale: false
  property string simpleLastRefresh: ""
  property var simpleAliases: []
  property var simpleAliasOptions: null
  property var simpleMailboxes: []
  property bool simpleCanCreate: true
  readonly property bool actionBusy: credentials.busy || _credentialCurrent !== null
    || temporaryAdapter.busy || duckAdapter.busy || simpleAdapter.busy

  property string _simpleQuery: ""
  property string _simpleFilter: "all"
  property int _simplePage: 0

  property var _credentialTasks: []
  property var _credentialCurrent: null
  property var _quickCreate: null

  function _providerLabel(provider) {
    if (provider === "maildrop") return "Maildrop"
    if (provider === "harakiri") return "Harakiri Mail"
    if (provider === "duckduckgo") return "DuckDuckGo"
    return "SimpleLogin"
  }

  function _notify(headline, description, openPanel) {
    if (openPanel === true) {
      Quickshell.execDetached([
        omarchyPath + "/bin/omarchy-notification-send",
        "--exec", "omarchy-shell shell summon io.github.ajanraj.disposable-email",
        headline, description
      ])
    } else if (description) {
      Quickshell.execDetached([
        omarchyPath + "/bin/omarchy-notification-send", headline, description
      ])
    } else {
      Quickshell.execDetached([
        omarchyPath + "/bin/omarchy-notification-send", headline
      ])
    }
  }

  function _quickBusy() {
    _notify("Disposable Email is busy", "Wait for the current action, then try again", false)
    return "busy"
  }

  function _beginQuick(provider, action, noun) {
    _quickCreate = {
      provider: provider,
      action: action,
      noun: noun,
      phase: "creating"
    }
  }

  function _quickMatches(provider, action) {
    var quick = _quickCreate
    return quick && quick.phase === "creating" && quick.provider === provider
      && (!action || quick.action === action)
  }

  function _finishQuickFailure(headline, description, openPanel) {
    if (!_quickCreate) return
    _quickCreate = null
    _notify(headline, description, openPanel)
  }

  function _quickCredentialFailed(provider, action) {
    if (!_quickMatches(provider, action)) return
    setLastTab(provider)
    _finishQuickFailure(_providerLabel(provider) + " credential unavailable",
      "Open Disposable Email to add or replace the saved credential", true)
  }

  function _quickUnauthorized(provider) {
    if (!_quickMatches(provider, "")) return
    setLastTab(provider)
    _finishQuickFailure(_providerLabel(provider) + " rejected the saved credential",
      "Open Disposable Email to replace or disconnect it", true)
  }

  function _quickProviderFailed(provider, action) {
    if (!_quickMatches(provider, action)) return
    var label = _providerLabel(provider)
    var noun = _quickCreate.noun
    _finishQuickFailure(label + " could not create an " + noun,
      "Check your connection and try again", true)
  }

  function _copyQuick(value) {
    if (!_quickCreate) {
      copyText(value)
      return
    }
    var quick = _quickCreate
    quick.phase = "copying"
    _quickCreate = quick
    _queueCopy(value, true)
  }

  function quickTemporary(provider) {
    if (actionBusy || _quickCreate !== null) return _quickBusy()
    var selected = String(provider || "")
    if (selected === "") selected = temporaryProvider
    if (selected !== "maildrop" && selected !== "harakiri") {
      _notify("Invalid temporary email provider", "Use maildrop or harakiri", false)
      return "invalid-provider"
    }
    _beginQuick(selected, "temporary", "address")
    if (!temporaryAdapter.create(selected)) {
      _quickProviderFailed(selected, "temporary")
      return "error"
    }
    return "started"
  }

  function quickDuckDuckGo() {
    if (actionBusy || _quickCreate !== null) return _quickBusy()
    _beginQuick("duckduckgo", "duck-generate", "alias")
    generateDuck()
    return "started"
  }

  function quickSimpleLogin() {
    if (actionBusy || _quickCreate !== null) return _quickBusy()
    _beginQuick("simplelogin", "simple-random", "alias")
    createSimpleRandom()
    return "started"
  }

  function _pendingDuckOperation() {
    var task = _credentialCurrent
    if (!task || task.provider !== "duckduckgo") return ""
    if (task.action === "duck-generate") return "generate"
    if (task.action === "duck-status") return "status"
    if (task.action === "duck-active") return "setActive"
    return ""
  }

  function _pendingDuckTarget() {
    var task = _credentialCurrent
    return task && task.provider === "duckduckgo" && task.payload
      ? String(task.payload.address || "") : ""
  }

  function _pendingSimpleOperation() {
    var task = _credentialCurrent
    if (!task || task.provider !== "simplelogin") return ""
    var actions = {
      "simple-list": "aliases",
      "simple-random": "random",
      "simple-options": "options",
      "simple-custom": "custom",
      "simple-pinned": "pinned",
      "simple-toggle": "toggle"
    }
    return String(actions[task.action] || "")
  }

  function _pendingSimpleTarget() {
    var task = _credentialCurrent
    return task && task.provider === "simplelogin" && task.payload
      ? Number(task.payload.aliasId || 0) : 0
  }

  function _saveState(next) {
    stateStore.save(next)
  }

  function setLastTab(tab) {
    _saveState(StateModel.setLastTab(stateStore.state, tab))
  }

  function setTemporaryProvider(provider) {
    _saveState(StateModel.setTemporaryProvider(stateStore.state, provider))
  }

  function createTemporary() {
    temporaryAdapter.create(temporaryProvider)
  }

  function forgetTemporary(address) {
    _saveState(StateModel.removeTemporaryAddress(stateStore.state, address))
  }

  function copyText(value) {
    var text = String(value || "")
    if (text === "") return
    _queueCopy(text, false)
  }

  function _queueCopy(text, quick) {
    if (copyProcess.running || _clipboardScheduled) {
      var next = _clipboardQueue.slice()
      var item = { text: text, quick: quick === true }
      // Preserve a pending shortcut result, but coalesce rapid manual copies
      // so the most recently selected address wins as it did before IPC.
      if (!item.quick && next.length > 0 && next[next.length - 1].quick !== true)
        next[next.length - 1] = item
      else
        next.push(item)
      _clipboardQueue = next
      return
    }
    _startCopy(text, quick === true)
  }

  function _startCopy(text, quick) {
    _activeClipboardText = text
    _activeClipboardQuick = quick === true
    _clipboardHandled = false
    copyProcess.stdinEnabled = true
    copyProcess.running = true
  }

  function _finishClipboard(exitCode) {
    if (_clipboardHandled) return
    _clipboardHandled = true
    var wasQuick = _activeClipboardQuick
    _activeClipboardQuick = false
    _activeClipboardText = ""

    if (wasQuick && _quickCreate) {
      if (exitCode === 0) {
        var quick = _quickCreate
        _quickCreate = null
        _notify(_providerLabel(quick.provider) + " " + quick.noun + " copied", "", false)
      } else {
        _finishQuickFailure("Could not copy to the clipboard",
          "Check that wl-clipboard is available, then try again", true)
      }
    }

    if (_clipboardQueue.length === 0) return
    _clipboardScheduled = true
    Qt.callLater(function() {
      var next = root._clipboardQueue.slice()
      var item = next.shift()
      root._clipboardQueue = next
      root._clipboardScheduled = false
      root._startCopy(item.text, item.quick)
    })
  }

  function openUrl(value) {
    var url = String(value || "")
    if (!/^https:\/\//.test(url)) return false
    Quickshell.execDetached(["/usr/bin/xdg-open", url])
    return true
  }

  function connectProvider(provider, token) {
    if (provider !== "duckduckgo" && provider !== "simplelogin") return false
    if (actionBusy) return false
    var value = String(token || "")
    if (value === "") return false
    if (provider === "duckduckgo") {
      duckCredentialState = "loading"
      _duckError = ""
    } else {
      simpleCredentialState = "loading"
      _simpleError = ""
    }
    _enqueueCredential({ kind: "store", provider: provider, token: value })
    value = ""
    return true
  }

  function disconnectProvider(provider) {
    if (provider !== "duckduckgo" && provider !== "simplelogin") return false
    if (actionBusy) return false
    _enqueueCredential({ kind: "clear", provider: provider, reset: false })
    return true
  }

  function resetPluginData() {
    if (actionBusy) return false
    _credentialTasks = []
    if (_credentialCurrent && _credentialCurrent.kind === "lookup")
      _credentialCurrent.action = "check"
    stateStore.resetState()
    simpleAliases = []
    simpleAliasOptions = null
    simpleMailboxes = []
    simpleCanCreate = true
    simpleStale = false
    simpleLastRefresh = ""
    _duckError = ""
    _simpleError = ""
    duckCredentialState = "loading"
    simpleCredentialState = "loading"
    _enqueueCredential({ kind: "clear", provider: "duckduckgo", reset: true })
    _enqueueCredential({ kind: "clear", provider: "simplelogin", reset: true })
    return true
  }

  function generateDuck() {
    _duckError = ""
    _requestCredential("duckduckgo", "duck-generate", null)
  }

  function refreshDuck(address) {
    _duckError = ""
    _requestCredential("duckduckgo", "duck-status", { address: String(address || "") })
  }

  function setDuckActive(address, active) {
    _duckError = ""
    _requestCredential("duckduckgo", "duck-active", {
      address: String(address || ""),
      active: active === true
    })
  }

  function forgetDuck(address) {
    _saveState(StateModel.removeDuckAlias(stateStore.state, address))
  }

  function retryDuckRequests() {
    _duckError = ""
    duckAdapter.error = ""
    duckRemoteAvailable = true
  }

  function refreshSimpleLogin(query, filter, page) {
    _simpleQuery = String(query || "")
    _simpleFilter = ["all", "enabled", "disabled", "pinned"].indexOf(filter) >= 0 ? filter : "all"
    _simplePage = Math.max(0, parseInt(page, 10) || 0)
    _simpleError = ""
    _requestCredential("simplelogin", "simple-list", {
      query: _simpleQuery,
      filter: _simpleFilter,
      page: _simplePage
    })
  }

  function createSimpleRandom() {
    _simpleError = ""
    _requestCredential("simplelogin", "simple-random", null)
  }

  function prepareSimpleCustom() {
    _simpleError = ""
    _requestCredential("simplelogin", "simple-options", null)
  }

  function createSimpleCustom(prefix, signedSuffix, mailboxIds, name, note) {
    _simpleError = ""
    _requestCredential("simplelogin", "simple-custom", {
      prefix: prefix,
      signedSuffix: signedSuffix,
      mailboxIds: mailboxIds,
      name: name,
      note: note
    })
  }

  function setSimplePinned(alias, pinned) {
    if (!alias || !alias.id) return false
    _simpleError = ""
    _requestCredential("simplelogin", "simple-pinned", {
      aliasId: Number(alias.id),
      pinned: pinned === true
    })
    return true
  }

  function toggleSimpleAlias(alias) {
    if (!alias || !alias.id) return false
    _simpleError = ""
    _requestCredential("simplelogin", "simple-toggle", { aliasId: Number(alias.id) })
    return true
  }

  function _requestCredential(provider, action, payload) {
    _enqueueCredential({
      kind: "lookup",
      provider: provider,
      action: action,
      payload: payload
    })
  }

  function _enqueueCredential(task) {
    var next = _credentialTasks.slice()
    next.push(task)
    _credentialTasks = next
    _runNextCredentialTask()
  }

  function _runNextCredentialTask() {
    if (_credentialCurrent !== null || credentials.busy || _credentialTasks.length === 0) return
    var next = _credentialTasks.slice()
    var task = next.shift()
    _credentialTasks = next
    _credentialCurrent = task

    var started = false
    if (task.kind === "lookup") {
      started = credentials.lookup(task.provider)
    } else if (task.kind === "clear") {
      started = credentials.clear(task.provider)
    } else if (task.kind === "store") {
      var token = task.token
      task.token = ""
      started = credentials.store(task.provider, token)
      token = ""
    }

    if (!started) _completeCredentialTask()
  }

  function _completeCredentialTask() {
    _credentialCurrent = null
    Qt.callLater(_runNextCredentialTask)
  }

  function _setCredentialState(provider, value) {
    if (provider === "duckduckgo") duckCredentialState = value
    else if (provider === "simplelogin") simpleCredentialState = value
  }

  function _credentialLookupSucceeded(provider, token) {
    var task = _credentialCurrent
    if (!task || task.kind !== "lookup" || task.provider !== provider) {
      token = ""
      return
    }
    _setCredentialState(provider, "connected")
    _dispatchProviderAction(task.action, token, task.payload)
    token = ""
    _completeCredentialTask()
  }

  function _credentialLookupFailed(provider, message) {
    var task = _credentialCurrent
    if (!task || task.kind !== "lookup" || task.provider !== provider) return
    if (task.action === "check") {
      _setCredentialState(provider, "disconnected")
    } else {
      _setCredentialState(provider, "attention")
      if (provider === "duckduckgo") _duckError = "DuckDuckGo credential is unavailable"
      else {
        _simpleError = "SimpleLogin credential is unavailable"
        if (simpleAliases.length > 0) simpleStale = true
      }
    }
    _quickCredentialFailed(provider, task.action)
    _completeCredentialTask()
  }

  function _credentialStored(provider) {
    _setCredentialState(provider, "connected")
    if (provider === "duckduckgo") {
      _duckError = ""
      duckAdapter.error = ""
      duckRemoteAvailable = true
    } else {
      _simpleError = ""
      simpleAdapter.error = ""
    }
    _completeCredentialTask()
  }

  function _credentialStoreFailed(provider, message) {
    _setCredentialState(provider, "attention")
    if (provider === "duckduckgo") _duckError = "Could not store DuckDuckGo credential"
    else _simpleError = "Could not store SimpleLogin credential"
    _completeCredentialTask()
  }

  function _credentialCleared(provider) {
    _setCredentialState(provider, "disconnected")
    if (provider === "duckduckgo") {
      var state = StateModel.normalize(stateStore.state)
      state.knownDuckAliases = []
      _saveState(state)
      _duckError = ""
    } else {
      simpleAliases = []
      simpleAliasOptions = null
      simpleMailboxes = []
      simpleCanCreate = true
      simpleStale = false
      simpleLastRefresh = ""
      _simpleError = ""
    }
    _completeCredentialTask()
  }

  function _credentialClearFailed(provider, message) {
    var task = _credentialCurrent
    var duringReset = task && task.reset === true
    _setCredentialState(provider, "attention")
    if (provider === "duckduckgo") {
      _duckError = duringReset
        ? "Local data was reset, but the DuckDuckGo credential could not be removed"
        : "Could not remove the DuckDuckGo credential"
    } else {
      _simpleError = duringReset
        ? "Local data was reset, but the SimpleLogin credential could not be removed"
        : "Could not remove the SimpleLogin credential"
    }
    _completeCredentialTask()
  }

  function _credentialOperationRejected(provider, operation, message) {
    if (_credentialCurrent === null) return
    var task = _credentialCurrent
    if (provider === "duckduckgo") _duckError = message
    else if (provider === "simplelogin") _simpleError = message
    if (task && task.kind === "lookup") _quickCredentialFailed(provider, task.action)
    _completeCredentialTask()
  }

  function _dispatchProviderAction(action, token, payload) {
    if (action === "check") return
    if (action === "duck-generate") duckAdapter.generate(token)
    else if (action === "duck-status") duckAdapter.fetchStatus(token, payload.address)
    else if (action === "duck-active") duckAdapter.setActive(token, payload.address, payload.active)
    else if (action === "simple-list") simpleAdapter.searchAliases(token, payload.query, payload.filter, payload.page)
    else if (action === "simple-random") simpleAdapter.createRandom(token)
    else if (action === "simple-options") simpleAdapter.loadCustomOptions(token)
    else if (action === "simple-custom") simpleAdapter.createCustom(token, payload.prefix,
      payload.signedSuffix, payload.mailboxIds, payload.name, payload.note)
    else if (action === "simple-pinned") simpleAdapter.setPinned(token, payload.aliasId, payload.pinned)
    else if (action === "simple-toggle") simpleAdapter.toggle(token, payload.aliasId)
  }

  function _markUnauthorized(provider) {
    _setCredentialState(provider, "attention")
    if (provider === "duckduckgo") {
      duckRemoteAvailable = false
      _duckError = "DuckDuckGo rejected the saved token. Replace it or disconnect."
    }
    else _simpleError = "SimpleLogin rejected the saved API key. Replace it or disconnect."
    _quickUnauthorized(provider)
  }

  function _updateSimpleAlias(patch) {
    if (!patch || !patch.id) return
    var next = []
    for (var i = 0; i < simpleAliases.length; i++) {
      var existing = simpleAliases[i]
      if (Number(existing.id) !== Number(patch.id)) {
        next.push(existing)
        continue
      }
      var updated = {}
      for (var key in existing) updated[key] = existing[key]
      for (var patchKey in patch) updated[patchKey] = patch[patchKey]
      next.push(updated)
    }
    simpleAliases = next
  }

  property string _activeClipboardText: ""
  property bool _activeClipboardQuick: false
  property bool _clipboardHandled: true
  property bool _clipboardScheduled: false
  property var _clipboardQueue: []

  Process {
    id: copyProcess
    command: ["/usr/bin/wl-copy"]
    stdinEnabled: true

    onStarted: {
      var value = root._activeClipboardText
      root._activeClipboardText = ""
      write(value)
      value = ""
      stdinEnabled = false
    }

    onExited: function(exitCode, exitStatus) {
      root._finishClipboard(exitCode)
    }

    onRunningChanged: {
      if (running || root._activeClipboardText === "" || root._clipboardHandled) return
      Qt.callLater(function() {
        if (!copyProcess.running && root._activeClipboardText !== ""
            && !root._clipboardHandled) root._finishClipboard(-1)
      })
    }
  }

  StateStore {
    id: stateStore
  }

  CredentialStore {
    id: credentials

    onLookupSucceeded: function(provider, token) { root._credentialLookupSucceeded(provider, token) }
    onLookupFailed: function(provider, error) { root._credentialLookupFailed(provider, error) }
    onStoreSucceeded: function(provider) { root._credentialStored(provider) }
    onStoreFailed: function(provider, error) { root._credentialStoreFailed(provider, error) }
    onClearSucceeded: function(provider) { root._credentialCleared(provider) }
    onClearFailed: function(provider, error) { root._credentialClearFailed(provider, error) }
    onOperationRejected: function(provider, operation, error) {
      root._credentialOperationRejected(provider, operation, error)
    }
  }

  TemporaryAddress {
    id: temporaryAdapter

    onCreated: function(result) {
      root._saveState(StateModel.addTemporaryAddress(stateStore.state, result))
      if (root._quickMatches(root._quickCreate ? root._quickCreate.provider : "", "temporary"))
        root._copyQuick(result.address)
      else
        root.copyText(result.address)
    }
    onErrorChanged: {
      if (temporaryAdapter.error !== "") Qt.callLater(function() {
        if (root._quickCreate)
          root._quickProviderFailed(root._quickCreate.provider, "temporary")
      })
    }
  }

  DuckDuckGo {
    id: duckAdapter

    onGenerated: function(result) {
      root._duckError = ""
      root.duckRemoteAvailable = true
      root._saveState(StateModel.addDuckAlias(stateStore.state, {
        address: result.address,
        active: true
      }))
      if (root._quickMatches("duckduckgo", "duck-generate")) root._copyQuick(result.address)
      else root.copyText(result.address)
    }
    onStatusFetched: function(result) {
      root._duckError = ""
      root.duckRemoteAvailable = true
      root._saveState(StateModel.updateDuckAlias(stateStore.state, result.address, result.active))
    }
    onActiveChanged: function(result) {
      root._duckError = ""
      root.duckRemoteAvailable = true
      root._saveState(StateModel.updateDuckAlias(stateStore.state, result.address, result.active))
    }
    onUnauthorized: root._markUnauthorized("duckduckgo")
    onErrorChanged: {
      if (duckAdapter.error !== "") {
        root.duckRemoteAvailable = false
        Qt.callLater(function() { root._quickProviderFailed("duckduckgo", "duck-generate") })
      }
    }
  }

  SimpleLogin {
    id: simpleAdapter

    onRandomCreated: function(alias) {
      root._simpleError = ""
      if (root._quickMatches("simplelogin", "simple-random")) root._copyQuick(alias.email)
      else root.copyText(alias.email)
      root.refreshSimpleLogin(root._simpleQuery, root._simpleFilter, root._simplePage)
    }
    onCustomOptionsLoaded: function(options) {
      root._simpleError = ""
      root.simpleAliasOptions = options
      root.simpleMailboxes = options.mailboxes || []
      root.simpleCanCreate = options.canCreate !== false
    }
    onCustomCreated: function(alias) {
      root._simpleError = ""
      root.copyText(alias.email)
      root.refreshSimpleLogin(root._simpleQuery, root._simpleFilter, root._simplePage)
    }
    onAliasesLoaded: function(aliases) {
      root._simpleError = ""
      root.simpleAliases = aliases
      root.simpleStale = false
      root.simpleLastRefresh = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")
    }
    onAliasPatched: function(result) {
      root._simpleError = ""
      root._updateSimpleAlias(result)
    }
    onAliasToggled: function(result) {
      root._simpleError = ""
      root._updateSimpleAlias(result)
    }
    onUnauthorized: root._markUnauthorized("simplelogin")
    onPlanLimit: function(message) {
      root.simpleCanCreate = false
      root._simpleError = message
      if (root._quickMatches("simplelogin", "simple-random"))
        root._finishQuickFailure("SimpleLogin cannot create another alias",
          "Check your plan or delete an alias, then try again", true)
    }
    onErrorChanged: {
      if (simpleAdapter.error !== "" && root.simpleAliases.length > 0)
        root.simpleStale = true
      if (simpleAdapter.error !== "")
        Qt.callLater(function() { root._quickProviderFailed("simplelogin", "simple-random") })
    }
  }

  IpcHandler {
    target: "io.github.ajanraj.disposable-email"

    function temporary(provider: string): string {
      return root.quickTemporary(provider)
    }

    function duckduckgo(): string {
      return root.quickDuckDuckGo()
    }

    function simplelogin(): string {
      return root.quickSimpleLogin()
    }
  }

  Component.onCompleted: {
    _requestCredential("duckduckgo", "check", null)
    _requestCredential("simplelogin", "check", null)
  }
}

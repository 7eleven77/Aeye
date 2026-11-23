import QtQuick
import qs.Commons

// Shared in-memory state hub between Aeye's floating HUD (Panel.qml) and its
// top-bar icon + settings popout (BarWidget.qml).
QtObject {
  id: svc

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // Live HUD state (published by Panel.qml)
  property string stage: "idle"
  property bool paused: false
  property bool windowOpen: false
  property bool backgroundRun: false
  property bool hasUnreadAnswer: false
  property bool hasAnswer: false
  property bool hasImage: false
  property string producerName: "Gemini"
  property string modelLabel: "Flash"
  property string visionWhy: ""
  property string statusTip: "Aeye"

  // Live theme semantic colors derived from Omarchy's active theme
  property color colAnalysing: Color.accent
  property color colSuccess: Color.accent

  // Shared configuration & provider auth status (synced from Panel.qml)
  property string provider: "agy"
  property string model: "gemini-3.8-flash-high"
  property bool autosend: false
  property bool minimizeOnSend: true
  property bool minimalMode: false
  property bool showReason: false
  property bool systemDebug: false
  property bool agentMemory: false
  property bool autoDelegate: true
  property string lastSaveDir: "~/Documents"
  property string lang: "auto"
  property string activeLang: "en"
  property string localeDisplayLabel: "Auto (EN)"
  property string hudPlacement: "bottom" // bottom | top | corner | dock-right | dock-left
  property var customPrompts: []
  property var customModels: []
  property var providerStatuses: []
  property var availableModels: ({})
  property bool loadingModels: false
  property string customContext: ""
  property string contextFile: ""
  property var providerAuthMode: ({})
  property var modelAuthMode: ({})

  // Actions emitted by BarWidget.qml -> handled by Panel.qml
  signal openHudRequested()
  signal captureRequested()
  signal pauseToggleRequested()
  signal stopAskRequested()
  signal pickModelRequested(int index)
  signal addCustomModelRequested(string vendorKey, string modelId, string label)
  signal removeCustomModelRequested(string modelId)
  signal setAutosendRequested(bool on)
  signal setMinimizeOnSendRequested(bool on)
  signal setMinimalModeRequested(bool on)
  signal setShowReasonRequested(bool on)
  signal setSystemDebugRequested(bool on)
  signal setAgentMemoryRequested(bool on)
  signal setAutoDelegateRequested(bool on)
  signal cycleLocaleRequested(int dir)
  signal setHudPlacementRequested(string placement)
  signal addCustomPromptRequested(string phrase)
  signal removeCustomPromptRequested(string phrase)
  signal setCustomContextRequested(string text)
  signal setContextFileRequested(string path)
  signal editContextFileRequested(string path)
  signal pickContextFileRequested()
  signal refreshProvidersRequested()
  signal refreshAvailableModelsRequested(bool force)
  signal setApiKeyRequested(string vendor, string apiKey)
  signal setProviderAuthModeRequested(string vendor, string mode)
  signal setModelAuthModeRequested(string modelId, string mode)

  function requestOpenHud() { openHudRequested() }
  function requestCapture() { captureRequested() }
  function requestPauseToggle() { pauseToggleRequested() }
  function requestStopAsk() { stopAskRequested() }
  function requestPickModel(index) { pickModelRequested(index) }
  function requestAddCustomModel(vendorKey, modelId, label) { addCustomModelRequested(vendorKey, modelId, label) }
  function requestRemoveCustomModel(modelId) { removeCustomModelRequested(modelId) }
  function requestSetAutosend(on) { setAutosendRequested(on) }
  function requestSetMinimizeOnSend(on) { setMinimizeOnSendRequested(on) }
  function requestSetMinimalMode(on) { setMinimalModeRequested(on) }
  function requestSetShowReason(on) { setShowReasonRequested(on) }
  function requestSetSystemDebug(on) { setSystemDebugRequested(on) }
  function requestSetAgentMemory(on) { setAgentMemoryRequested(on) }
  function requestSetAutoDelegate(on) { setAutoDelegateRequested(on) }
  function requestCycleLocale(dir) { cycleLocaleRequested(dir) }
  function requestSetHudPlacement(placement) { setHudPlacementRequested(placement) }
  function requestAddCustomPrompt(phrase) { addCustomPromptRequested(phrase) }
  function requestRemoveCustomPrompt(phrase) { removeCustomPromptRequested(phrase) }
  function requestSetCustomContext(text) { setCustomContextRequested(text) }
  function requestSetContextFile(path) { setContextFileRequested(path) }
  function requestEditContextFile(path) { editContextFileRequested(path) }
  function requestPickContextFile() { pickContextFileRequested() }
  function requestRefreshProviders() { refreshProvidersRequested() }
  function requestRefreshAvailableModels(force) { refreshAvailableModelsRequested(force === true) }
  function requestSetApiKey(vendor, apiKey) { setApiKeyRequested(vendor, apiKey) }
  function requestSetProviderAuthMode(vendor, mode) { setProviderAuthModeRequested(vendor, mode) }
  function requestSetModelAuthMode(modelId, mode) { setModelAuthModeRequested(modelId, mode) }
}

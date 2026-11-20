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
  property string lang: "auto"
  property string activeLang: "en"
  property string localeDisplayLabel: "Auto (EN)"
  property string hudPlacement: "bottom" // bottom | top | corner | dock-right | dock-left
  property var customPrompts: []
  property var providerStatuses: []

  // Actions emitted by BarWidget.qml -> handled by Panel.qml
  signal openHudRequested()
  signal captureRequested()
  signal pauseToggleRequested()
  signal stopAskRequested()
  signal pickModelRequested(int index)
  signal setAutosendRequested(bool on)
  signal setMinimizeOnSendRequested(bool on)
  signal setMinimalModeRequested(bool on)
  signal setShowReasonRequested(bool on)
  signal cycleLocaleRequested(int dir)
  signal setHudPlacementRequested(string placement)
  signal addCustomPromptRequested(string phrase)
  signal removeCustomPromptRequested(string phrase)
  signal refreshProvidersRequested()
  signal setApiKeyRequested(string vendor, string apiKey)

  function requestOpenHud() { openHudRequested() }
  function requestCapture() { captureRequested() }
  function requestPauseToggle() { pauseToggleRequested() }
  function requestStopAsk() { stopAskRequested() }
  function requestPickModel(index) { pickModelRequested(index) }
  function requestSetAutosend(on) { setAutosendRequested(on) }
  function requestSetMinimizeOnSend(on) { setMinimizeOnSendRequested(on) }
  function requestSetMinimalMode(on) { setMinimalModeRequested(on) }
  function requestSetShowReason(on) { setShowReasonRequested(on) }
  function requestCycleLocale(dir) { cycleLocaleRequested(dir) }
  function requestSetHudPlacement(placement) { setHudPlacementRequested(placement) }
  function requestAddCustomPrompt(phrase) { addCustomPromptRequested(phrase) }
  function requestRemoveCustomPrompt(phrase) { removeCustomPromptRequested(phrase) }
  function requestRefreshProviders() { refreshProvidersRequested() }
  function requestSetApiKey(vendor, apiKey) { setApiKeyRequested(vendor, apiKey) }
}

import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Aeye top-bar widget: eye mark + native Omarchy KeyboardPanel popout
// for quick capture, settings, API keys, and pinned prompts.
// Chrome follows the live Omarchy theme. Secondary text is mixed from
// the popup foreground, because several themes use `muted` as a surface.
BarWidget {
  id: root
  moduleName: "io.github.7eleven77.aeye"

  readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("io.github.7eleven77.aeye")
    : null

  readonly property string stage: svc ? String(svc.stage || "idle") : "idle"
  readonly property bool paused: svc ? svc.paused === true : false
  readonly property bool windowOpen: svc ? svc.windowOpen === true : false
  readonly property bool hasUnreadAnswer: svc ? svc.hasUnreadAnswer === true : false
  readonly property bool hasAnswer: svc ? svc.hasAnswer === true : false
  readonly property bool hasImage: svc ? svc.hasImage === true : false
  readonly property bool analysing: stage === "analysing"
  readonly property bool isActive: root.opened || root.windowOpen || root.analysing || root.hasUnreadAnswer

  readonly property string modelId: svc ? String(svc.model || "gemini-3.8-flash-high") : "gemini-3.8-flash-high"
  readonly property bool autosend: svc ? svc.autosend === true : false
  readonly property bool minimizeOnSend: svc ? svc.minimizeOnSend === true : true
  readonly property bool minimalMode: svc ? svc.minimalMode === true : false
  readonly property bool showReason: svc ? svc.showReason === true : false
  readonly property bool systemDebug: svc ? svc.systemDebug === true : false
  readonly property bool agentMemory: svc ? svc.agentMemory !== false : true
  readonly property bool autoDelegate: svc ? svc.autoDelegate !== false : true
  readonly property string activeLang: svc ? String(svc.activeLang || "en") : "en"
  readonly property string localeDisplayLabel: svc ? String(svc.localeDisplayLabel || "Auto (EN)") : "Auto (EN)"
  readonly property string hudPlacement: svc ? String(svc.hudPlacement || "bottom") : "bottom"
  readonly property string visionWhy: svc ? String(svc.visionWhy || "") : ""
  readonly property var customPrompts: svc && Array.isArray(svc.customPrompts) ? svc.customPrompts : []
  readonly property var customModels: svc && Array.isArray(svc.customModels) ? svc.customModels : []
  readonly property var providerStatuses: svc && Array.isArray(svc.providerStatuses) ? svc.providerStatuses : []
  readonly property var availableModels: svc && svc.availableModels ? svc.availableModels : ({})
  readonly property bool loadingModels: svc ? svc.loadingModels === true : false
  readonly property var availableModelsForVendor: {
    var list = availableModels && availableModels[newModelVendor]
    return Array.isArray(list) ? list : []
  }
  readonly property string customContext: svc ? String(svc.customContext || "") : ""
  readonly property string contextFile: svc ? String(svc.contextFile || "") : ""
  readonly property var providerAuthMode: svc && svc.providerAuthMode ? svc.providerAuthMode : ({})
  readonly property var modelAuthMode: svc && svc.modelAuthMode ? svc.modelAuthMode : ({})
  readonly property bool hasNoteContext: customContext.replace(/^\s+|\s+$/g, "").length > 0
  readonly property bool hasFileContext: contextFile.replace(/^\s+|\s+$/g, "").length > 0
  readonly property bool hasAnyContext: hasNoteContext || hasFileContext

  // Live Omarchy theme. `dim` is opaque secondary text, not Color.muted.
  // On some themes muted is a near-background surface and cannot be read.
  readonly property color fg: Commons.Color.popups.text
  readonly property color bg: Commons.Color.popups.background
  readonly property color dim: mixOn(bg, fg, 0.72)
  readonly property color line: Commons.Color.popups.border
  readonly property color softLine: Util.alpha(fg, 0.11)
  readonly property color surface: Util.alpha(fg, 0.045)
  readonly property color surfaceHover: Util.alpha(fg, 0.09)
  readonly property color colAnalysing: svc ? svc.colAnalysing : Commons.Color.accent
  readonly property color colSuccess: svc ? svc.colSuccess : Commons.Color.accent
  readonly property string face: bar ? bar.fontFamily : Style.font.family

  readonly property bool opened: panelController.open
  property bool popoutSwitchClosing: false
  property string hoverTip: ""
  property bool optionsPage: false
  property bool contextExpanded: false
  property bool keysExpanded: false
  property bool promptsExpanded: false
  property string editingVendor: ""
  property bool addModelOpen: false
  property string newModelVendor: "gemini"

  function mixOn(back, front, t) {
    if (!back || !front) return front || fg
    return Qt.rgba(
      front.r * t + back.r * (1 - t),
      front.g * t + back.g * (1 - t),
      front.b * t + back.b * (1 - t),
      1
    )
  }

  function setPopoutHover(active, text) {
    if (active && text !== "") hoverTip = text
    else if (!active && hoverTip === text) hoverTip = ""
  }

  function open() {
    hoverTip = ""
    if (svc) {
      svc.requestRefreshProviders()
      if (!availableModels || Object.keys(availableModels).length === 0)
        svc.requestRefreshAvailableModels(false)
    }
    panelController.show()
  }
  function flushPendingContext() {
    if (!svc) return
    var noteVal = ctxNoteEdit.text.replace(/^\s+|\s+$/g, "")
    if (noteVal !== customContext.replace(/^\s+|\s+$/g, ""))
      svc.requestSetCustomContext(noteVal)
    var fileVal = ctxFileInput.text.replace(/^\s+|\s+$/g, "")
    if (fileVal !== contextFile.replace(/^\s+|\s+$/g, ""))
      svc.requestSetContextFile(fileVal)
  }

  function close() {
    flushPendingContext()
    hoverTip = ""
    editingVendor = ""
    optionsPage = false
    panelController.hide()
  }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }

  function triggerCapture() {
    close()
    if (svc) svc.requestCapture()
    else if (bar && typeof bar.run === "function")
      bar.run(Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.7eleven77.aeye/bin/aeye capture")
  }

  function triggerOpenHud() {
    close()
    if (svc) svc.requestOpenHud()
    else if (bar && typeof bar.run === "function")
      bar.run("omarchy-shell shell call io.github.7eleven77.aeye open '{}'")
  }

  readonly property var i18n: ({
    capture:       { en: "Capture Screenshot", no: "Ta skjermbilde", sv: "Ta skärmbild", da: "Tag skærmbillede", de: "Screenshot aufnehmen", fr: "Prendre une capture", es: "Capturar pantalla", pt: "Capturar tela", it: "Cattura schermo", pl: "Zrób zrzut ekranu", ja: "スクリーンショットを撮る", zh: "截取屏幕" },
    openAnswer:    { en: "View Answer", no: "Vis svar", sv: "Visa svar", da: "Vis svar", de: "Antwort ansehen", fr: "Voir la réponse", es: "Ver respuesta", pt: "Ver resposta", it: "Mostra risposta", pl: "Zobacz odpowiedź", ja: "回答を表示", zh: "查看回答" },
    openHud:       { en: "Open HUD", no: "Åpne HUD", sv: "Öppna HUD", da: "Åbn HUD", de: "HUD öffnen", fr: "Ouvrir le HUD", es: "Abrir HUD", pt: "Abrir HUD", it: "Apri HUD", pl: "Otwórz HUD", ja: "HUDを開く", zh: "打开界面" },
    modelSec:      { en: "AI Vision Model", no: "AI-modell", sv: "AI-modell", da: "AI-model", de: "KI-Modell", fr: "Modèle IA", es: "Modelo IA", pt: "Modelo IA", it: "Modello IA", pl: "Model AI", ja: "AIモデル", zh: "AI 视觉模型" },
    settingsSec:   { en: "Behavior & Settings", no: "Oppførsel & innstillinger", sv: "Inställningar", da: "Indstillinger", de: "Einstellungen", fr: "Paramètres", es: "Ajustes", pt: "Configurações", it: "Impostazioni", pl: "Ustawienia", ja: "動作と設定", zh: "行为与设置" },
    apiSec:        { en: "Providers & API Keys", no: "AI-tilbydere & API-nøkler", sv: "Leverantörer & API-nycklar", da: "Udbydere & API-nøgler", de: "Anbieter & API-Keys", fr: "Fournisseurs & clés API", es: "Proveedores y claves API", pt: "Provedores e chaves API", it: "Provider e chiavi API", pl: "Dostawcy i klucze API", ja: "プロバイダーとAPIキー", zh: "服务商与 API 密钥" },
    apiHint:       { en: "Uses Omarchy Agent auth automatically; set manual keys if missing.", no: "Bruker Omarchy-agenter automatisk; legg inn manuell nøkkel hvis den mangler.", sv: "Använder Omarchy-agenter automatiskt; ange manuell nyckel vid behov.", da: "Bruger Omarchy-agenter automatisk; angiv manuel nøgle hvis den mangler.", de: "Nutzt Omarchy-Agenten automatisch; manuelle Keys bei Bedarf setzen.", fr: "Utilise les agents Omarchy automatiquement ; clé manuelle si absente.", es: "Usa agentes de Omarchy automáticamente; añade clave manual si falta.", pt: "Usa agentes do Omarchy automaticamente; defina chave manual se faltar.", it: "Usa gli agenti Omarchy automaticamente; imposta chiave manuale se manca.", pl: "Używa agentów Omarchy automatycznie; wpisz klucz ręcznie jeśli brak.", ja: "Omarchyエージェント認証を自動利用（未設定時は手動キー入力）", zh: "自动使用 Omarchy 代理认证；缺失时可手动输入密钥" },
    keyPlaceholder:{ en: "Paste API key…", no: "Lim inn API-nøkkel…", sv: "Klistra in API-nyckel…", da: "Indsæt API-nøgle…", de: "API-Key einfügen…", fr: "Coller la clé API…", es: "Pegar clave API…", pt: "Colar chave API…", it: "Incolla chiave API…", pl: "Wklej klucz API…", ja: "APIキーを貼り付け…", zh: "粘贴 API 密钥…" },
    saveKey:       { en: "Save", no: "Lagre", sv: "Spara", da: "Gem", de: "Speichern", fr: "Enregistrer", es: "Guardar", pt: "Salvar", it: "Salva", pl: "Zapisz", ja: "保存", zh: "保存" },
    clearKey:      { en: "Clear", no: "Fjern", sv: "Rensa", da: "Ryd", de: "Löschen", fr: "Effacer", es: "Borrar", pt: "Limpar", it: "Rimuovi", pl: "Usuń", ja: "削除", zh: "清除" },
    setKey:        { en: "Set key", no: "Sett nøkkel", sv: "Ange nyckel", da: "Angiv nøgle", de: "Key setzen", fr: "Définir", es: "Configurar", pt: "Definir", it: "Imposta", pl: "Ustaw", ja: "設定", zh: "设置" },
    minSend:       { en: "Minimize on send", no: "Minimer ved sending", sv: "Minimera vid sändning", da: "Minimer ved afsendelse", de: "Beim Senden minimieren", fr: "Réduire à l'envoi", es: "Minimizar al enviar", pt: "Minimizar ao enviar", it: "Riduci all'invio", pl: "Minimalizuj po wysłaniu", ja: "送信時に最小化", zh: "发送后最小化" },
    minSendSub:    { en: "Hide HUD while thinking & notify when ready", no: "Skjul HUD under analyse og varsle når klar", sv: "Dölj HUD vid analys och avisera när klart", da: "Skjul HUD under analyse og giv besked", de: "HUD ausblenden & bei Antwort benachrichtigen", fr: "Masquer le HUD et notifier à la fin", es: "Ocultar HUD y notificar al terminar", pt: "Ocultar HUD e notificar quando pronto", it: "Nascondi HUD e notifica a risposta pronta", pl: "Ukryj HUD i powiadom po zakończeniu", ja: "解析中は最小化し完了時に通知", zh: "分析时隐藏窗口并在完成后通知" },
    autoScan:      { en: "Auto-analyze on capture", no: "Auto-analyser ved skjermbilde", sv: "Auto-analysera vid fångst", da: "Auto-analysér ved optagelse", de: "Sofort automatisch analysieren", fr: "Analyser auto à la capture", es: "Analizar automáticamente", pt: "Analisar automaticamente", it: "Analizza automaticamente", pl: "Analizuj automatycznie", ja: "撮影時に自動解析", zh: "截图后自动分析" },
    autoScanSub:   { en: "Summary + auto-generated questions (✦)", no: "Oppsummering + autogenererte spørsmål (✦)", sv: "Sammanfattning + autogenererade frågor (✦)", da: "Resumé + autogenererede spørgsmål (✦)", de: "Zusammenfassung + Rückfragen (✦)", fr: "Résumé + questions générées (✦)", es: "Resumen + preguntas sugeridas (✦)", pt: "Resumo + perguntas sugeridas (✦)", it: "Riassunto + domande suggerite (✦)", pl: "Podsumowanie + podpowiedzi pytań (✦)", ja: "要約＋追質問（✦）を自動生成", zh: "总结 + 自动生成追问（✦）" },
    sysDebug:      { en: "⚠ System Debug (opt-in)", no: "⚠ System Debug (valgfritt)", sv: "⚠ System Debug (valfritt)", da: "⚠ System Debug (valgfrit)", de: "⚠ System-Debug (Opt-in)", fr: "⚠ System Debug (opt-in)", es: "⚠ System Debug (opcional)", pt: "⚠ System Debug (opcional)", it: "⚠ System Debug (opzionale)", pl: "⚠ System Debug (opcja)", ja: "⚠ システムデバッグ（任意）", zh: "⚠ 系统调试（可选）" },
    sysDebugSub:   { en: "Attach read-only logs & system state", no: "Legg ved lesebeskyttet logg & systemstatus", sv: "Bifoga skrivskyddad logg & systemstatus", da: "Vedhæft skrivebeskyttet log & systemstatus", de: "Schreibgeschützte Logs & Systemstatus anhängen", fr: "Joindre journaux et état en lecture seule", es: "Adjuntar registros y estado de solo lectura", pt: "Anexar logs e estado somente leitura", it: "Allega log e stato di sola lettura", pl: "Dołącz logi i stan systemu (tylko odczyt)", ja: "読み取り専用ログとシステム状態を添付", zh: "附加只读系统日志与状态快照" },
    sysDebugWarn:  { en: "Read-only diagnostics (journalctl errors, Hyprland, memory/disk) are sent with your screenshot. No env vars, no keys, never runs commands automatically.", no: "Lesebeskyttet diagnostikk (journalctl-feil, Hyprland, minne/disk) legges ved skjermbildet. Ingen nøkler eller env-variabler — kjører aldri kommandoer automatisk.", sv: "Skrivskyddad diagnostik (journalctl-fel, Hyprland, minne/disk) bifogas. Inga nycklar eller env-variabler — kör aldrig kommandon automatiskt.", da: "Skrivebeskyttet diagnostik (journalctl-fejl, Hyprland, hukommelse/disk) vedhæftes. Ingen nøgler eller env-variabler — kører aldrig kommandoer automatisk.", de: "Nur-Lese-Diagnose (journalctl-Fehler, Hyprland, RAM/Disk) wird angehängt. Keine Keys/Env-Vars, führt nie Befehle automatisch aus.", fr: "Diagnostic en lecture seule (journalctl, Hyprland, RAM/disque) joint à la capture. Aucune clé/env, aucune exécution automatique.", es: "Diagnóstico de solo lectura (errores journalctl, Hyprland, RAM/disco) adjunto. Sin claves ni env, nunca ejecuta comandos.", pt: "Diagnóstico somente leitura (erros journalctl, Hyprland, RAM/disco) anexado. Sem chaves/env, nunca executa comandos.", it: "Diagnostica in sola lettura (errori journalctl, Hyprland, RAM/disco) allegata. Nessuna chiave/env, mai comandi automatici.", pl: "Diagnostyka tylko do odczytu (błędy journalctl, Hyprland, RAM/dysk). Bez kluczy/env, nigdy nie uruchamia poleceń automatycznie.", ja: "読み取り専用の診断情報（journalctlエラー、Hyprland、メモリ/ディスク）を添付します。キーや環境変数は含まず、自動実行もしません。", zh: "随截图附加只读诊断信息（journalctl 错误、Hyprland、内存/磁盘）。不包含密钥或环境变量，绝不自动执行命令。" },
    tipSysDebug:   { en: "Opt-in troubleshooting: attaches a bounded ~8 KB read-only snapshot (recent journalctl errors, Hyprland state, disk/RAM) so AI can diagnose real system issues. Unprivileged only, zero secrets, never executes commands.", no: "Valgfri feilsøking: legger ved et avgrenset ~8 KB read-only snapshot (siste journalctl-feil, Hyprland-status, disk/RAM) så AI finner ekte systemårsaker. Kun vanlig bruker, null hemmeligheter, kjører aldri kommandoer.", sv: "Valfri felsökning: bifogar en ~8 KB skrivskyddad ögonblicksbild (journalctl-fel, Hyprland, disk/RAM). Endast vanlig användare, inga hemligheter, kör aldrig kommandon.", da: "Valgfri fejlfinding: vedhæfter et ~8 KB skrivebeskyttet snapshot (journalctl-fejl, Hyprland, disk/RAM). Kun almindelig bruger, ingen hemmeligheder, kører aldrig kommandoer.", de: "Optionale Fehlersuche: hängt einen ~8 KB Nur-Lese-Snapshot an (journalctl, Hyprland, RAM/Disk). Ohne Root-Rechte, keine Geheimnisse, keine automatische Ausführung.", fr: "Dépannage opt-in : joint un instantané lecture seule (~8 Ko : journalctl, Hyprland, RAM/disque). Sans élévation de privilèges, sans secrets, sans exécution automatique.", es: "Diagnóstico opcional: adjunta una instantánea de solo lectura (~8 KB: journalctl, Hyprland, RAM/disco). Sin elevación de privilegios, sin secretos, sin ejecución automática.", pt: "Solução de problemas opcional: anexa um snapshot somente leitura (~8 KB: journalctl, Hyprland, RAM/disco). Sem elevação de privilégios, sem segredos, sem execução automática.", it: "Debug opzionale: allega uno snapshot in sola lettura (~8 KB: journalctl, Hyprland, RAM/disco). Senza privilegi elevati, zero segreti, nessuna esecuzione automatica.", pl: "Opcjonalna diagnostyka: dołącza migawkę tylko do odczytu (~8 KB: journalctl, Hyprland, RAM/dysk). Bez uprawnień administratora, bez sekretów, bez automatycznego uruchamiania.", ja: "任意のトラブルシューティング：約8KBの読み取り専用スナップショット（journalctl、Hyprland、メモリ/ディスク）を添付します。特権昇格・機密情報・自動実行なし。", zh: "可选故障排查：附加约 8 KB 只读快照（journalctl 错误、Hyprland、磁盘/内存）。无特权提升、无密钥、绝不自动执行命令。" },
    noActiveModels:{ en: "No active AI providers — click to add an API key below", no: "Ingen aktive AI-tilbydere — klikk for å legge inn API-nøkkel under", sv: "Inga aktiva AI-leverantörer — klicka för att lägga till API-nyckel", da: "Ingen aktive AI-udbydere — klik for at tilføje en API-nøgle", de: "Keine aktiven KI-Anbieter — klicken für API-Key-Setup", fr: "Aucun fournisseur IA actif — cliquez pour ajouter une clé API", es: "Sin proveedores de IA activos — haz clic para añadir una clave API", pt: "Nenhum provedor de IA ativo — clique para adicionar uma chave API", it: "Nessun provider IA attivo — clicca per aggiungere una chiave API", pl: "Brak aktywnych dostawców AI — kliknij, aby dodać klucz API", ja: "有効なAIプロバイダーなし — クリックしてAPIキーを設定", zh: "暂无已启用的 AI 服务商 — 点击下方配置 API 密钥" },
    stealth:       { en: "Stealth mode", no: "Stillemodus (Stealth)", sv: "Tyst läge (Stealth)", da: "Stilletilstand (Stealth)", de: "Still-Modus (Stealth)", fr: "Mode discret (Stealth)", es: "Modo sigilo (Stealth)", pt: "Modo discreto (Stealth)", it: "Modalità silenziosa", pl: "Tryb cichy (Stealth)", ja: "ステルスモード", zh: "静默模式" },
    modeQuick:     { en: "⚡ Auto-Analyze: ON", no: "⚡ Auto-analyse: PÅ", sv: "⚡ Auto-analys: PÅ", da: "⚡ Auto-analyse: TIL", de: "⚡ Auto-Analyse: AN", fr: "⚡ Auto-analyse : ON", es: "⚡ Auto-análisis: SÍ", pt: "⚡ Auto-análise: ON", it: "⚡ Auto-analisi: ON", pl: "⚡ Auto-analiza: WŁ", ja: "⚡ 自動解析: ON", zh: "⚡ 自动分析: 开" },
    modeHud:       { en: "✎ Manual Prompt", no: "✎ Manuell (vent på spørsmål)", sv: "✎ Manuell", da: "✎ Manuel", de: "✎ Manuell", fr: "✎ Manuel", es: "✎ Manual", pt: "✎ Manual", it: "✎ Manuale", pl: "✎ Ręcznie", ja: "✎ 手動質問", zh: "✎ 手动提问" },
    tipModeQuick:  { en: "Auto-Analyze ON: immediately analyzes new screenshots in 1–2s, auto-copies the first answer, and opens compact chat (expands automatically as you chat).", no: "Auto-analyse PÅ: analyserer skjermbildet med én gang på 1–2s, kopierer første svar automatisk og åpner kompakt chat (utvider seg når du chatter videre).", sv: "Auto-analys PÅ: analyserar skärmbilden direkt, kopierar svaret och öppnar kompakt chatt.", da: "Auto-analyse TIL: analyserer skærmbilledet med det samme, kopierer svaret og åbner kompakt chat.", de: "Auto-Analyse AN: analysiert neue Screenshots sofort, kopiert die erste Antwort und öffnet den kompakten Chat.", fr: "Auto-analyse ON : analyse immédiatement la capture, copie la réponse et ouvre le chat compact.", es: "Auto-análisis SÍ: analiza al instante, copia la primera respuesta y abre el chat compacto.", pt: "Auto-análise ON: analisa na hora, copia a primeira resposta e abre o chat compacto.", it: "Auto-analisi ON: analizza subito, copia la prima risposta e apre la chat compatta.", pl: "Auto-analiza WŁ: analizuje od razu, kopiuje odpowiedź i otwiera kompaktowy czat.", ja: "自動解析ON：撮影直後に解析して回答を自動コピーし、コンパクトチャットを開きます。", zh: "自动分析开启：截图后立即分析并自动复制首条回答，打开紧凑对话窗口。" },
    tipModeHud:    { en: "Manual Prompt mode: opens the screenshot preview first and waits for you to draw arrows/boxes/crop or type your own question before calling AI.", no: "Manuell modus: åpner skjermbildet først og venter til du tegner piler/bokser/utsnitt eller skriver spørsmålet ditt før AI kjører.", sv: "Manuellt läge: öppnar skärmbilden först och väntar på dina markeringar eller din fråga innan AI körs.", da: "Manuel tilstand: åbner skærmbilledet først og venter på dine markeringer eller dit spørgsmål.", de: "Manueller Modus: öffnet zuerst die Bildvorschau zum Zeichnen/Zuschneiden und wartet auf deine Frage.", fr: "Mode manuel : ouvre d'abord l'aperçu pour annoter/recadrer et attend votre question.", es: "Modo manual: abre primero la vista previa para anotar/recortar y espera tu pregunta.", pt: "Modo manual: abre primeiro a prévia para anotar/recortar e aguarda sua pergunta.", it: "Modalità manuale: apre prima l'anteprima per annotare/ritagliare e attende la tua domanda.", pl: "Tryb ręczny: otwiera najpierw podgląd do rysowania/przycinania i czeka na Twoje pytanie.", ja: "手動モード：まず画像プレビューを開き、矢印・切り抜きや質問の入力を待ってからAIを実行します。", zh: "手动模式：先打开截图预览供标注或裁剪，输入问题后再调用 AI。" },
    tipAuthToggle: { en: "Switch between CLI subscription auth (agy/claude/grok Pro) and API key for this model or provider", no: "Bytt mellom vanlig CLI-innlogging (agy/claude/grok Pro-abonnement) og API-nøkkel for denne modellen eller tilbyderen", sv: "Växla mellan CLI-inloggning (Pro-abonnemang) och API-nyckel", da: "Skift mellem CLI-login (Pro-abonnement) og API-nøgle", de: "Zwischen CLI-Abo-Login (agy/claude/grok Pro) und API-Key wechseln", fr: "Basculer entre l'authentification CLI (abonnement Pro) et la clé API", es: "Cambiar entre autenticación CLI (suscripción Pro) y clave API", pt: "Alternar entre autenticação CLI (assinatura Pro) e chave API", it: "Passa tra autenticazione CLI (abbonamento Pro) e chiave API", pl: "Przełącz między logowaniem CLI (subskrypcja Pro) a kluczem API", ja: "CLI認証（Proサブスクリプション）とAPIキーを切り替えます", zh: "在 CLI 订阅认证与 API 密钥之间切换" },
    reason:        { en: "Show visual reasoning", no: "Vis resonnering", sv: "Visa resonemang", da: "Vis ræsonnement", de: "Begründung anzeigen", fr: "Afficher le raisonnement", es: "Mostrar razonamiento", pt: "Mostrar raciocínio", it: "Mostra ragionamento", pl: "Pokaż tok myślenia", ja: "推論の根拠を表示", zh: "显示视觉推理" },
    language:      { en: "Language", no: "Språk", sv: "Språk", da: "Sprog", de: "Sprache", fr: "Langue", es: "Idioma", pt: "Idioma", it: "Lingua", pl: "Język", ja: "言語", zh: "语言" },
    pinnedSec:     { en: "Pinned Prompts", no: "Lagrede spørsmål", sv: "Fästa frågor", da: "Fastgjorte spørgsmål", de: "Gepinnte Prompts", fr: "Prompts épinglés", es: "Prompts fijados", pt: "Prompts fixados", it: "Prompt fissati", pl: "Przypięte pytania", ja: "ピン留めプロンプト", zh: "固定提示词" },
    addPromptHint: { en: "Add quick prompt…", no: "Legg til hurtigspørsmål…", sv: "Lägg till snabbfråga…", da: "Tilføj hurtigspørgsmål…", de: "Prompt hinzufügen…", fr: "Ajouter un prompt…", es: "Añadir prompt…", pt: "Adicionar prompt…", it: "Aggiungi prompt…", pl: "Dodaj pytanie…", ja: "クイック質問を追加…", zh: "添加快捷提示…" },
    scanning:      { en: "SCANNING…", no: "ANALYSERER…", sv: "ANALYSERAR…", da: "ANALYSERER…", de: "ANALYSIERT…", fr: "ANALYSE…", es: "ANALIZANDO…", pt: "ANALISANDO…", it: "ANALISI…", pl: "ANALIZA…", ja: "解析中…", zh: "分析中…" },
    paused:        { en: "PAUSED", no: "PAUSET", sv: "PAUSAD", da: "PAUSET", de: "PAUSIERT", fr: "EN PAUSE", es: "PAUSADO", pt: "PAUSADO", it: "IN PAUSA", pl: "WSTRZYMANO", ja: "一時停止", zh: "已暂停" },
    ready:         { en: "ANSWER READY", no: "SVAR KLART", sv: "SVAR KLART", da: "SVAR KLAR", de: "ANTWORT BEREIT", fr: "RÉPONSE PRÊTE", es: "RESPUESTA LISTA", pt: "RESPOSTA PRONTA", it: "RISPOSTA PRONTA", pl: "GOTOWE", ja: "回答完了", zh: "回答就绪" },
    idle:          { en: "READY", no: "KLAR", sv: "REDO", da: "KLAR", de: "BEREIT", fr: "PRÊT", es: "LISTO", pt: "PRONTO", it: "PRONTO", pl: "GOTOWY", ja: "待機中", zh: "就绪" },
    pause:         { en: "Pause", no: "Pause", sv: "Paus", da: "Pause", de: "Pause", fr: "Pause", es: "Pausa", pt: "Pausa", it: "Pausa", pl: "Pauza", ja: "停止", zh: "暂停" },
    resume:        { en: "Resume", no: "Fortsett", sv: "Fortsätt", da: "Fortsæt", de: "Weiter", fr: "Reprendre", es: "Reanudar", pt: "Retomar", it: "Riprendi", pl: "Wznów", ja: "再開", zh: "继续" },
    stop:          { en: "Stop", no: "Stopp", sv: "Stopp", da: "Stop", de: "Stopp", fr: "Arrêter", es: "Detener", pt: "Parar", it: "Ferma", pl: "Stop", ja: "中止", zh: "停止" },
    tipIdle:       { en: "Aeye — Left-click: Settings & Capture · Right-click: Screenshot", no: "Aeye — Venstreklikk: Innstillinger & skjermbilde · Høyreklikk: Ta skjermbilde", sv: "Aeye — Vänster: Inställningar · Höger: Ta skärmbild", da: "Aeye — Venstre: Indstillinger · Højre: Tag skærmbillede", de: "Aeye — Links: Einstellungen · Rechts: Screenshot", fr: "Aeye — Clic gauche : Paramètres · Clic droit : Capture", es: "Aeye — Clic izq.: Ajustes · Clic der.: Captura", pt: "Aeye — Clique esq.: Config · Clique dir.: Captura", it: "Aeye — Sinistro: Impostazioni · Destro: Cattura", pl: "Aeye — LPM: Ustawienia · PPM: Zrzut ekranu", ja: "Aeye — 左クリック: 設定 · 右クリック: 撮影", zh: "Aeye — 左键: 设置 · 右键: 截图" },
    tipScanning:   { en: "Aeye — Analyzing screenshot… Click to open", no: "Aeye — Analyserer skjermbilde… Klikk for å åpne", sv: "Aeye — Analyserar skärmbild… Klicka för att öppna", da: "Aeye — Analyserer skærmbillede… Klik for at åbne", de: "Aeye — Analysiert Screenshot… Klicken zum Öffnen", fr: "Aeye — Analyse en cours… Cliquer pour ouvrir", es: "Aeye — Analizando captura… Clic para abrir", pt: "Aeye — Analisando captura… Clique para abrir", it: "Aeye — Analisi in corso… Clicca per aprire", pl: "Aeye — Analizowanie… Kliknij, aby otworzyć", ja: "Aeye — 解析中… クリックして開く", zh: "Aeye — 正在分析… 点击打开" },
    tipReady:      { en: "Aeye — Answer ready! Click to view", no: "Aeye — Svar klart! Klikk for å vise", sv: "Aeye — Svar klart! Klicka för att visa", da: "Aeye — Svar klar! Klik for at vise", de: "Aeye — Antwort bereit! Klicken zum Ansehen", fr: "Aeye — Réponse prête ! Cliquer pour voir", es: "Aeye — ¡Respuesta lista! Clic para ver", pt: "Aeye — Resposta pronta! Clique para ver", it: "Aeye — Risposta pronta! Clicca per vedere", pl: "Aeye — Odpowiedź gotowa! Kliknij, aby zobaczyć", ja: "Aeye — 回答完了！クリックして表示", zh: "Aeye — 回答已就绪！点击查看" },
    hoverDefault:  { en: "Hover any option for details · Right-click bar eye to capture", no: "Hold musen over et valg for forklaring · Høyreklikk øyet for skjermbilde", sv: "Hovra för detaljer · Högerklicka ögat för skärmbild", da: "Hold musen over for detaljer · Højreklik øjet for skærmbillede", de: "Über Optionen fahren für Details · Rechtsklick für Screenshot", fr: "Survolez pour les détails · Clic droit sur l'œil pour capturer", es: "Pasa el cursor para detalles · Clic derecho en el ojo para capturar", pt: "Passe o cursor para detalhes · Clique direito no olho para capturar", it: "Passa il mouse per i dettagli · Tasto destro sull'occhio per catturare", pl: "Najedź po szczegóły · PPM na oko aby zrobić zrzut", ja: "各項目にホバーで説明表示 · 右クリックで即キャプチャ", zh: "悬停查看详情 · 右键顶栏图标快速截图" },
    tipCaptureBtn: { en: "Select a screen region to open in Aeye (Super+Shift+Print)", no: "Merk et område på skjermen for å åpne i Aeye (Super+Shift+Print)", sv: "Markera ett skärmområde att öppna i Aeye (Super+Shift+Print)", da: "Vælg et område på skærmen til Aeye (Super+Shift+Print)", de: "Bildschirmbereich für Aeye auswählen (Super+Shift+Print)", fr: "Sélectionner une zone à ouvrir dans Aeye (Super+Shift+Print)", es: "Seleccionar una región para abrir en Aeye (Super+Shift+Print)", pt: "Selecionar área da tela para abrir no Aeye (Super+Shift+Print)", it: "Seleziona una regione dello schermo per Aeye (Super+Shift+Print)", pl: "Zaznacz obszar ekranu dla Aeye (Super+Shift+Print)", ja: "画面領域を選択してAeyeで開く（Super+Shift+Print）", zh: "框选屏幕区域并在 Aeye 中打开（Super+Shift+Print）" },
    tipOpenBtn:    { en: "Re-open the Aeye HUD with your latest screenshot and answer", no: "Åpne Aeye-vinduet igjen med siste skjermbilde og svar", sv: "Öppna Aeye-fönstret med senaste bild och svar", da: "Åbn Aeye-vinduet med dit seneste billede og svar", de: "Aeye-HUD mit letztem Screenshot und Antwort wieder öffnen", fr: "Rouvrir le HUD Aeye avec la dernière capture et réponse", es: "Reabrir el HUD de Aeye con tu última captura y respuesta", pt: "Reabrir o HUD do Aeye com a última captura e resposta", it: "Riapri il HUD di Aeye con l'ultimo screenshot e risposta", pl: "Otwórz ponownie HUD Aeye z ostatnim zrzutem i odpowiedzią", ja: "最新のスクリーンショットと回答でHUDを再度開く", zh: "重新打开包含最新截图和回答的 HUD" },
    tipPauseBtn:   { en: "Pause or resume the active background AI scan", no: "Sett pågående bakgrunnsanalyse på pause eller fortsett", sv: "Pausa eller återuppta pågående bakgrundsanalys", da: "Sæt baggrundsanalysen på pause eller genoptag", de: "Laufende Hintergrundanalyse pausieren oder fortsetzen", fr: "Mettre en pause ou reprendre l'analyse en arrière-plan", es: "Pausar o reanudar el análisis en segundo plano", pt: "Pausar ou retomar a análise em segundo plano", it: "Metti in pausa o riprendi l'analisi in background", pl: "Wstrzymaj lub wznów analizę w tle", ja: "バックグラウンド解析を一時停止/再開", zh: "暂停或继续后台分析" },
    tipStopBtn:    { en: "Cancel the active AI request immediately", no: "Avbryt pågående AI-forespørsel umiddelbart", sv: "Avbryt pågående AI-förfrågan direkt", da: "Annuller den igangværende AI-forespørgsel", de: "Laufende KI-Anfrage sofort abbrechen", fr: "Annuler la requête IA en cours", es: "Cancelar la solicitud de IA inmediatamente", pt: "Cancelar a solicitação de IA imediatamente", it: "Annulla immediatamente la richiesta IA", pl: "Natychmiast anuluj bieżące zapytanie AI", ja: "実行中のAIリクエストを中止", zh: "立即取消当前 AI 请求" },
    tipFlash:      { en: "Gemini Flash (OCR & Quick) — fastest pick for reading text (OCR), translations, quick summaries & everyday UI questions.", no: "Gemini Flash (OCR & Rask) — best for lynrask tekstuthenting (OCR), oversettelse, korte oppsummeringer og enkle UI-spørsmål.", sv: "Gemini Flash (OCR & Snabb) — bäst för snabb textutläsning (OCR), översättning, korta sammanfattningar och vardagsfrågor.", da: "Gemini Flash (OCR & Hurtig) — bedst til lynhurtig OCR, oversættelse, korte resuméer og hurtige UI-spørgsmål.", de: "Gemini Flash (OCR & Schnell) — ideal für Textauslesung (OCR), Übersetzungen, kurze Zusammenfassungen & Alltagsfragen.", fr: "Gemini Flash (OCR & Rapide) — idéal pour extraire du texte (OCR), traduire, résumer vite et répondre aux questions UI.", es: "Gemini Flash (OCR y Rápido) — ideal para extraer texto (OCR), traducciones, resúmenes rápidos y consultas diarias.", pt: "Gemini Flash (OCR e Rápido) — ótimo para extrair texto (OCR), traduções, resumos rápidos e dúvidas do dia a dia.", it: "Gemini Flash (OCR e Veloce) — ideale per estrarre testo (OCR), traduzioni, riassunti rapidi e domande quotidiane.", pl: "Gemini Flash (OCR i Szybki) — najlepszy do szybkiego odczytu tekstu (OCR), tłumaczeń i krótkich podsumowań.", ja: "Gemini Flash（OCR・高速）— テキスト抽出（OCR）、翻訳、要約、日常のUI確認に最適です。", zh: "Gemini Flash（OCR 与快速）— 最适合快速提取文字（OCR）、翻译、摘要及日常界面问题。" },
    tipArgon:      { en: "Gemini Argon (Deep Logic) — best for dense charts, architecture diagrams, long docs, comparisons & complex reasoning.", no: "Gemini Argon (Dyp analyse) — best for komplekse grafer, arkitekturdiagrammer, lange tekster, sammenligninger og grundig resonnering.", sv: "Gemini Argon (Djup analys) — bäst för komplexa grafer, arkitekturdiagram, långa dokument och svåra jämförelser.", da: "Gemini Argon (Dyb analyse) — bedst til komplekse grafer, arkitekturdiagrammer, lange dokumenter og grundige sammenligninger.", de: "Gemini Argon (Tiefe Logik) — optimal für komplexe Diagramme, Architekturpläne, lange Dokumente & gründliche Vergleiche.", fr: "Gemini Argon (Analyse profonde) — idéal pour graphiques complexes, schémas d'architecture, longs documents et comparaisons.", es: "Gemini Argon (Análisis profundo) — ideal para gráficos complejos, diagramas, documentos largos y razonamiento detallado.", pt: "Gemini Argon (Análise profunda) — ótimo para gráficos complejos, diagramas de arquitetura, documentos longos e comparações.", it: "Gemini Argon (Analisi profonda) — ideale per grafici complessi, diagrammi, documenti lunghi e ragionamenti approfonditi.", pl: "Gemini Argon (Głęboka analiza) — najlepszy do złożonych wykresów, diagramów architektury, długich dokumentów i porównań.", ja: "Gemini Argon（深い推論）— 複雑なグラフ、構成図、長文ドキュメントの比較や深い分析に最適です。", zh: "Gemini Argon（深度推理）— 最适合复杂图表、架构图、长文档分析与深度对比。" },
    tipSonnet:     { en: "Claude Sonnet 5.5 (Code & Text) — best for code debugging, stacktraces, logs, refactoring, grammar review & polished writing.", no: "Claude Sonnet 5.5 (Kode & Tekst) — best for koding, debugging av feilmeldinger/logger, refaktorering, grammatikk og god tekstskriving.", sv: "Claude Sonnet 5.5 (Kod & Text) — bäst för kod, felsökning av loggar/stacktraces, refaktorering, grammatik och skrivande.", da: "Claude Sonnet 5.5 (Kode & Tekst) — bedst til kodning, fejlfinding af logs/stacktraces, grammatik og velformuleret tekst.", de: "Claude Sonnet 5.5 (Code & Text) — top für Code, Stacktraces, Logs, Refactoring, Grammatikprüfung & präzises Schreiben.", fr: "Claude Sonnet 5.5 (Code & Texte) — top pour le code, bugs, logs, grammaire et rédaction soignée.", es: "Claude Sonnet 5.5 (Código y Texto) — ideal para código, depuración, logs, gramática y redacción cuidada.", pt: "Claude Sonnet 5.5 (Código e Texto) — ótimo para código, depuração, logs, revisão gramatical e escrita clara.", it: "Claude Sonnet 5.5 (Codice e Testo) — top per codice, debug, log, grammatica e scrittura curata.", pl: "Claude Sonnet 5.5 (Kod i Tekst) — świetny do kodu, debugowania logów, refaktoryzacji, gramatyki i pisania.", ja: "Claude Sonnet 5.5（コード・文章）— コード解析、エラーログ修正、文法チェック、自然な文章作成に最適です。", zh: "Claude Sonnet 5.5（代码与写作）— 最擅长代码调试、报错日志分析、语法检查与润色写作。" },
    tipGrok:       { en: "Grok 4.7 (Realtime & Tech) — best for fresh/current topics, brand-new tool errors, blunt answers & quick tech sanity checks.", no: "Grok 4.7 (Sanntid & Rett på sak) — best for ferske nyheter/hendelser, feil i helt nye verktøy, direkte svar og raske tek-sjekker.", sv: "Grok 4.7 (Realtid & Direkt) — bäst för färska nyheter, nya verktygsfel, raka svar och snabba tekniska kontroller.", da: "Grok 4.7 (Realtid & Direkte) — bedst til aktuelle emner, helt nye fejlmeddelelser og kontante tekniske svar.", de: "Grok 4.7 (Echtzeit & Direkt) — ideal für aktuelle Themen, Fehler neuer Tools und direkte, schnörkellose Antworten.", fr: "Grok 4.7 (Temps réel & Direct) — idéal pour l'actualité récente, erreurs d'outils récents et réponses directes.", es: "Grok 4.7 (Tiempo real y Directo) — ideal para temas actuales, errores recientes y respuestas directas sin rodeos.", pt: "Grok 4.7 (Tempo real e Direto) — ótimo para novidades recentes, erros de ferramentas novas e respostas diretas.", it: "Grok 4.7 (Tempo reale e Diretto) — ideale per notizie recenti, errori di nuovi tool e risposte dirette.", pl: "Grok 4.7 (Na żywo i Konkret) — najlepszy do świeżych tematów, nowych błędów narzędzi i zwięzłych odpowiedzi.", ja: "Grok 4.7（最新情報・率直）— 最新トピック、新しいツールのエラー、簡潔で率直な技術チェックに最適です。", zh: "Grok 4.7（实时与直率）— 最适合最新资讯、新工具报错以及直截了当的技术检查。" },
    tipOpenai:     { en: "GPT-4o (UI & General) — strong all-rounder for UI/UX feedback, structured tables/JSON extraction & creative copy.", no: "GPT-4o (UI & Allround) — sterk allrounder for UI/UX-tilbakemeldinger, uthenting av tabeller/JSON og kreativ tekst.", sv: "GPT-4o (UI & Allround) — stark allroundmodell för UI/UX-feedback, tabeller/JSON och kreativ text.", da: "GPT-4o (UI & Allround) — stærk allrounder til UI/UX-feedback, tabeller/JSON og kreativ tekst.", de: "GPT-4o (UI & Allround) — starker Allrounder für UI/UX-Feedback, strukturierte Tabellen/JSON & kreative Texte.", fr: "GPT-4o (UI & Polyvalent) — très polyvalent pour l'UI/UX, l'extraction de tableaux/JSON et le texte créatif.", es: "GPT-4o (UI y General) — todoterreno ideal para feedback UI/UX, tablas/JSON y textos creativos.", pt: "GPT-4o (UI e Geral) — versátil para feedback de UI/UX, extração de tabelas/JSON e texto criativo.", it: "GPT-4o (UI e Generale) — versatile per feedback UI/UX, estrazione di tabelle/JSON e testi creativi.", pl: "GPT-4o (UI i Uniwersalny) — wszechstronny do uwag UI/UX, tabel/JSON oraz kreatywnych tekstów.", ja: "GPT-4o（UI・万能）— UI/UXレビュー、表・JSON抽出、クリエイティブな文章まで幅広く対応します。", zh: "GPT-4o（UI 与全能）— 擅长 UI/UX 反馈、表格/JSON 结构化提取和通用视觉理解。" },
    tipMinSend:    { en: "Automatically hide HUD when you press Enter and notify when the answer is ready", no: "Skjuler HUD-en automatisk når du trykker Enter og varsler når svaret er klart", sv: "Döljer HUD vid Enter och skickar notis när svaret är klart", da: "Skjuler HUD ved Enter og giver besked når svaret er klar", de: "Minimiert HUD beim Senden und benachrichtigt bei fertiger Antwort", fr: "Réduit le HUD à l'envoi et notifie dès que la réponse est prête", es: "Oculta el HUD al enviar y notifica cuando la respuesta está lista", pt: "Oculta o HUD ao enviar e notifica quando a resposta ficar pronta", it: "Nasconde il HUD all'invio e notifica quando la risposta è pronta", pl: "Ukrywa HUD po wysłaniu i powiadamia, gdy odpowiedź jest gotowa", ja: "Enter送信時にHUDを最小化し、回答完了時に通知します", zh: "按 Enter 后自动隐藏窗口，完成后发送通知" },
    tipAutoScan:   { en: "Recommended for quick lookups: analyzes immediately on capture, auto-generates 3 clickable follow-up questions (✦), and suggests switching to the best active AI model for code, grammar, charts or realtime info.", no: "Smart for rask hjelp: analyserer bildet med én gang, autogenererer 3 klikkbare oppfølgingsspørsmål (✦) og tipser om å bytte til best egnet aktiv AI-modell for kode, grammatikk, grafer eller sanntidsinfo.", sv: "Smart för snabb hjälp: analyserar direkt vid fångst, autogenererar 3 klickbara följdfrågor (✦) och tipsar om bästa aktiva AI-modell för kod, grammatik, grafer eller realtidsinfo.", da: "Smart til hurtig hjælp: analyserer med det samme, autogenererer 3 klikbare spørgsmål (✦) og foreslår den bedste aktive AI-model til kode, grammatik, grafer eller realtidsinfo.", de: "Empfohlen für schnelle Hilfe: analysiert sofort, generiert 3 klickbare Rückfragen (✦) und schlägt das beste aktive KI-Modell für Code, Grammatik, Diagramme oder Echtzeitinfos vor.", fr: "Idéal pour aller vite : analyse dès la capture, génère 3 questions (✦) et suggère le meilleur modèle IA actif pour le code, la grammaire, les graphiques ou l'actualité.", es: "Ideal para consultas rápidas: analiza al instante, genera 3 preguntas clicables (✦) y sugiere el mejor modelo IA activo para código, gramática, gráficos o info actual.", pt: "Ótimo para agilidade: analisa na hora, gera 3 perguntas clicáveis (✦) e sugere o melhor modelo de IA ativo para código, gramática, gráficos ou informações recentes.", it: "Consigliato per risposte rapide: analizza subito, genera 3 domande cliccabili (✦) e suggerisce il miglior modello IA attivo per codice, grammatica, grafici o news.", pl: "Polecane do szybkiej pracy: analizuje od razu, generuje 3 klikalne pytania (✦) i podpowiada najlepszy aktywny model AI dla kodu, gramatyki, wykresów lub bieżących danych.", ja: "素早い確認に便利：撮影直後に要約と3つの追質問（✦）を自動生成し、コード・文法・図表・最新情報に応じて最適な有効モデルを提案します。", zh: "适合快速查看：截图后立即总结并生成 3 个可点击追问（✦），同时根据代码、语法、图表或实时信息推荐最合适的已启用模型。" },
    tipStealth:    { en: "Skip opening HUD completely — analyze silently and show result in a notification", no: "Åpner ikke HUD-en — analyserer stille i bakgrunnen og viser svaret i en varsling", sv: "Hoppar över HUD — analyserar tyst och visar svaret i en notis", da: "Springer HUD over — analyserer stille og viser svaret som notifikation", de: "Öffnet kein HUD — analysiert leise und zeigt das Ergebnis als Benachrichtigung", fr: "N'ouvre pas le HUD — analyse silencieuse avec notification", es: "No abre el HUD — analiza en silencio y muestra una notificación", pt: "Não abre o HUD — analisa em silêncio e exibe uma notificação", it: "Non apre il HUD — analizza in silenzio e mostra una notifica", pl: "Nie otwiera HUD — analizuje w tle i pokazuje wynik w powiadomieniu", ja: "HUDを開かずバックグラウンド解析し通知で結果を表示", zh: "不弹出窗口，后台静默分析并通过通知显示结果" },
    tipReason:     { en: "Ask the model to cite which visual detail in the image drives its answer", no: "Ber modellen oppgi hvilken detalj i bildet svaret bygger på", sv: "Ber modellen förklara vilken detalj i bilden svaret bygger på", da: "Beder modellen forklare hvilken detalje i billedet svaret bygger på", de: "Modell nennt zuerst das ausschlaggebende Bilddetail vor der Antwort", fr: "Demande au modèle d'indiquer quel détail visuel motive sa réponse", es: "Pide al modelo indicar qué detalle visual respalda su respuesta", pt: "Pede ao modelo para explicar qual detalhe visual motiva a resposta", it: "Chiede al modello quale dettaglio visivo guida la risposta", pl: "Prosi model o wskazanie szczegółu obrazu będącego podstawą odpowiedzi", ja: "回答の根拠となった画像上の箇所を最初に1行で示します", zh: "让模型先说明回答所依据的图像细节" },
    tipLang:       { en: "Left-click: next language · Right-click: previous (applies to UI & AI replies)", no: "Venstreklikk: neste språk · Høyreklikk: forrige (gjelder både UI og AI-svar)", sv: "Vänster: nästa språk · Höger: föregående (gäller UI & AI-svar)", da: "Venstre: næste sprog · Højre: forrige (gælder UI & AI-svar)", de: "Links: nächste Sprache · Rechts: vorherige (für UI & KI-Antworten)", fr: "Clic gauche : langue suivante · Clic droit : précédente (UI & IA)", es: "Clic izq.: siguiente idioma · Clic der.: anterior (UI e IA)", pt: "Clique esq.: próximo idioma · Clique dir.: anterior (UI e IA)", it: "Sinistro: lingua successiva · Destro: precedente (UI e IA)", pl: "LPM: następny język · PPM: poprzedni (UI i odpowiedzi AI)", ja: "左クリック: 次の言語 · 右クリック: 前の言語（UIとAI回答）", zh: "左键切换下一个语言 · 右键上一个（同时应用于界面和 AI 回复）" },
    tipApiSec:     { en: "Check Omarchy agent auth or set manual API keys (saved chmod 600)", no: "Se status for Omarchy-agenter eller legg inn egne API-nøkler (lagres chmod 600)", sv: "Kontrollera Omarchy-agenter eller ange manuella API-nycklar (chmod 600)", da: "Tjek Omarchy-agenter eller angiv manuelle API-nøgler (gemmes chmod 600)", de: "Omarchy-Agenten prüfen oder manuelle API-Keys setzen (chmod 600)", fr: "Vérifier les agents Omarchy ou définir des clés API manuelles (chmod 600)", es: "Comprobar agentes de Omarchy o definir claves API manuales (chmod 600)", pt: "Verificar agentes Omarchy ou definir chaves API manuais (chmod 600)", it: "Controlla gli agenti Omarchy o imposta chiavi API manuali (chmod 600)", pl: "Sprawdź agentów Omarchy lub ustaw ręczne klucze API (chmod 600)", ja: "Omarchyエージェント認証の確認と手動APIキー設定（chmod 600保存）", zh: "查看 Omarchy 代理认证状态或手动配置 API 密钥（chmod 600 保护）" },
    tipProviderRow:{ en: "Click to set or update a manual API key for this provider", no: "Klikk for å legge inn eller oppdatere manuell API-nøkkel for denne tilbyderen", sv: "Klicka för att ange eller uppdatera manuell API-nyckel", da: "Klik for at angive eller opdatere manuel API-nøgle", de: "Klicken, um einen manuellen API-Key für diesen Anbieter zu setzen", fr: "Cliquez pour définir ou modifier la clé API manuelle", es: "Haz clic para configurar o actualizar una clave API manual", pt: "Clique para definir ou atualizar a chave API manual", it: "Clicca per impostare o aggiornare una chiave API manuale", pl: "Kliknij, aby ustawić lub zmienić ręczny klucz API", ja: "クリックしてこのプロバイダーの手動APIキーを設定/更新", zh: "点击为此服务商设置或更新手动 API 密钥" },
    tipPinAdd:     { en: "Type a favorite question and press Enter or + to pin it as a quick button", no: "Skriv et favorittspørsmål og trykk Enter eller + for å lagre hurtigknapp", sv: "Skriv en fråga och tryck Enter eller + för att fästa som snabbknapp", da: "Skriv et spørgsmål og tryk Enter eller + for at gemme som genvej", de: "Frage eingeben und Enter oder + drücken, um sie anzupinnen", fr: "Saisissez une question et appuyez sur Entrée ou + pour l'épingler", es: "Escribe una pregunta y pulsa Enter o + para fijarla", pt: "Digite uma pergunta e pressione Enter ou + para fixar", it: "Scrivi una domanda e premi Invio o + per fissarla", pl: "Wpisz pytanie i naciśnij Enter lub +, aby przypiąć przycisk", ja: "よく使う質問を入力し Enter または + でクイックボタンに追加", zh: "输入常用问题并按 Enter 或 + 保存为快捷按钮" },
    tipPinDel:     { en: "Click × to remove this pinned prompt", no: "Klikk × for å slette dette lagrede spørsmålet", sv: "Klicka × för att ta bort frågan", da: "Klik × for at slette dette gemte spørgsmål", de: "Auf × klicken, um diesen Prompt zu entfernen", fr: "Cliquez sur × pour supprimer ce prompt", es: "Haz clic en × para eliminar este prompt", pt: "Clique em × para remover este prompt", it: "Clicca × per rimuovere questo prompt", pl: "Kliknij ×, aby usunąć to przypięte pytanie", ja: "× をクリックしてこのプロンプトを削除", zh: "点击 × 删除此固定提示" },
    hudPos:        { en: "HUD Placement", no: "HUD-plassering", sv: "HUD-placering", da: "HUD-placering", de: "HUD-Position", fr: "Position du HUD", es: "Posición del HUD", pt: "Posição do HUD", it: "Posizione HUD", pl: "Położenie HUD", ja: "HUD配置", zh: "HUD 位置" },
    posBottom:     { en: "Bottom", no: "Bunn", sv: "Botten", da: "Bund", de: "Unten", fr: "Bas", es: "Abajo", pt: "Base", it: "Basso", pl: "Dół", ja: "下", zh: "底部" },
    posTop:        { en: "Top", no: "Topp", sv: "Topp", da: "Top", de: "Oben", fr: "Haut", es: "Arriba", pt: "Topo", it: "Alto", pl: "Góra", ja: "上", zh: "顶部" },
    posCorner:     { en: "Corner", no: "Hjørne", sv: "Hörn", da: "Hjørne", de: "Ecke", fr: "Coin", es: "Esquina", pt: "Canto", it: "Angolo", pl: "Róg", ja: "右下", zh: "角落" },
    posTileLeft:   { en: "Tile L", no: "Tile V", sv: "Tile V", da: "Tile V", de: "Tile L", fr: "Tile G", es: "Tile I", pt: "Tile E", it: "Tile S", pl: "Tile L", ja: "左タイル", zh: "左平铺" },
    posTileRight:  { en: "Tile R", no: "Tile H", sv: "Tile H", da: "Tile H", de: "Tile R", fr: "Tile D", es: "Tile D", pt: "Tile D", it: "Tile D", pl: "Tile P", ja: "右タイル", zh: "右平铺" },
    tipPosFloat:   { en: "Floating HUD (click-through outside card + drag header freely anywhere on screen)", no: "Flytende HUD (klikk rett gjennom utenfor vinduet + dra topplinjen fritt hvor du vil på skjermen)", sv: "Flytande HUD (klicka utanför för andra appar + dra rubriken fritt)", da: "Flydende HUD (klik udenfor for andre apps + træk toppen frit)", de: "Schwebendes HUD (Klicks außerhalb gehen durch + Leiste frei verschiebbar)", fr: "HUD flottant (clics libres hors du HUD + déplaçable par l'en-tête)", es: "HUD flotante (clics libres fuera + arrastra la barra donde quieras)", pt: "HUD flutuante (cliques livres fora + arraste o topo livremente)", it: "HUD flottante (clic liberi fuori + trascinabile dall'intestazione)", pl: "Pływający HUD (klikanie poza oknem działa + dowolne przesuwanie)", ja: "フローティングHUD（外側クリック透過＋ヘッダーを自由にドラッグ可能）", zh: "悬浮 HUD（窗口外可自由点击其他应用 + 拖动顶部自由移动）" },
    tipPosTile:    { en: "Hyprland Tiled Sidebar — reserves screen space so your tiled windows resize neatly alongside Aeye with zero overlap", no: "Hyprland Tiled sidepanel — reserverer plass i flisleggingen så vinduene dine automatisk tilpasser seg ved siden av Aeye uten overlapp", sv: "Hyprland Tiled sidopanel — reserverar utrymme så dina fönster flisas snyggt bredvid Aeye", da: "Hyprland Tiled sidepanel — reserverer plads så dine vinduer tiles pænt ved siden af Aeye", de: "Hyprland Tiled Sidebar — reserviert Platz im Tiling-Layout ohne Überlappung", fr: "Panneau latéral Hyprland Tiled — réserve l'espace pour vos fenêtres sans chevauchement", es: "Panel lateral Hyprland Tiled — reserva espacio para que tus ventanas se ajusten junto a Aeye", pt: "Barra lateral Hyprland Tiled — reserva espaço para suas janelas sem sobreposição", it: "Barra laterale Hyprland Tiled — riserva spazio alle finestre senza sovrapposizioni", pl: "Panel boczny Hyprland Tiled — rezerwuje miejsce w układzie okien bez nakładania", ja: "Hyprlandタイル用サイドバー — 領域を確保し他ウィンドウと重ならず並列表示します", zh: "Hyprland 平铺侧边栏 — 自动预留屏幕空间，与平铺窗口并排显示不遮挡" },
    options:       { en: "Options", no: "Valg", sv: "Alternativ", da: "Valg", de: "Optionen", fr: "Options", es: "Opciones", pt: "Opções", it: "Opzioni", pl: "Opcje", ja: "設定", zh: "选项" },
    tipOptions:    { en: "Behavior toggles, HUD placement, AI context, API keys & pinned prompts", no: "Oppførsel, HUD-plassering, AI-kontekst, API-nøkler og lagrede spørsmål", sv: "Inställningar, HUD-placering, AI-kontext, API-nycklar och fästa frågor", da: "Indstillinger, HUD-placering, AI-kontekst, API-nøgler og fastgjorte spørgsmål", de: "Verhalten, HUD-Position, KI-Kontext, API-Keys & gepinnte Prompts", fr: "Options, position du HUD, contexte IA, clés API et prompts épinglés", es: "Opciones, posición del HUD, contexto IA, claves API y prompts fijados", pt: "Opções, posição do HUD, contexto IA, chaves API e prompts fixados", it: "Opzioni, posizione HUD, contesto IA, chiavi API e prompt fissati", pl: "Opcje, położenie HUD, kontekst AI, klucze API i przypięte pytania", ja: "動作設定・HUD配置・AIコンテキスト・APIキー・ピン留めプロンプト", zh: "行为设置、HUD 位置、AI 上下文、API 密钥和固定提示" },
    tipOptionsBack:{ en: "Back to quick capture & AI models", no: "Tilbake til skjermbilde og AI-modeller", sv: "Tillbaka till skärmbild och AI-modeller", da: "Tilbage til skærmbillede og AI-modeller", de: "Zurück zu Aufnahme & KI-Modellen", fr: "Retour à la capture et aux modèles IA", es: "Volver a captura y modelos IA", pt: "Voltar para captura e modelos IA", it: "Torna a cattura e modelli IA", pl: "Powrót do zrzutu i modeli AI", ja: "撮影とAIモデル選択に戻る", zh: "返回截图与 AI 模型" },
    contextSec:    { en: "AI Context & .md", no: "AI-kontekst & .md", sv: "AI-kontext & .md", da: "AI-kontekst & .md", de: "KI-Kontext & .md", fr: "Contexte IA & .md", es: "Contexto IA y .md", pt: "Contexto IA e .md", it: "Contesto IA e .md", pl: "Kontekst AI i .md", ja: "AIコンテキスト & .md", zh: "AI 上下文与 .md" },
    contextNoteLbl:{ en: "Comment / instructions for AI", no: "Kommentar / instruksjoner til AI", sv: "Kommentar / instruktioner till AI", da: "Kommentar / instruktioner til AI", de: "Kommentar / Anweisungen für KI", fr: "Note / instructions pour l'IA", es: "Nota / instrucciones para la IA", pt: "Nota / instruções para a IA", it: "Nota / istruzioni per l'IA", pl: "Komentarz / instrukcje dla AI", ja: "AIへのメモ・指示", zh: "给 AI 的备注 / 指令" },
    contextNoteHint:{ en: "Write notes or rules the AI should consider on every screenshot…", no: "Skriv kommentarer eller regler AI-en skal ta hensyn til…", sv: "Skriv anteckningar eller regler som AI:n ska ta hänsyn till…", da: "Skriv noter eller regler som AI'en skal tage hensyn til…", de: "Notizen oder Regeln, die die KI berücksichtigen soll…", fr: "Écrivez des notes ou règles que l'IA doit prendre en compte…", es: "Escribe notas o reglas que la IA deba tener en cuenta…", pt: "Escreva notas ou regras que a IA deve considerar…", it: "Scrivi note o regole che l'IA deve considerare…", pl: "Wpisz uwagi lub zasady, które AI ma uwzględniać…", ja: "AIに常に考慮してほしいメモやルールを入力…", zh: "输入希望 AI 在分析截图时参考的备注或规则…" },
    contextFileLbl:{ en: "Markdown (.md) file", no: "Markdown (.md)-fil", sv: "Markdown (.md)-fil", da: "Markdown (.md)-fil", de: "Markdown (.md)-Datei", fr: "Fichier Markdown (.md)", es: "Archivo Markdown (.md)", pt: "Arquivo Markdown (.md)", it: "File Markdown (.md)", pl: "Plik Markdown (.md)", ja: "Markdown (.md) ファイル", zh: "Markdown (.md) 文件" },
    contextFileHint:{ en: "~/Documents/aeye-context.md", no: "~/Documents/aeye-context.md", sv: "~/Documents/aeye-context.md", da: "~/Documents/aeye-context.md", de: "~/Documents/aeye-context.md", fr: "~/Documents/aeye-context.md", es: "~/Documents/aeye-context.md", pt: "~/Documents/aeye-context.md", it: "~/Documents/aeye-context.md", pl: "~/Documents/aeye-context.md", ja: "~/Documents/aeye-context.md", zh: "~/Documents/aeye-context.md" },
    contextBrowse: { en: "Browse", no: "Velg .md", sv: "Bläddra", da: "Vælg .md", de: "Wählen", fr: "Parcourir", es: "Elegir", pt: "Escolher", it: "Sfoglia", pl: "Wybierz", ja: "選択", zh: "浏览" },
    contextEdit:   { en: "Edit .md", no: "Rediger .md", sv: "Redigera .md", da: "Rediger .md", de: ".md öffnen", fr: "Éditer .md", es: "Editar .md", pt: "Editar .md", it: "Modifica .md", pl: "Edytuj .md", ja: ".mdを編集", zh: "编辑 .md" },
    contextNewMd:  { en: "Create .md", no: "Lag .md", sv: "Skapa .md", da: "Opret .md", de: ".md erstellen", fr: "Créer .md", es: "Crear .md", pt: "Criar .md", it: "Crea .md", pl: "Utwórz .md", ja: ".mdを作成", zh: "新建 .md" },
    contextOff:    { en: "Off", no: "Av", sv: "Av", da: "Fra", de: "Aus", fr: "Inactif", es: "Off", pt: "Off", it: "Off", pl: "Wył.", ja: "オフ", zh: "关闭" },
    contextNoteTag:{ en: "Note", no: "Notat", sv: "Not", da: "Note", de: "Notiz", fr: "Note", es: "Nota", pt: "Nota", it: "Nota", pl: "Notatka", ja: "メモ", zh: "备注" },
    tipContextSec: { en: "Add a custom comment or attach a .md file that every AI reads and considers with your screenshots", no: "Legg inn en kommentar eller knytt til en .md-fil som alle AI-ene leser og tar hensyn til", sv: "Lägg till en kommentar eller .md-fil som AI:n läser och tar hänsyn till", da: "Tilføj en kommentar eller .md-fil som AI'en læser og tager hensyn til", de: "Eigene Hinweise oder eine .md-Datei anhängen, die jede KI berücksichtigt", fr: "Ajouter une note ou un fichier .md que chaque IA prend en compte", es: "Añade un comentario o archivo .md que cada IA tendrá en cuenta", pt: "Adicione uma nota ou arquivo .md que toda IA levará em conta", it: "Aggiungi una nota o un file .md che ogni IA considererà", pl: "Dodaj komentarz lub plik .md uwzględniany przez każde AI", ja: "AIがすべてのスクリーンショット解析で参照するメモや.mdファイルを設定", zh: "添加备注或附加 .md 文件，让所有 AI 在分析截图时自动参考" },
    tipContextBrowse:{ en: "Pick an existing .md or .txt file from disk", no: "Velg en eksisterende .md- eller .txt-fil fra disk", sv: "Välj en befintlig .md- eller .txt-fil", da: "Vælg en eksisterende .md- eller .txt-fil", de: "Bestehende .md- oder .txt-Datei auswählen", fr: "Choisir un fichier .md ou .txt existant", es: "Elegir un archivo .md o .txt existente", pt: "Escolher um arquivo .md ou .txt existente", it: "Scegli un file .md o .txt esistente", pl: "Wybierz istniejący plik .md lub .txt", ja: "既存の.md/.txtファイルを選択", zh: "从磁盘选择已有的 .md 或 .txt 文件" },
    tipContextEdit:{ en: "Open the .md file in your default Omarchy editor (creates ~/.config/omarchy/aeye-context.md if none is set)", no: "Åpne .md-filen i din standard Omarchy-editor (oppretter ~/.config/omarchy/aeye-context.md hvis ingen er valgt)", sv: "Öppna .md-filen i din Omarchy-editor (skapar standardfil om ingen valts)", da: "Åbn .md-filen i din Omarchy-editor (opretter standardfil hvis ingen er valgt)", de: "Öffnet die .md-Datei im Standard-Editor (erstellt Standarddatei falls leer)", fr: "Ouvrir le fichier .md dans l'éditeur Omarchy (crée le fichier par défaut si vide)", es: "Abre el archivo .md en tu editor Omarchy (crea uno por defecto si está vacío)", pt: "Abre o arquivo .md no editor Omarchy (cria um padrão se vazio)", it: "Apri il file .md nell'editor Omarchy (crea quello predefinito se vuoto)", pl: "Otwórz plik .md w edytorze Omarchy (utworzy domyślny, jeśli pusty)", ja: "既定エディタで.mdを開く（未設定時はデフォルト作成）", zh: "在默认编辑器中打开 .md 文件（若未设置则自动创建默认文件）" },
    activeModelsHdr:{ en: "Active models", no: "Aktive modeller", sv: "Aktiva modeller", da: "Aktive modeller", de: "Aktive Modelle", fr: "Modèles actifs", es: "Modelos activos", pt: "Modelos ativos", it: "Modelli attivi", pl: "Aktywne modele", ja: "利用可能なモデル", zh: "可用模型" },
    loadingModels: { en: "Fetching active models…", no: "Henter aktive modeller…", sv: "Hämtar aktiva modeller…", da: "Henter aktive modeller…", de: "Lade aktive Modelle…", fr: "Chargement des modèles…", es: "Cargando modelos activos…", pt: "Carregando modelos ativos…", it: "Caricamento modelli…", pl: "Pobieranie modeli…", ja: "モデル一覧を取得中…", zh: "正在获取可用模型…" },
    modelAdded:    { en: "Added", no: "Lagt til", sv: "Tillagd", da: "Tilføjet", de: "Aktiv", fr: "Ajouté", es: "Añadido", pt: "Adicionado", it: "Aggiunto", pl: "Dodano", ja: "追加済", zh: "已添加" },
    tipRefreshMods:{ en: "Refresh live active models from installed CLIs (agy / grok)", no: "Oppdater aktive modeller direkte fra installerte CLI-er (agy / grok)", sv: "Uppdatera aktiva modeller från installerade CLI:er", da: "Opdater aktive modeller fra installerede CLI'er", de: "Aktive Modelle aus installierten CLIs neu laden", fr: "Actualiser les modèles actifs depuis les CLI installés", es: "Actualizar modelos activos desde las CLI instaladas", pt: "Atualizar modelos ativos das CLIs instaladas", it: "Aggiorna i modelli attivi dalle CLI installate", pl: "Odśwież aktywne modele z zainstalowanych CLI", ja: "インストール済みCLIから最新モデルを再取得", zh: "从已安装的 CLI 刷新可用模型列表" },
    autoDelegate:  { en: "Smart AI handoff on follow-up", no: "Smart AI-stafett ved oppfølging", sv: "Smart AI-stafett vid uppföljning", da: "Smart AI-stafet ved opfølgning", de: "Smartes KI-Handoff bei Nachfrage", fr: "Relais IA intelligent en suivi", es: "Relevo IA inteligente en seguimiento", pt: "Repasse inteligente de IA no chat", it: "Passaggio IA intelligente nel seguito", pl: "Inteligentne przekazanie AI w czacie", ja: "追質問で最適なAIへ自動バトンタッチ", zh: "追问时智能移交最佳 AI 模型" },
    autoDelegateSub:{ en: "Fast model on 1st reply → specialist model in chat", no: "Rask modell på 1. svar → spesialistmodell når du chatter videre", sv: "Snabb modell på 1:a svar → specialist i chatt", da: "Hurtig model på 1. svar → specialist i chat", de: "Schnelles 1. Modell → Spezialist im Chat", fr: "Modèle rapide au 1er tour → spécialiste ensuite", es: "Modelo rápido al inicio → especialista en el chat", pt: "Modelo rápido no 1º turno → especialista no chat", it: "Modello rapido al 1° turno → specialista in chat", pl: "Szybki model na start → specjalista w czacie", ja: "初回は高速モデル→深掘りは専門モデルへ自動切替", zh: "首轮快速响应 → 追问自动切换专业模型" },
    tipAutoDelegate:{ en: "Zero double-wait: your chosen fast model answers the initial capture in 1–2s, then automatically hands follow-up chat over to the strongest active model for code (Claude), deep logic (Argon/Neon) or realtime tech (Grok).", no: "Null dobbel ventetid: hurtigmodellen tar første skjermbildesvar på 1–2s, og gir automatisk stafettpinnen videre til beste aktive spesialist (Claude på kode, Argon/Neon på dyp logikk, Grok på sanntid) når du svarer i chatten.", sv: "Ingen dubbel väntetid: snabb modell tar första svaret och lämnar över uppföljning till bästa aktiva specialist.", da: "Ingen dobbelt ventetid: hurtig model tager første svar og giver stafetten videre til bedste aktive specialist i chatten.", de: "Keine doppelte Wartezeit: schnelles Modell für die erste Analyse, automatische Übergabe an den besten Spezialisten im Chat.", fr: "Zéro double attente : modèle rapide au premier tour, puis relais automatique au meilleur spécialiste actif dans le chat.", es: "Sin doble espera: modelo rápido en la primera respuesta y relevo automático al mejor especialista activo al conversar.", pt: "Sem espera dupla: modelo rápido na primeira resposta e repasse automático ao melhor especialista ativo no chat.", it: "Zero doppia attesa: modello rapido al primo turno e passaggio automatico al miglior specialista attivo nella chat.", pl: "Zero podwójnego czekania: szybki model na start, potem automatyczne przekazanie do najlepszego specjalisty w czacie.", ja: "待ち時間ゼロ：初回は高速モデルが即答し、チャットでの深掘りはコード・論理・最新情報の最適モデルへ自動引き継ぎします。", zh: "无双重等待：首轮由快速模型即刻回答，继续对话时自动移交给最擅长代码、深度逻辑或实时信息的已启用模型。" },
    agentMem:      { en: "Read installed AI agent memory", no: "Les minne fra installerte AI-er", sv: "Läs minne från installerade AI:er", da: "Læs hukommelse fra installerede AI'er", de: "KI-Agenten-Memory einbeziehen", fr: "Lire la mémoire des agents IA installés", es: "Leer memoria de agentes IA instalados", pt: "Ler memória dos agentes de IA instalados", it: "Leggi memoria degli agenti IA installati", pl: "Czytaj pamięć zainstalowanych agentów AI", ja: "インストール済みAIのメモリを参照", zh: "读取已安装 AI 代理的记忆" },
    agentMemSub:   { en: "Sync MEMORY.md / CLAUDE.md / GEMINI.md", no: "Synk MEMORY.md / CLAUDE.md / GEMINI.md", sv: "Synka MEMORY.md / CLAUDE.md / GEMINI.md", da: "Synk MEMORY.md / CLAUDE.md / GEMINI.md", de: "MEMORY.md / CLAUDE.md / GEMINI.md synchronisieren", fr: "Synchroniser MEMORY.md / CLAUDE.md / GEMINI.md", es: "Sincronizar MEMORY.md / CLAUDE.md / GEMINI.md", pt: "Sincronizar MEMORY.md / CLAUDE.md / GEMINI.md", it: "Sincronizza MEMORY.md / CLAUDE.md / GEMINI.md", pl: "Synchronizuj MEMORY.md / CLAUDE.md / GEMINI.md", ja: "MEMORY.md / CLAUDE.md / GEMINI.md を同期", zh: "同步 MEMORY.md / CLAUDE.md / GEMINI.md" },
    tipAgentMem:   { en: "Read-only sync of curated Markdown memory files (~/.grok/memory-v2/*/MEMORY.md, ~/.claude/CLAUDE.md, ~/.gemini/GEMINI.md) so Aeye automatically knows your preferences and stack.", no: "Leser automatisk oppsummerte Markdown-minnefiler (~/.grok/memory-v2/*/MEMORY.md, ~/.claude/CLAUDE.md, ~/.gemini/GEMINI.md) så Aeye kjenner oppsettet og preferansene dine.", sv: "Läser Markdown-minnesfiler från Grok, Claude och Gemini så Aeye känner till dina preferenser.", da: "Læser Markdown-hukommelsesfiler fra Grok, Claude og Gemini så Aeye kender dine præferencer.", de: "Liest kuratierte Markdown-Memory-Dateien von Grok, Claude und Gemini schreibgeschützt ein.", fr: "Lecture seule des fichiers mémoire Markdown de Grok, Claude et Gemini pour connaître vos préférences.", es: "Lectura de archivos de memoria Markdown de Grok, Claude y Gemini para conocer tus preferencias.", pt: "Leitura dos arquivos de memória Markdown do Grok, Claude e Gemini para conhecer suas preferências.", it: "Lettura dei file di memoria Markdown di Grok, Claude e Gemini per conoscere le tue preferenze.", pl: "Tylko do odczytu plików pamięci Markdown z Grok, Claude i Gemini.", ja: "Grok・Claude・GeminiのMarkdownメモリファイルを読み取り専用で参照します。", zh: "只读同步 Grok、Claude 和 Gemini 的 Markdown 记忆文件，自动了解你的偏好与技术栈。" }
  })

  function t(key) {
    var entry = i18n[key]
    if (!entry) return key
    return entry[activeLang] || entry["en"] || key
  }

  readonly property var baseModelChoices: [
    { choiceIndex: 0, vendorKey: "gemini",    id: "gemini-3.8-flash-high",    label: "Flash",      vendor: "Gemini",    badge: "OCR & Quick",     tipKey: "tipFlash",  custom: false },
    { choiceIndex: 1, vendorKey: "gemini",    id: "gemini-4-argon-high",      label: "Argon",      vendor: "Gemini",    badge: "Deep Logic",      tipKey: "tipArgon",  custom: false },
    { choiceIndex: 2, vendorKey: "anthropic", id: "claude-sonnet-5-5-medium", label: "Sonnet 5.5", vendor: "Anthropic", badge: "Code & Text",     tipKey: "tipSonnet", custom: false },
    { choiceIndex: 3, vendorKey: "xai",       id: "grok-4.7",                 label: "Grok 4.7",   vendor: "xAI",       badge: "Realtime & Tech", tipKey: "tipGrok",   custom: false },
    { choiceIndex: 4, vendorKey: "openai",    id: "gpt-4o",                   label: "GPT-4o",     vendor: "OpenAI",    badge: "UI & General",    tipKey: "tipOpenai", custom: false }
  ]

  readonly property var modelChoices: {
    var out = []
    for (var i = 0; i < baseModelChoices.length; i++) out.push(baseModelChoices[i])
    for (var j = 0; j < customModels.length; j++) {
      var cm = customModels[j]
      if (cm && cm.id) {
        out.push({
          choiceIndex: baseModelChoices.length + j,
          vendorKey: cm.vendorKey || "gemini",
          id: cm.id,
          label: cm.label || cm.id,
          vendor: cm.vendor || "Custom",
          badge: cm.badge || "Custom",
          tipKey: "hoverDefault",
          custom: true
        })
      }
    }
    return out
  }

  function isVendorReady(vendorKey) {
    for (var i = 0; i < providerStatuses.length; i++) {
      if (providerStatuses[i] && providerStatuses[i].vendor === vendorKey)
        return providerStatuses[i].ready === true
    }
    return false
  }

  function providerStatusFor(vendorKey) {
    for (var i = 0; i < providerStatuses.length; i++) {
      if (providerStatuses[i] && providerStatuses[i].vendor === vendorKey)
        return providerStatuses[i]
    }
    return null
  }

  function modelRequiresApiOnly(vendorKey, id) {
    var low = String(id || "").toLowerCase()
    if (vendorKey === "openai" && low.indexOf("gpt-oss-") !== 0) return true
    if (low.indexOf("grok-4.20-") === 0 || low.indexOf("grok-4-1-") === 0 || low.indexOf("grok-4.6") === 0 || low.indexOf("grok-4.5") === 0 || low.indexOf("grok-4.3") === 0) return true
    if (low.indexOf("gemini-2.5-") === 0) return true
    return false
  }

  function canModelToggleAuth(vendorKey, id) {
    if (modelRequiresApiOnly(vendorKey, id)) return false
    var st = providerStatusFor(vendorKey)
    return st !== null && st.hasCli === true && st.hasApi === true
  }

  function effectiveAuthForModel(vendorKey, id) {
    if (modelRequiresApiOnly(vendorKey, id)) return "api"
    var st = providerStatusFor(vendorKey)
    if (modelAuthMode && modelAuthMode[id]) {
      var m = String(modelAuthMode[id])
      if (m === "api" && st && st.hasApi) return "api"
      if (m === "cli" && st && st.hasCli) return "cli"
    }
    if (st && st.authMode) return String(st.authMode)
    return (vendorKey === "gemini" || vendorKey === "anthropic") ? "cli" : "api"
  }

  function isModelAdded(id) {
    for (var i = 0; i < modelChoices.length; i++) {
      if (modelChoices[i] && modelChoices[i].id === id) return true
    }
    return false
  }

  function modelDetailsFor(vendorKey, id) {
    var list = availableModels && availableModels[vendorKey]
    if (Array.isArray(list)) {
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === id && list[i].details) return list[i].details
      }
    }
    return ""
  }

  readonly property var activeModels: {
    var list = []
    for (var i = 0; i < modelChoices.length; i++) {
      if (isVendorReady(modelChoices[i].vendorKey)) list.push(modelChoices[i])
    }
    return list
  }

  readonly property color iconColor: {
    if (analysing) return colAnalysing
    if (hasUnreadAnswer) return colSuccess
    return bar ? bar.barForeground : Commons.Color.foreground
  }

  readonly property string barTooltip: {
    if (hasUnreadAnswer) return t("tipReady")
    if (analysing) return t("tipScanning")
    return t("tipIdle")
  }

  readonly property int readyProviderCount: {
    var n = 0
    for (var i = 0; i < providerStatuses.length; i++)
      if (providerStatuses[i] && providerStatuses[i].ready) n += 1
    return n
  }

  component PlainText: Text {
    textFormat: Text.PlainText
  }

  component ToggleRow: Rectangle {
    id: tRow
    property string title: ""
    property string subtitle: ""
    property string tip: ""
    property bool checked: false
    property bool warnTone: false
    readonly property color activeCol: warnTone ? Commons.Color.urgent : Commons.Color.accent
    signal toggled()

    width: parent.width
    height: subtitle !== "" ? Style.space(42) : Style.space(32)
    radius: Style.space(8)
    color: rowMouse.containsMouse ? root.surfaceHover : "transparent"
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: switchPill.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      PlainText {
        width: parent.width
        text: tRow.title
        color: tRow.warnTone && tRow.checked ? Commons.Color.urgent : root.fg
        font.family: root.face
        font.pixelSize: Style.font.caption
        font.bold: tRow.checked
        elide: Text.ElideRight
      }
      PlainText {
        visible: tRow.subtitle !== ""
        width: parent.width
        text: tRow.subtitle
        color: root.dim
        font.family: root.face
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Rectangle {
      id: switchPill
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(32)
      height: Style.space(18)
      radius: height / 2
      color: tRow.checked ? Util.alpha(tRow.activeCol, 0.35) : Util.alpha(root.fg, 0.10)
      border.width: 1
      border.color: tRow.checked ? tRow.activeCol : root.softLine
      Behavior on color { ColorAnimation { duration: Style.duration(140) } }

      Rectangle {
        width: Style.space(12)
        height: Style.space(12)
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: tRow.checked ? parent.width - width - Style.space(3) : Style.space(3)
        color: tRow.checked ? tRow.activeCol : root.dim
        Behavior on x { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: root.setPopoutHover(containsMouse, tRow.tip)
      onClicked: tRow.toggled()
    }
  }

  PanelController {
    id: panelController
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Top-bar Utvalg mark: solid sculptural eye inside four crisp screenshot corner brackets.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.barTooltip
    active: root.isActive
    useActiveColor: false
    iconComponent: Component {
      Item {
        id: iconRoot
        width: Style.bar.iconSize
        height: Style.bar.iconSize

        EyeMark {
          anchors.fill: parent
          color: root.bar ? root.bar.barForeground : Commons.Color.foreground
          accentColor: root.colAnalysing
          readyColor: root.colSuccess
          active: root.isActive
          ready: root.hasUnreadAnswer
          scanning: root.analysing && !root.paused && root.visible && !(root.bar && root.bar.barHidden)
        }

        Rectangle {
          visible: root.hasUnreadAnswer
          width: Math.max(4, Math.round(parent.width * 0.28))
          height: width
          radius: width / 2
          anchors.top: parent.top
          anchors.right: parent.right
          color: root.colSuccess

          SequentialAnimation on opacity {
            running: root.hasUnreadAnswer && root.visible && !(root.bar && root.bar.barHidden) && !Style.reduceMotion && Style.duration(100) > 0
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.45; duration: Style.duration(700); easing.type: Easing.Linear }
            NumberAnimation { from: 0.45; to: 1.0; duration: Style.duration(700); easing.type: Easing.Linear }
          }
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.triggerCapture()
      } else if (buttonCode === Qt.LeftButton) {
        if (root.hasUnreadAnswer) root.triggerOpenHud()
        else root.toggle()
      }
    }
  }

  // Native Omarchy Bar Popout: Quick Capture + Model Picker (Main) & Options page
  KeyboardPanel {
    id: popout
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: popoutKeys
    readonly property real activeBodyHeight: root.optionsPage ? optionsPageCol.implicitHeight : mainPageCol.implicitHeight
    contentWidth: popout.fittedContentWidth(Style.space(376))
    contentHeight: popout.fittedContentHeight(popoutHeader.height + Style.space(10) + activeBodyHeight + Style.space(10) + hoverFooter.height)

    FocusScope {
      id: popoutKeys
      anchors.fill: parent
      Keys.onEscapePressed: {
        if (root.editingVendor !== "") root.editingVendor = ""
        else if (root.optionsPage) root.optionsPage = false
        else root.close()
      }

      // 1. PINNED TOP HEADER — dynamic Aeye logo + gradient AI VISION + Options & language pills
      Item {
        id: popoutHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(34)

          Row {
            id: brandWordmark
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            EyeMark {
              id: aEyeLogo
              width: Style.space(22)
              height: Style.space(22)
              anchors.verticalCenter: parent.verticalCenter
              color: root.fg
              accentColor: Commons.Color.accent
              readyColor: root.colSuccess
              active: true
              ready: root.hasUnreadAnswer
              scanning: root.analysing && !root.paused
            }

            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              PlainText {
                text: "A"
                color: Commons.Color.accent
                font.family: root.face
                font.pixelSize: Style.font.heading
                font.bold: true
              }

              PlainText {
                text: "eye"
                color: root.fg
                font.family: root.face
                font.pixelSize: Style.font.heading
                font.bold: true
              }
            }
          }

          Row {
            id: headerRightControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            // Options page toggle pill
            Rectangle {
              id: headerOptionsPill
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(24)
              width: hdrOptLbl.implicitWidth + Style.space(16)
              radius: height / 2
              color: root.optionsPage
                ? Util.alpha(Commons.Color.accent, 0.22)
                : (hdrOptMouse.containsMouse ? root.surfaceHover : root.surface)
              border.width: 1
              border.color: (root.optionsPage || hdrOptMouse.containsMouse) ? Commons.Color.accent : root.softLine
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              PlainText {
                id: hdrOptLbl
                anchors.centerIn: parent
                text: (root.optionsPage ? "← " : "⚙ ") + root.t("options")
                color: (root.optionsPage || hdrOptMouse.containsMouse) ? Commons.Color.accent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                id: hdrOptMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setPopoutHover(containsMouse, root.optionsPage ? root.t("tipOptionsBack") : root.t("tipOptions"))
                onClicked: {
                  root.optionsPage = !root.optionsPage
                  popoutScroll.contentY = 0
                }
              }
            }

            // Compact Language switcher pill right in header (saves a full row below)
            Rectangle {
              id: headerLangPill
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(24)
              width: hdrLangLbl.implicitWidth + Style.space(16)
              radius: height / 2
              color: hdrLangMouse.containsMouse ? root.surfaceHover : root.surface
              border.width: 1
              border.color: hdrLangMouse.containsMouse ? Commons.Color.accent : root.softLine
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              PlainText {
                id: hdrLangLbl
                anchors.centerIn: parent
                text: "◎ " + root.localeDisplayLabel
                color: hdrLangMouse.containsMouse ? Commons.Color.accent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                id: hdrLangMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipLang"))
                onClicked: function(mouse) {
                  if (root.svc) root.svc.requestCycleLocale(mouse.button === Qt.RightButton ? -1 : 1)
                }
              }
            }
          }

        MouseArea {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: headerRightControls.left
          hoverEnabled: true
          cursorShape: root.optionsPage ? Qt.PointingHandCursor : Qt.ArrowCursor
          onContainsMouseChanged: root.setPopoutHover(containsMouse, root.optionsPage ? root.t("tipOptionsBack") : root.barTooltip)
          onClicked: {
            if (root.optionsPage) {
              root.optionsPage = false
              popoutScroll.contentY = 0
            }
          }
        }
      }

      // 2-6. SCROLLABLE MIDDLE BODY (auto-yields height to pinned header & hover footer so nothing clips)
      Flickable {
        id: popoutScroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: popoutHeader.bottom
        anchors.topMargin: Style.space(10)
        anchors.bottom: hoverFooter.top
        anchors.bottomMargin: Style.space(10)
        contentWidth: width
        contentHeight: popout.activeBodyHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 2

        // PAGE 1: MAIN (Quick Capture, AI Vision Models, Quick / Full HUD)
        Column {
          id: mainPageCol
          visible: !root.optionsPage
          width: popoutScroll.width - (popoutScroll.contentHeight > popoutScroll.height + 2 ? Style.space(8) : 0)
          spacing: Style.space(10)

        // 2. QUICK ACTIONS
        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: (root.hasAnswer || root.hasImage || root.analysing) ? (parent.width - Style.space(8)) * 0.56 : parent.width
            height: Style.space(34)
            radius: Style.space(9)
            color: capMouse.containsMouse ? Qt.lighter(Commons.Color.accent, 1.12) : Commons.Color.accent
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              PlainText {
                text: "✦"
                color: Commons.Color.background
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              PlainText {
                text: root.t("capture")
                color: Commons.Color.background
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            MouseArea {
              id: capMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipCaptureBtn"))
              onClicked: root.triggerCapture()
            }
          }

          Rectangle {
            visible: root.hasAnswer || root.hasImage || root.analysing
            width: (parent.width - Style.space(8)) * 0.44
            height: Style.space(34)
            radius: Style.space(9)
            color: root.hasUnreadAnswer
              ? (openMouse.containsMouse ? Util.alpha(root.colSuccess, 0.3) : Util.alpha(root.colSuccess, 0.2))
              : (openMouse.containsMouse ? root.surfaceHover : root.surface)
            border.width: 1
            border.color: root.hasUnreadAnswer ? root.colSuccess : root.softLine
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            PlainText {
              anchors.centerIn: parent
              text: root.hasUnreadAnswer || root.hasAnswer ? root.t("openAnswer") : root.t("openHud")
              color: root.hasUnreadAnswer ? root.colSuccess : root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              id: openMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipOpenBtn"))
              onClicked: root.triggerOpenHud()
            }
          }
        }

        // Active scan controls
        Row {
          visible: root.analysing
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: (parent.width - Style.space(8)) / 2
            height: Style.space(28)
            radius: Style.space(7)
            color: pBtnMouse.containsMouse ? Util.alpha(root.colAnalysing, 0.26) : Util.alpha(root.colAnalysing, 0.14)
            border.width: 1
            border.color: root.colAnalysing

            PlainText {
              anchors.centerIn: parent
              text: (root.paused ? "▶ " : "⏸ ") + (root.paused ? root.t("resume") : root.t("pause"))
              color: root.colAnalysing
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              id: pBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipPauseBtn"))
              onClicked: if (root.svc) root.svc.requestPauseToggle()
            }
          }

          Rectangle {
            width: (parent.width - Style.space(8)) / 2
            height: Style.space(28)
            radius: Style.space(7)
            color: sBtnMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.26) : root.surface
            border.width: 1
            border.color: sBtnMouse.containsMouse ? Commons.Color.urgent : root.softLine

            PlainText {
              anchors.centerIn: parent
              text: "■ " + root.t("stop")
              color: sBtnMouse.containsMouse ? Commons.Color.urgent : root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              id: sBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipStopBtn"))
              onClicked: if (root.svc) root.svc.requestStopAsk()
            }
          }
        }

        // 3. AI VISION MODEL SELECTOR (clean 2-column calm cards — zero neon border clutter)
        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            height: Style.space(20)
            PlainText {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.t("modelSec")
              color: root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: addModLbl.implicitWidth + Style.space(12)
              height: Style.space(20)
              radius: height / 2
              color: root.addModelOpen ? Util.alpha(Commons.Color.accent, 0.2) : (addModMouse.containsMouse ? root.surfaceHover : root.surface)
              border.width: 1
              border.color: root.addModelOpen ? Commons.Color.accent : root.softLine

              PlainText {
                id: addModLbl
                anchors.centerIn: parent
                text: root.addModelOpen ? "−" : "+ Add"
                color: root.addModelOpen ? Commons.Color.accent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                id: addModMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.addModelOpen = !root.addModelOpen
                  if (root.addModelOpen && root.svc && root.availableModelsForVendor.length === 0)
                    root.svc.requestRefreshAvailableModels(false)
                }
              }
            }
          }

          Rectangle {
            visible: root.activeModels.length === 0 && root.providerStatuses.length > 0
            width: parent.width
            height: noModLbl.implicitHeight + Style.space(14)
            radius: Style.space(8)
            color: Util.alpha(Commons.Color.urgent, 0.12)
            border.width: 1
            border.color: Commons.Color.urgent

            PlainText {
              id: noModLbl
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              text: "⚠ " + root.t("noActiveModels")
              color: Commons.Color.urgent
              font.family: root.face
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipApiSec"))
              onClicked: {
                root.optionsPage = true
                root.keysExpanded = true
                popoutScroll.contentY = 0
                if (root.svc) root.svc.requestRefreshProviders()
              }
            }
          }

          Flow {
            visible: root.activeModels.length > 0
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.activeModels
              delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool selected: root.modelId === modelData.id
                readonly property string effAuth: root.effectiveAuthForModel(modelData.vendorKey, modelData.id)
                readonly property bool canToggleAuth: root.canModelToggleAuth(modelData.vendorKey, modelData.id)
                width: (mainPageCol.width - Style.space(6)) / 2
                height: Style.space(36)
                radius: Style.space(8)
                color: selected ? Util.alpha(Commons.Color.accent, 0.16) : (mMouse.containsMouse ? root.surfaceHover : root.surface)
                border.width: 1
                border.color: selected ? Commons.Color.accent : root.softLine
                clip: true
                Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(34)
                  spacing: 1
                  PlainText {
                    width: parent.width
                    text: modelData.label
                    color: selected ? Commons.Color.accent : root.fg
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }
                  PlainText {
                    width: parent.width
                    text: modelData.vendor
                    color: root.dim
                    font.family: root.face
                    font.pixelSize: Math.max(9, Style.font.caption - 1)
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: mMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: {
                    var det = modelData.custom ? root.modelDetailsFor(modelData.vendorKey, modelData.id) : ""
                    root.setPopoutHover(containsMouse, modelData.custom ? (det !== "" ? det : (modelData.vendor + " · " + modelData.id)) : root.t(modelData.tipKey))
                  }
                  onClicked: if (root.svc) root.svc.requestPickModel(modelData.choiceIndex)
                }

                // Per-model CLI vs API badge (clickable when both CLI and API key are available)
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.right: parent.right
                  anchors.bottomMargin: Style.space(4)
                  anchors.rightMargin: Style.space(5)
                  width: modAuthLbl.implicitWidth + Style.space(8)
                  height: Style.space(14)
                  radius: Style.space(4)
                  color: effAuth === "api"
                    ? Util.alpha(Commons.Color.accent, modAuthMouse.containsMouse ? 0.28 : 0.16)
                    : Util.alpha(root.colSuccess, modAuthMouse.containsMouse ? 0.28 : 0.14)
                  border.width: canToggleAuth && modAuthMouse.containsMouse ? 1 : 0
                  border.color: Commons.Color.accent

                  PlainText {
                    id: modAuthLbl
                    anchors.centerIn: parent
                    text: effAuth.toUpperCase()
                    color: effAuth === "api" ? Commons.Color.accent : root.colSuccess
                    font.family: root.face
                    font.pixelSize: Math.max(8, Style.font.caption - 2)
                    font.bold: true
                  }

                  MouseArea {
                    id: modAuthMouse
                    enabled: canToggleAuth
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: canToggleAuth ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipAuthToggle"))
                    onClicked: {
                      if (root.svc && canToggleAuth) {
                        root.svc.requestSetModelAuthMode(modelData.id, effAuth === "api" ? "cli" : "api")
                      }
                    }
                  }
                }

                // Remove button for user-added custom models
                PlainText {
                  visible: modelData.custom === true
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.topMargin: Style.space(2)
                  anchors.rightMargin: Style.space(6)
                  text: "×"
                  color: delModMouse.containsMouse ? Commons.Color.urgent : root.dim
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  font.bold: true

                  MouseArea {
                    id: delModMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.svc) root.svc.requestRemoveCustomModel(modelData.id)
                  }
                }
              }
            }
          }

          // Inline form to add extra models for any provider (multiple models per provider!)
          Rectangle {
            visible: root.addModelOpen
            width: parent.width
            implicitHeight: addModForm.implicitHeight + Style.space(14)
            radius: Style.space(8)
            color: root.surface
            border.width: 1
            border.color: root.softLine

            Column {
              id: addModForm
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Row {
                width: parent.width
                spacing: Style.space(4)
                Repeater {
                  model: [
                    { key: "gemini",    label: "Gemini" },
                    { key: "anthropic", label: "Anthropic" },
                    { key: "xai",       label: "xAI" },
                    { key: "openai",    label: "OpenAI" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    readonly property bool picked: root.newModelVendor === modelData.key
                    width: (addModForm.width - Style.space(12)) / 4
                    height: Style.space(24)
                    radius: Style.space(5)
                    color: picked ? Util.alpha(Commons.Color.accent, 0.22) : root.surface
                    border.width: 1
                    border.color: picked ? Commons.Color.accent : root.softLine
                    PlainText {
                      anchors.centerIn: parent
                      text: modelData.label
                      color: picked ? Commons.Color.accent : root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: picked
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.newModelVendor = modelData.key
                        availModelsFlick.contentY = 0
                        if (root.svc && root.availableModelsForVendor.length === 0)
                          root.svc.requestRefreshAvailableModels(false)
                      }
                    }
                  }
                }
              }

              // Active models list for the selected provider (hover for full model details, click to add)
              Item {
                width: parent.width
                height: Style.space(18)

                PlainText {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.loadingModels && root.availableModelsForVendor.length === 0
                    ? root.t("loadingModels")
                    : (root.t("activeModelsHdr") + " (" + root.availableModelsForVendor.length + ")")
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Math.max(9, Style.font.caption - 1)
                  font.bold: true
                }

                Rectangle {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(20)
                  height: Style.space(18)
                  radius: Style.space(4)
                  color: refModMouse.containsMouse ? root.surfaceHover : "transparent"

                  PlainText {
                    anchors.centerIn: parent
                    text: "↻"
                    color: root.loadingModels || refModMouse.containsMouse ? Commons.Color.accent : root.dim
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  MouseArea {
                    id: refModMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipRefreshMods"))
                    onClicked: if (root.svc) root.svc.requestRefreshAvailableModels(true)
                  }
                }
              }

              Rectangle {
                visible: root.availableModelsForVendor.length > 0
                width: parent.width
                height: Math.min(Style.space(164), availModelsCol.implicitHeight + Style.space(8))
                radius: Style.space(7)
                color: Util.alpha(Commons.Color.background, 0.40)
                border.width: 1
                border.color: root.softLine
                clip: true

                Flickable {
                  id: availModelsFlick
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  contentWidth: width
                  contentHeight: availModelsCol.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  interactive: contentHeight > height + 2

                  Column {
                    id: availModelsCol
                    width: availModelsFlick.width - (availModelsFlick.contentHeight > availModelsFlick.height + 2 ? Style.space(6) : 0)
                    spacing: Style.space(3)

                    Repeater {
                      model: root.availableModelsForVendor
                      delegate: Rectangle {
                        required property var modelData
                        readonly property bool alreadyAdded: root.isModelAdded(modelData.id)
                        width: availModelsCol.width
                        height: Style.space(34)
                        radius: Style.space(6)
                        color: availRowMouse.containsMouse
                          ? Util.alpha(Commons.Color.accent, 0.16)
                          : (alreadyAdded ? Util.alpha(root.colSuccess, 0.08) : "transparent")
                        border.width: availRowMouse.containsMouse ? 1 : 0
                        border.color: Commons.Color.accent
                        Behavior on color { ColorAnimation { duration: Style.duration(110) } }

                        Column {
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.left: parent.left
                          anchors.right: availActionBadge.left
                          anchors.leftMargin: Style.space(7)
                          anchors.rightMargin: Style.space(6)
                          spacing: 1

                          PlainText {
                            width: parent.width
                            text: modelData.label
                            color: availRowMouse.containsMouse ? Commons.Color.accent : root.fg
                            font.family: root.face
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          PlainText {
                            width: parent.width
                            text: (modelData.tier ? (modelData.tier + " · ") : "") + modelData.id
                            color: root.dim
                            font.family: root.face
                            font.pixelSize: Math.max(9, Style.font.caption - 1)
                            elide: Text.ElideRight
                          }
                        }

                        PlainText {
                          id: availActionBadge
                          anchors.right: parent.right
                          anchors.rightMargin: Style.space(7)
                          anchors.verticalCenter: parent.verticalCenter
                          text: alreadyAdded ? ("✓ " + root.t("modelAdded")) : "+ Add"
                          color: alreadyAdded
                            ? root.colSuccess
                            : (availRowMouse.containsMouse ? Commons.Color.accent : root.dim)
                          font.family: root.face
                          font.pixelSize: Math.max(9, Style.font.caption - 1)
                          font.bold: alreadyAdded || availRowMouse.containsMouse
                        }

                        MouseArea {
                          id: availRowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onContainsMouseChanged: root.setPopoutHover(containsMouse, modelData.details || (modelData.label + " · " + modelData.id))
                          onClicked: {
                            if (root.svc) {
                              root.svc.requestAddCustomModel(root.newModelVendor, modelData.id, modelData.shortLabel || modelData.label)
                            }
                          }
                        }
                      }
                    }
                  }

                  Rectangle {
                    visible: availModelsFlick.contentHeight > availModelsFlick.height + 2
                    anchors.right: parent.right
                    y: availModelsFlick.visibleArea.yPosition * availModelsFlick.height
                    width: Style.space(3)
                    height: Math.max(Style.space(18), availModelsFlick.visibleArea.heightRatio * availModelsFlick.height)
                    radius: width / 2
                    color: Util.alpha(root.fg, 0.35)
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Rectangle {
                  width: parent.width - addSubmitBtn.width - Style.space(6)
                  height: Style.space(28)
                  radius: Style.space(6)
                  color: Util.alpha(Commons.Color.background, 0.55)
                  border.width: 1
                  border.color: newModIdInput.activeFocus ? Commons.Color.accent : root.softLine

                  TextInput {
                    id: newModIdInput
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.fg
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    clip: true
                    selectByMouse: true
                    onTextEdited: {
                      var low = text.trim().toLowerCase()
                      if (low.indexOf("gemini") === 0) root.newModelVendor = "gemini"
                      else if (low.indexOf("claude") === 0) root.newModelVendor = "anthropic"
                      else if (low.indexOf("grok") === 0) root.newModelVendor = "xai"
                      else if (low.indexOf("gpt") === 0 || low.indexOf("o1") === 0 || low.indexOf("o3") === 0 || low.indexOf("o4") === 0) root.newModelVendor = "openai"
                    }
                    PlainText {
                      anchors.fill: parent
                      verticalAlignment: Text.AlignVCenter
                      visible: newModIdInput.text === ""
                      text: "Model ID (e.g. claude-opus-4-6, gpt-4.1…)"
                      color: root.dim
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                    Keys.onReturnPressed: {
                      if (root.svc && newModIdInput.text.trim() !== "") {
                        root.svc.requestAddCustomModel(root.newModelVendor, newModIdInput.text.trim(), newModLblInput.text.trim())
                        newModIdInput.text = ""
                        newModLblInput.text = ""
                        root.addModelOpen = false
                      }
                    }
                  }
                }

                Rectangle {
                  id: addSubmitBtn
                  width: Style.space(48)
                  height: Style.space(28)
                  radius: Style.space(6)
                  color: Commons.Color.accent
                  PlainText {
                    anchors.centerIn: parent
                    text: "+ Add"
                    color: Commons.Color.background
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.svc && newModIdInput.text.trim() !== "") {
                        root.svc.requestAddCustomModel(root.newModelVendor, newModIdInput.text.trim(), newModLblInput.text.trim())
                        newModIdInput.text = ""
                        newModLblInput.text = ""
                        root.addModelOpen = false
                      }
                    }
                  }
                }
              }

              Rectangle {
                width: parent.width
                height: Style.space(26)
                radius: Style.space(6)
                color: Util.alpha(Commons.Color.background, 0.45)
                border.width: 1
                border.color: newModLblInput.activeFocus ? Commons.Color.accent : root.softLine

                TextInput {
                  id: newModLblInput
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  verticalAlignment: TextInput.AlignVCenter
                  color: root.fg
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  clip: true
                  selectByMouse: true
                  PlainText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: newModLblInput.text === ""
                    text: "Short label (optional, e.g. Opus 4.6)"
                    color: root.dim
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                  Keys.onReturnPressed: {
                    if (root.svc && newModIdInput.text.trim() !== "") {
                      root.svc.requestAddCustomModel(root.newModelVendor, newModIdInput.text.trim(), newModLblInput.text.trim())
                      newModIdInput.text = ""
                      newModLblInput.text = ""
                      root.addModelOpen = false
                    }
                  }
                }
              }
            }
          }
        }

        // 4. CAPTURE BEHAVIOR (Unified Auto-Analyze ON vs Manual Prompt)
        Rectangle {
          width: parent.width
          height: Style.space(32)
          radius: Style.space(8)
          color: root.surface
          border.width: 1
          border.color: root.softLine

          Row {
            anchors.fill: parent
            anchors.margins: Style.space(3)
            spacing: Style.space(3)

            Rectangle {
              width: (parent.width - Style.space(3)) / 2
              height: parent.height
              radius: Style.space(6)
              color: root.autosend ? Util.alpha(Commons.Color.accent, 0.22) : (quickModeMouse.containsMouse ? root.surfaceHover : "transparent")
              border.width: root.autosend ? 1 : 0
              border.color: Commons.Color.accent
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              PlainText {
                anchors.centerIn: parent
                text: root.t("modeQuick")
                color: root.autosend ? Commons.Color.accent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: root.autosend
              }

              MouseArea {
                id: quickModeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipModeQuick"))
                onClicked: if (root.svc) root.svc.requestSetAutosend(true)
              }
            }

            Rectangle {
              width: (parent.width - Style.space(3)) / 2
              height: parent.height
              radius: Style.space(6)
              color: !root.autosend ? Util.alpha(Commons.Color.accent, 0.22) : (hudModeMouse.containsMouse ? root.surfaceHover : "transparent")
              border.width: !root.autosend ? 1 : 0
              border.color: Commons.Color.accent
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              PlainText {
                anchors.centerIn: parent
                text: root.t("modeHud")
                color: !root.autosend ? Commons.Color.accent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: !root.autosend
              }

              MouseArea {
                id: hudModeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipModeHud"))
                onClicked: if (root.svc) root.svc.requestSetAutosend(false)
              }
            }
          }
        }
        }

        // PAGE 2: OPTIONS (Behavior settings, HUD placement, Providers & API keys, Pinned prompts)
        Column {
          id: optionsPageCol
          visible: root.optionsPage
          width: popoutScroll.width - (popoutScroll.contentHeight > popoutScroll.height + 2 ? Style.space(8) : 0)
          spacing: Style.space(10)

          // Grouped soft settings container
          Rectangle {
            width: parent.width
            implicitHeight: settingsGroupCol.implicitHeight + Style.space(8)
            radius: Style.space(9)
            color: root.surface
            border.width: 1
            border.color: root.softLine

            Column {
              id: settingsGroupCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(4)
              spacing: Style.space(2)

              ToggleRow {
                title: root.t("minSend")
                subtitle: root.t("minSendSub")
                tip: root.t("tipMinSend")
                checked: root.minimizeOnSend
                onToggled: if (root.svc) root.svc.requestSetMinimizeOnSend(!root.minimizeOnSend)
              }

              ToggleRow {
                title: root.t("autoDelegate")
                subtitle: root.t("autoDelegateSub")
                tip: root.t("tipAutoDelegate")
                checked: root.autoDelegate
                onToggled: if (root.svc) root.svc.requestSetAutoDelegate(!root.autoDelegate)
              }

              ToggleRow {
                title: root.t("agentMem")
                subtitle: root.t("agentMemSub")
                tip: root.t("tipAgentMem")
                checked: root.agentMemory
                onToggled: if (root.svc) root.svc.requestSetAgentMemory(!root.agentMemory)
              }

              ToggleRow {
                visible: !root.systemDebug
                title: root.t("reason")
                tip: root.t("tipReason")
                checked: root.showReason
                onToggled: if (root.svc) root.svc.requestSetShowReason(!root.showReason)
              }

              ToggleRow {
                title: root.t("sysDebug")
                subtitle: root.t("sysDebugSub")
                tip: root.t("tipSysDebug")
                warnTone: true
                checked: root.systemDebug
                onToggled: if (root.svc) root.svc.requestSetSystemDebug(!root.systemDebug)
              }

              Rectangle {
                visible: root.systemDebug
                width: parent.width - Style.space(8)
                anchors.horizontalCenter: parent.horizontalCenter
                height: visible ? sysDebugWarnLbl.implicitHeight + Style.space(10) : 0
                radius: Style.space(6)
                color: Util.alpha(Commons.Color.urgent, 0.10)
                border.width: 1
                border.color: Util.alpha(Commons.Color.urgent, 0.38)

                PlainText {
                  id: sysDebugWarnLbl
                  anchors.centerIn: parent
                  width: parent.width - Style.space(12)
                  text: root.t("sysDebugWarn")
                  color: root.fg
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }

              // HUD Placement & Hyprland Tiling Mode
              Column {
                width: parent.width
                topPadding: Style.space(4)
                bottomPadding: Style.space(4)
                leftPadding: Style.space(4)
                rightPadding: Style.space(4)
                spacing: Style.space(5)

                PlainText {
                  leftPadding: Style.space(4)
                  text: "⊞  " + root.t("hudPos")
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                }

                Row {
                  width: parent.width - Style.space(8)
                  spacing: Style.space(4)

                  Repeater {
                    model: [
                      { id: "bottom",     icon: "⬇", key: "posBottom",    tipKey: "tipPosFloat" },
                      { id: "top",        icon: "⬆", key: "posTop",       tipKey: "tipPosFloat" },
                      { id: "corner",     icon: "⬊", key: "posCorner",    tipKey: "tipPosFloat" },
                      { id: "dock-left",  icon: "◧", key: "posTileLeft",  tipKey: "tipPosTile"  },
                      { id: "dock-right", icon: "◨", key: "posTileRight", tipKey: "tipPosTile"  }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      readonly property bool active: root.hudPlacement === modelData.id
                      width: (parent.width - Style.space(16)) / 5
                      height: Style.space(24)
                      radius: Style.space(6)
                      color: active ? Util.alpha(Commons.Color.accent, 0.2) : (posMouse.containsMouse ? root.surfaceHover : "transparent")
                      border.width: 1
                      border.color: active ? Commons.Color.accent : root.softLine
                      Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                      PlainText {
                        anchors.centerIn: parent
                        text: modelData.icon + " " + root.t(modelData.key)
                        color: active ? Commons.Color.accent : root.dim
                        font.family: root.face
                        font.pixelSize: Style.font.caption
                        font.bold: active
                      }

                      MouseArea {
                        id: posMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t(modelData.tipKey))
                        onClicked: if (root.svc) root.svc.requestSetHudPlacement(modelData.id)
                      }
                    }
                  }
                }
              }
            }
          }

        // 4B. AI CONTEXT & MARKDOWN (.md) INSTRUCTIONS (seen by all AI providers)
        Column {
          width: parent.width
          spacing: Style.space(6)

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(7)
            color: ctxHdrMouse.containsMouse ? root.surfaceHover : "transparent"

            PlainText {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: (root.contextExpanded ? "▾  " : "▸  ") + "✎ " + root.t("contextSec")
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            PlainText {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.hasNoteContext && root.hasFileContext
                ? (root.t("contextNoteTag") + " + .md")
                : (root.hasFileContext ? ".md" : (root.hasNoteContext ? root.t("contextNoteTag") : root.t("contextOff")))
              color: root.hasAnyContext ? root.colSuccess : root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: root.hasAnyContext
            }

            MouseArea {
              id: ctxHdrMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipContextSec"))
              onClicked: root.contextExpanded = !root.contextExpanded
            }
          }

          Rectangle {
            visible: root.contextExpanded
            width: parent.width
            implicitHeight: ctxBodyCol.implicitHeight + Style.space(16)
            radius: Style.space(9)
            color: root.surface
            border.width: 1
            border.color: root.softLine

            Column {
              id: ctxBodyCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              // A. Freeform comment / custom instructions
              Column {
                width: parent.width
                spacing: Style.space(4)

                Item {
                  width: parent.width
                  height: Style.space(18)

                  PlainText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.t("contextNoteLbl")
                    color: root.dim
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    readonly property bool noteDirty: ctxNoteEdit.text.replace(/^\s+|\s+$/g, "") !== root.customContext.replace(/^\s+|\s+$/g, "")

                    Rectangle {
                      visible: root.hasNoteContext || ctxNoteEdit.text.length > 0
                      width: ctxClrLbl.implicitWidth + Style.space(10)
                      height: Style.space(18)
                      radius: Style.space(4)
                      color: ctxClrMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.20) : "transparent"
                      border.width: 1
                      border.color: ctxClrMouse.containsMouse ? Commons.Color.urgent : root.softLine

                      PlainText {
                        id: ctxClrLbl
                        anchors.centerIn: parent
                        text: root.t("clearKey")
                        color: ctxClrMouse.containsMouse ? Commons.Color.urgent : root.dim
                        font.family: root.face
                        font.pixelSize: Math.max(9, Style.font.caption - 1)
                      }

                      MouseArea {
                        id: ctxClrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          ctxNoteEdit.text = ""
                          if (root.svc) root.svc.requestSetCustomContext("")
                        }
                      }
                    }

                    Rectangle {
                      visible: parent.noteDirty
                      width: ctxSaveLbl.implicitWidth + Style.space(12)
                      height: Style.space(18)
                      radius: Style.space(4)
                      color: Commons.Color.accent

                      PlainText {
                        id: ctxSaveLbl
                        anchors.centerIn: parent
                        text: root.t("saveKey")
                        color: Commons.Color.background
                        font.family: root.face
                        font.pixelSize: Math.max(9, Style.font.caption - 1)
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (root.svc) root.svc.requestSetCustomContext(ctxNoteEdit.text)
                        }
                      }
                    }
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(66)
                  radius: Style.space(7)
                  color: ctxNoteEdit.activeFocus ? Util.alpha(root.fg, 0.08) : Util.alpha(Commons.Color.background, 0.45)
                  border.width: 1
                  border.color: ctxNoteEdit.activeFocus ? Commons.Color.accent : root.softLine
                  clip: true

                  PlainText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(7)
                    visible: ctxNoteEdit.text.length === 0
                    text: root.t("contextNoteHint")
                    color: root.dim
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                  }

                  Flickable {
                    id: ctxNoteFlick
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    contentWidth: width
                    contentHeight: Math.max(height, ctxNoteEdit.paintedHeight + Style.space(4))
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                      id: ctxNoteEdit
                      width: ctxNoteFlick.width
                      height: Math.max(ctxNoteFlick.height, paintedHeight)
                      textFormat: TextEdit.PlainText
                      wrapMode: TextEdit.Wrap
                      color: root.fg
                      selectionColor: Util.alpha(Commons.Color.accent, 0.35)
                      selectedTextColor: root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      selectByMouse: true
                      Component.onCompleted: text = root.customContext
                      onActiveFocusChanged: {
                        if (!activeFocus && root.svc && text.replace(/^\s+|\s+$/g, "") !== root.customContext.replace(/^\s+|\s+$/g, ""))
                          root.svc.requestSetCustomContext(text)
                      }
                      Connections {
                        target: root
                        function onCustomContextChanged() {
                          if (!ctxNoteEdit.activeFocus && ctxNoteEdit.text !== root.customContext)
                            ctxNoteEdit.text = root.customContext
                        }
                      }
                      Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                          if (root.svc) root.svc.requestSetCustomContext(ctxNoteEdit.text)
                          event.accepted = true
                        }
                      }
                      Keys.onEscapePressed: popoutKeys.forceActiveFocus()
                    }
                  }
                }
              }

              // B. Optional Markdown (.md) file path + Browse / Edit / Clear
              Column {
                width: parent.width
                spacing: Style.space(5)

                PlainText {
                  text: root.t("contextFileLbl")
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  width: parent.width
                  spacing: Style.space(5)

                  readonly property bool fileDirty: ctxFileInput.text.replace(/^\s+|\s+$/g, "") !== root.contextFile.replace(/^\s+|\s+$/g, "")

                  Rectangle {
                    width: parent.width - (ctxFileSaveBtn.visible ? ctxFileSaveBtn.width + Style.space(5) : 0)
                    height: Style.space(28)
                    radius: Style.space(6)
                    color: ctxFileInput.activeFocus ? Util.alpha(root.fg, 0.08) : Util.alpha(Commons.Color.background, 0.45)
                    border.width: 1
                    border.color: ctxFileInput.activeFocus ? Commons.Color.accent : root.softLine

                    PlainText {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      visible: ctxFileInput.text.length === 0
                      text: root.t("contextFileHint")
                      color: root.dim
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    TextInput {
                      id: ctxFileInput
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)
                      verticalAlignment: TextInput.AlignVCenter
                      color: root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      clip: true
                      selectByMouse: true
                      Component.onCompleted: text = root.contextFile
                      onActiveFocusChanged: {
                        if (!activeFocus && root.svc && text.replace(/^\s+|\s+$/g, "") !== root.contextFile.replace(/^\s+|\s+$/g, ""))
                          root.svc.requestSetContextFile(text)
                      }
                      Connections {
                        target: root
                        function onContextFileChanged() {
                          if (!ctxFileInput.activeFocus && ctxFileInput.text !== root.contextFile)
                            ctxFileInput.text = root.contextFile
                        }
                      }
                      onAccepted: {
                        if (root.svc) root.svc.requestSetContextFile(text)
                      }
                      Keys.onEscapePressed: popoutKeys.forceActiveFocus()
                    }
                  }

                  Rectangle {
                    id: ctxFileSaveBtn
                    visible: parent.fileDirty
                    width: ctxFileSaveLbl.implicitWidth + Style.space(14)
                    height: Style.space(28)
                    radius: Style.space(6)
                    color: Commons.Color.accent

                    PlainText {
                      id: ctxFileSaveLbl
                      anchors.centerIn: parent
                      text: root.t("saveKey")
                      color: Commons.Color.background
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.svc) root.svc.requestSetContextFile(ctxFileInput.text)
                      }
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Rectangle {
                    height: Style.space(24)
                    width: ctxBrowseLbl.implicitWidth + Style.space(16)
                    radius: Style.space(6)
                    color: ctxBrowseMouse.containsMouse ? root.surfaceHover : Util.alpha(Commons.Color.background, 0.35)
                    border.width: 1
                    border.color: ctxBrowseMouse.containsMouse ? Commons.Color.accent : root.softLine

                    PlainText {
                      id: ctxBrowseLbl
                      anchors.centerIn: parent
                      text: "📂 " + root.t("contextBrowse")
                      color: ctxBrowseMouse.containsMouse ? Commons.Color.accent : root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: ctxBrowseMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipContextBrowse"))
                      onClicked: {
                        root.close()
                        if (root.svc) root.svc.requestPickContextFile()
                      }
                    }
                  }

                  Rectangle {
                    height: Style.space(24)
                    width: ctxEditLbl.implicitWidth + Style.space(16)
                    radius: Style.space(6)
                    color: ctxEditMouse.containsMouse ? Util.alpha(Commons.Color.accent, 0.20) : Util.alpha(Commons.Color.background, 0.35)
                    border.width: 1
                    border.color: ctxEditMouse.containsMouse ? Commons.Color.accent : root.softLine

                    PlainText {
                      id: ctxEditLbl
                      anchors.centerIn: parent
                      text: "✎ " + (root.hasFileContext || ctxFileInput.text.trim().length > 0 ? root.t("contextEdit") : root.t("contextNewMd"))
                      color: ctxEditMouse.containsMouse ? Commons.Color.accent : root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: ctxEditMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipContextEdit"))
                      onClicked: {
                        var targetPath = ctxFileInput.text.replace(/^\s+|\s+$/g, "")
                        root.close()
                        if (root.svc) root.svc.requestEditContextFile(targetPath)
                      }
                    }
                  }

                  Rectangle {
                    visible: root.hasFileContext || ctxFileInput.text.length > 0
                    height: Style.space(24)
                    width: ctxFileClrLbl.implicitWidth + Style.space(14)
                    radius: Style.space(6)
                    color: ctxFileClrMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.20) : "transparent"
                    border.width: 1
                    border.color: ctxFileClrMouse.containsMouse ? Commons.Color.urgent : root.softLine

                    PlainText {
                      id: ctxFileClrLbl
                      anchors.centerIn: parent
                      text: root.t("clearKey")
                      color: ctxFileClrMouse.containsMouse ? Commons.Color.urgent : root.dim
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: ctxFileClrMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        ctxFileInput.text = ""
                        if (root.svc) root.svc.requestSetContextFile("")
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // 5. PROVIDERS & MANUAL API KEYS (Omarchy Agent Auth + Manual Fallback)
        Column {
          width: parent.width
          spacing: Style.space(6)

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(7)
            color: apiHdrMouse.containsMouse ? root.surfaceHover : "transparent"

            PlainText {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: (root.keysExpanded ? "▾  " : "▸  ") + "◈ " + root.t("apiSec")
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            PlainText {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.readyProviderCount + "/" + Math.max(4, root.providerStatuses.length)
              color: root.readyProviderCount > 0 ? root.colSuccess : Commons.Color.urgent
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              id: apiHdrMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipApiSec"))
              onClicked: {
                root.keysExpanded = !root.keysExpanded
                if (root.keysExpanded && root.svc) root.svc.requestRefreshProviders()
              }
            }
          }

          Column {
            visible: root.keysExpanded
            width: parent.width
            spacing: Style.space(5)

            PlainText {
              width: parent.width
              text: root.t("apiHint")
              color: root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.providerStatuses
              delegate: Column {
                required property var modelData
                readonly property bool isEditing: root.editingVendor === modelData.vendor
                width: optionsPageCol.width
                spacing: Style.space(4)

                Rectangle {
                  width: parent.width
                  height: Style.space(32)
                  radius: Style.space(7)
                  color: isEditing ? Util.alpha(Commons.Color.accent, 0.14) : (pRowMouse.containsMouse ? root.surfaceHover : root.surface)
                  border.width: 1
                  border.color: isEditing ? Commons.Color.accent : root.softLine

                  PlainText {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: root.fg
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  MouseArea {
                    id: pRowMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: provRightRow.left
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipProviderRow") + " (" + modelData.envName + ")")
                    onClicked: {
                      root.editingVendor = isEditing ? "" : modelData.vendor
                      if (root.editingVendor !== "") Qt.callLater(function() { keyField.forceActiveFocus() })
                    }
                  }

                  Row {
                    id: provRightRow
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    // 1-Click CLI vs API segmented switch when CLI is installed
                    Rectangle {
                      visible: modelData.hasCli === true
                      width: Style.space(70)
                      height: Style.space(22)
                      anchors.verticalCenter: parent.verticalCenter
                      radius: Style.space(5)
                      color: Util.alpha(Commons.Color.background, 0.55)
                      border.width: 1
                      border.color: root.softLine

                      Row {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 2

                        Rectangle {
                          width: (parent.width - 2) / 2
                          height: parent.height
                          radius: Style.space(4)
                          color: modelData.authMode !== "api" ? Util.alpha(root.colSuccess, 0.25) : "transparent"

                          PlainText {
                            anchors.centerIn: parent
                            text: "CLI"
                            color: modelData.authMode !== "api" ? root.colSuccess : root.dim
                            font.family: root.face
                            font.pixelSize: Math.max(9, Style.font.caption - 1)
                            font.bold: modelData.authMode !== "api"
                          }

                          MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipAuthToggle"))
                            onClicked: {
                              if (root.svc) root.svc.requestSetProviderAuthMode(modelData.vendor, "cli")
                            }
                          }
                        }

                        Rectangle {
                          width: (parent.width - 2) / 2
                          height: parent.height
                          radius: Style.space(4)
                          color: modelData.authMode === "api" ? Util.alpha(Commons.Color.accent, 0.25) : "transparent"

                          PlainText {
                            anchors.centerIn: parent
                            text: "API"
                            color: modelData.authMode === "api" ? Commons.Color.accent : root.dim
                            font.family: root.face
                            font.pixelSize: Math.max(9, Style.font.caption - 1)
                            font.bold: modelData.authMode === "api"
                          }

                          MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipAuthToggle"))
                            onClicked: {
                              if (modelData.hasApi === true) {
                                if (root.svc) root.svc.requestSetProviderAuthMode(modelData.vendor, "api")
                              } else {
                                root.editingVendor = modelData.vendor
                                Qt.callLater(function() { keyField.forceActiveFocus() })
                              }
                            }
                          }
                        }
                      }
                    }

                    PlainText {
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.ready ? ("✓ " + modelData.detail) : ("⚠ " + root.t("setKey"))
                      color: modelData.ready ? root.colSuccess : Commons.Color.urgent
                      font.family: root.face
                      font.pixelSize: Style.font.caption

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.editingVendor = isEditing ? "" : modelData.vendor
                          if (root.editingVendor !== "") Qt.callLater(function() { keyField.forceActiveFocus() })
                        }
                      }
                    }
                  }
                }

                // Masked manual API key editor row
                Row {
                  visible: isEditing
                  width: parent.width
                  spacing: Style.space(5)

                  Rectangle {
                    width: parent.width - saveKeyBtn.width - (clearKeyBtn.visible ? clearKeyBtn.width + Style.space(5) : 0) - Style.space(5)
                    height: Style.space(28)
                    radius: Style.space(6)
                    color: Util.alpha(root.fg, 0.08)
                    border.width: 1
                    border.color: Commons.Color.accent

                    PlainText {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      visible: keyField.text.length === 0
                      text: root.t("keyPlaceholder")
                      color: root.dim
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    TextInput {
                      id: keyField
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)
                      verticalAlignment: TextInput.AlignVCenter
                      echoMode: TextInput.Password
                      color: root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      clip: true
                      selectByMouse: true
                      onAccepted: {
                        var k = String(text || "").replace(/^\s+|\s+$/g, "")
                        if (k.length > 0 && root.svc) {
                          root.svc.requestSetApiKey(modelData.vendor, k)
                          text = ""
                          root.editingVendor = ""
                        }
                      }
                      Keys.onEscapePressed: root.editingVendor = ""
                    }
                  }

                  Rectangle {
                    id: saveKeyBtn
                    width: saveLbl.implicitWidth + Style.space(14)
                    height: Style.space(28)
                    radius: Style.space(6)
                    color: Commons.Color.accent

                    PlainText {
                      id: saveLbl
                      anchors.centerIn: parent
                      text: root.t("saveKey")
                      color: Commons.Color.background
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: keyField.accepted()
                    }
                  }

                  Rectangle {
                    id: clearKeyBtn
                    visible: modelData.hasManual === true
                    width: clearLbl.implicitWidth + Style.space(12)
                    height: Style.space(28)
                    radius: Style.space(6)
                    color: clearKeyMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.22) : root.surface
                    border.width: 1
                    border.color: clearKeyMouse.containsMouse ? Commons.Color.urgent : root.line

                    PlainText {
                      id: clearLbl
                      anchors.centerIn: parent
                      text: root.t("clearKey")
                      color: clearKeyMouse.containsMouse ? Commons.Color.urgent : root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: clearKeyMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.svc) root.svc.requestSetApiKey(modelData.vendor, "")
                        keyField.text = ""
                        root.editingVendor = ""
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // 6. PINNED PROMPTS MANAGER (clean collapsible accordion matching Providers)
        Column {
          width: parent.width
          spacing: Style.space(6)

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(7)
            color: pinHdrMouse.containsMouse ? root.surfaceHover : "transparent"

            PlainText {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: (root.promptsExpanded ? "▾  " : "▸  ") + "★ " + root.t("pinnedSec")
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            PlainText {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: String(root.customPrompts.length)
              color: root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              id: pinHdrMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipPinAdd"))
              onClicked: root.promptsExpanded = !root.promptsExpanded
            }
          }

          Column {
            visible: root.promptsExpanded
            width: parent.width
            spacing: Style.space(6)

            Flow {
              width: parent.width
              spacing: Style.space(5)
              visible: root.customPrompts.length > 0

              Repeater {
                model: root.customPrompts
                delegate: Rectangle {
                  required property string modelData
                  width: Math.min(optionsPageCol.width, pRow.implicitWidth + Style.space(14))
                  height: Style.space(24)
                  radius: height / 2
                  color: root.surface
                  border.width: 1
                  border.color: root.softLine

                  Row {
                    id: pRow
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    PlainText {
                      text: modelData
                      color: root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, optionsPageCol.width - Style.space(34))
                    }
                    PlainText {
                      text: "×"
                      color: pDelMouse.containsMouse ? Commons.Color.urgent : root.dim
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      MouseArea {
                        id: pDelMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipPinDel"))
                        onClicked: if (root.svc) root.svc.requestRemoveCustomPrompt(modelData)
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: Style.space(30)
              radius: Style.space(7)
              color: addPromptInput.activeFocus ? Util.alpha(root.fg, 0.08) : root.surface
              border.width: 1
              border.color: addPromptInput.activeFocus ? Commons.Color.accent : root.softLine

            PlainText {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(9)
              anchors.verticalCenter: parent.verticalCenter
              visible: addPromptInput.text.length === 0
              text: root.t("addPromptHint")
              color: root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
            }

            TextInput {
              id: addPromptInput
              anchors.left: parent.left
              anchors.right: addBtn.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.leftMargin: Style.space(9)
              anchors.rightMargin: Style.space(6)
              verticalAlignment: TextInput.AlignVCenter
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
              clip: true
              selectByMouse: true
              onAccepted: {
                var txt = String(text || "").replace(/^\s+|\s+$/g, "")
                if (txt.length > 0 && root.svc) {
                  root.svc.requestAddCustomPrompt(txt)
                  text = ""
                }
              }
              Keys.onEscapePressed: root.close()
            }

            Rectangle {
              id: addBtn
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(22)
              height: Style.space(22)
              radius: Style.space(5)
              color: addBtnMouse.containsMouse ? Util.alpha(Commons.Color.accent, 0.28) : "transparent"

              PlainText {
                anchors.centerIn: parent
                text: "+"
                color: addPromptInput.text.length > 0 ? Commons.Color.accent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.body
                font.bold: true
              }

              MouseArea {
                id: addBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipPinAdd"))
                onClicked: addPromptInput.accepted()
              }
            }
          }
          }
        }
        }

        // Subtle scrollbar indicator when popout content scrolls
        Rectangle {
          visible: popoutScroll.contentHeight > popoutScroll.height + 2
          anchors.right: parent.right
          y: popoutScroll.visibleArea.yPosition * popoutScroll.height
          width: Style.space(3)
          height: Math.max(Style.space(22), popoutScroll.visibleArea.heightRatio * popoutScroll.height)
          radius: width / 2
          color: Util.alpha(root.fg, 0.38)
        }
      }

      // 7. CLEAN BORDERLESS LIVE HOVER HINT FOOTER
      Item {
        id: hoverFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(Style.space(18), hintLbl.implicitHeight + Style.space(4))

        PlainText {
          id: hintLbl
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: Style.space(4)
          rightPadding: Style.space(4)
          text: root.hoverTip !== "" ? ("ⓘ " + root.hoverTip) : root.t("hoverDefault")
          color: root.hoverTip !== "" ? root.fg : Util.alpha(root.dim, 0.72)
          font.family: root.face
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        }
      }
    }
  }
}

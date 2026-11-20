import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Aeye top-bar widget: always-visible animated Spark Pupil icon + native
// Omarchy KeyboardPanel popout for quick capture, settings, API keys, and
// pinned prompts — 100% styled from Omarchy's live system theme.
BarWidget {
  id: root
  moduleName: "io.github.7eleven77.aeye"

  readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("io.github.7eleven77.aeye")
    : null

  readonly property string stage: svc ? String(svc.stage || "idle") : "idle"
  readonly property bool paused: svc ? svc.paused === true : false
  readonly property bool hasUnreadAnswer: svc ? svc.hasUnreadAnswer === true : false
  readonly property bool hasAnswer: svc ? svc.hasAnswer === true : false
  readonly property bool hasImage: svc ? svc.hasImage === true : false
  readonly property bool analysing: stage === "analysing"

  readonly property string modelId: svc ? String(svc.model || "gemini-3.8-flash-high") : "gemini-3.8-flash-high"
  readonly property bool autosend: svc ? svc.autosend === true : false
  readonly property bool minimizeOnSend: svc ? svc.minimizeOnSend === true : true
  readonly property bool minimalMode: svc ? svc.minimalMode === true : false
  readonly property bool showReason: svc ? svc.showReason === true : false
  readonly property bool systemDebug: svc ? svc.systemDebug === true : false
  readonly property string activeLang: svc ? String(svc.activeLang || "en") : "en"
  readonly property string localeDisplayLabel: svc ? String(svc.localeDisplayLabel || "Auto (EN)") : "Auto (EN)"
  readonly property string hudPlacement: svc ? String(svc.hudPlacement || "bottom") : "bottom"
  readonly property string visionWhy: svc ? String(svc.visionWhy || "") : ""
  readonly property var customPrompts: svc && Array.isArray(svc.customPrompts) ? svc.customPrompts : []
  readonly property var providerStatuses: svc && Array.isArray(svc.providerStatuses) ? svc.providerStatuses : []

  // 100% live Omarchy system theme colors
  readonly property color fg: Commons.Color.popups.text
  readonly property color dim: Commons.Color.muted
  readonly property color line: Commons.Color.popups.border
  readonly property color surface: Util.alpha(fg, 0.05)
  readonly property color surfaceHover: Util.alpha(fg, 0.1)
  readonly property color colAnalysing: svc ? svc.colAnalysing : Commons.Color.accent
  readonly property color colSuccess: svc ? svc.colSuccess : Commons.Color.accent
  readonly property string face: bar ? bar.fontFamily : Style.font.family

  readonly property bool opened: panelController.open
  property bool popoutSwitchClosing: false
  property string hoverTip: ""
  property bool keysExpanded: false
  property string editingVendor: ""

  function setPopoutHover(active, text) {
    if (active && text !== "") hoverTip = text
    else if (!active && hoverTip === text) hoverTip = ""
  }

  function open() {
    hoverTip = ""
    if (svc) svc.requestRefreshProviders()
    panelController.show()
  }
  function close() {
    hoverTip = ""
    editingVendor = ""
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
    sysDebugWarn:  { en: "Read-only diagnostics (journalctl errors, failed units, Hyprland, memory/disk) are sent with your screenshot. No env vars, no keys, never runs commands automatically.", no: "Lesebeskyttet diagnostikk (journalctl-feil, feilede tjenester, Hyprland, minne/disk) legges ved skjermbildet. Ingen nøkler eller env-variabler — kjører aldri kommandoer automatisk.", sv: "Skrivskyddad diagnostik (journalctl-fel, misslyckade tjänster, Hyprland, minne/disk) bifogas. Inga nycklar eller env-variabler — kör aldrig kommandon automatiskt.", da: "Skrivebeskyttet diagnostik (journalctl-fejl, fejlede tjenester, Hyprland, hukommelse/disk) vedhæftes. Ingen nøgler eller env-variabler — kører aldrig kommandoer automatisk.", de: "Nur-Lese-Diagnose (journalctl-Fehler, fehlgeschlagene Units, Hyprland, RAM/Disk) wird angehängt. Keine Keys/Env-Vars, führt nie Befehle automatisch aus.", fr: "Diagnostic en lecture seule (journalctl, unités en échec, Hyprland, RAM/disque) joint à la capture. Aucune clé/env, aucune exécution automatique.", es: "Diagnóstico de solo lectura (errores journalctl, unidades fallidas, Hyprland, RAM/disco) adjunto. Sin claves ni env, nunca ejecuta comandos.", pt: "Diagnóstico somente leitura (erros journalctl, unidades com falha, Hyprland, RAM/disco) anexado. Sem chaves/env, nunca executa comandos.", it: "Diagnostica in sola lettura (errori journalctl, unità fallite, Hyprland, RAM/disco) allegata. Nessuna chiave/env, mai comandi automatici.", pl: "Diagnostyka tylko do odczytu (błędy journalctl, nieudane usługi, Hyprland, RAM/dysk). Bez kluczy/env, nigdy nie uruchamia poleceń automatycznie.", ja: "読み取り専用の診断情報（journalctlエラー、失敗ユニット、Hyprland、メモリ/ディスク）を添付します。キーや環境変数は含まず、自動実行もしません。", zh: "随截图附加只读诊断信息（journalctl 错误、失败服务、Hyprland、内存/磁盘）。不包含密钥或环境变量，绝不自动执行命令。" },
    tipSysDebug:   { en: "Opt-in troubleshooting: attaches a bounded ~8 KB read-only snapshot (recent journalctl errors, failed units, Hyprland state, disk/RAM) so AI can diagnose real system issues. Zero sudo, zero secrets, never executes commands.", no: "Valgfri feilsøking: legger ved et avgrenset ~8 KB read-only snapshot (siste journalctl-feil, feilede tjenester, Hyprland-status, disk/RAM) så AI finner ekte systemårsaker. Null sudo, null hemmeligheter, kjører aldri kommandoer.", sv: "Valfri felsökning: bifogar en ~8 KB skrivskyddad ögonblicksbild (journalctl-fel, tjänster, Hyprland, disk/RAM). Ingen sudo, inga hemligheter, kör aldrig kommandon.", da: "Valgfri fejlfinding: vedhæfter et ~8 KB skrivebeskyttet snapshot (journalctl-fejl, tjenester, Hyprland, disk/RAM). Ingen sudo, ingen hemmeligheder, kører aldrig kommandoer.", de: "Optionale Fehlersuche: hängt einen ~8 KB Nur-Lese-Snapshot an (journalctl, Units, Hyprland, RAM/Disk). Kein sudo, keine Geheimnisse, keine automatische Ausführung.", fr: "Dépannage opt-in : joint un instantané lecture seule (~8 Ko : journalctl, unités, Hyprland, RAM/disque). Sans sudo, sans secrets, sans exécution automatique.", es: "Diagnóstico opcional: adjunta una instantánea de solo lectura (~8 KB: journalctl, unidades, Hyprland, RAM/disco). Sin sudo, sin secretos, sin ejecución automática.", pt: "Solução de problemas opcional: anexa um snapshot somente leitura (~8 KB: journalctl, unidades, Hyprland, RAM/disco). Sem sudo, sem segredos, sem execução automática.", it: "Debug opzionale: allega uno snapshot in sola lettura (~8 KB: journalctl, unità, Hyprland, RAM/disco). Zero sudo, zero segreti, nessuna esecuzione automatica.", pl: "Opcjonalna diagnostyka: dołącza migawkę tylko do odczytu (~8 KB: journalctl, usługi, Hyprland, RAM/dysk). Bez sudo, bez sekretów, bez automatycznego uruchamiania.", ja: "任意のトラブルシューティング：約8KBの読み取り専用スナップショット（journalctl、失敗ユニット、Hyprland、メモリ/ディスク）を添付します。sudo・機密情報・自動実行なし。", zh: "可选故障排查：附加约 8 KB 只读快照（journalctl 错误、失败服务、Hyprland、磁盘/内存）。无 sudo、无密钥、绝不自动执行命令。" },
    noActiveModels:{ en: "No active AI providers — click to add an API key below", no: "Ingen aktive AI-tilbydere — klikk for å legge inn API-nøkkel under", sv: "Inga aktiva AI-leverantörer — klicka för att lägga till API-nyckel", da: "Ingen aktive AI-udbydere — klik for at tilføje en API-nøgle", de: "Keine aktiven KI-Anbieter — klicken für API-Key-Setup", fr: "Aucun fournisseur IA actif — cliquez pour ajouter une clé API", es: "Sin proveedores de IA activos — haz clic para añadir una clave API", pt: "Nenhum provedor de IA ativo — clique para adicionar uma chave API", it: "Nessun provider IA attivo — clicca per aggiungere una chiave API", pl: "Brak aktywnych dostawców AI — kliknij, aby dodać klucz API", ja: "有効なAIプロバイダーなし — クリックしてAPIキーを設定", zh: "暂无已启用的 AI 服务商 — 点击下方配置 API 密钥" },
    stealth:       { en: "Stealth mode", no: "Stillemodus (Stealth)", sv: "Tyst läge (Stealth)", da: "Stilletilstand (Stealth)", de: "Still-Modus (Stealth)", fr: "Mode discret (Stealth)", es: "Modo sigilo (Stealth)", pt: "Modo discreto (Stealth)", it: "Modalità silenziosa", pl: "Tryb cichy (Stealth)", ja: "ステルスモード", zh: "静默模式" },
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
    tipPosTile:    { en: "Hyprland Tiled Sidebar — reserves screen space so your tiled windows resize neatly alongside Aeye with zero overlap", no: "Hyprland Tiled sidepanel — reserverer plass i flisleggingen så vinduene dine automatisk tilpasser seg ved siden av Aeye uten overlapp", sv: "Hyprland Tiled sidopanel — reserverar utrymme så dina fönster flisas snyggt bredvid Aeye", da: "Hyprland Tiled sidepanel — reserverer plads så dine vinduer tiles pænt ved siden af Aeye", de: "Hyprland Tiled Sidebar — reserviert Platz im Tiling-Layout ohne Überlappung", fr: "Panneau latéral Hyprland Tiled — réserve l'espace pour vos fenêtres sans chevauchement", es: "Panel lateral Hyprland Tiled — reserva espacio para que tus ventanas se ajusten junto a Aeye", pt: "Barra lateral Hyprland Tiled — reserva espaço para suas janelas sem sobreposição", it: "Barra laterale Hyprland Tiled — riserva spazio alle finestre senza sovrapposizioni", pl: "Panel boczny Hyprland Tiled — rezerwuje miejsce w układzie okien bez nakładania", ja: "Hyprlandタイル用サイドバー — 領域を確保し他ウィンドウと重ならず並列表示します", zh: "Hyprland 平铺侧边栏 — 自动预留屏幕空间，与平铺窗口并排显示不遮挡" }
  })

  function t(key) {
    var entry = i18n[key]
    if (!entry) return key
    return entry[activeLang] || entry["en"] || key
  }

  readonly property var modelChoices: [
    { choiceIndex: 0, vendorKey: "gemini",    id: "gemini-3.8-flash-high",    label: "Flash",      vendor: "Gemini",    badge: "OCR & Quick",     tipKey: "tipFlash" },
    { choiceIndex: 1, vendorKey: "gemini",    id: "gemini-4-argon-high",      label: "Argon",      vendor: "Gemini",    badge: "Deep Logic",      tipKey: "tipArgon" },
    { choiceIndex: 2, vendorKey: "anthropic", id: "claude-sonnet-5-5-medium", label: "Sonnet 5.5", vendor: "Anthropic", badge: "Code & Text",     tipKey: "tipSonnet" },
    { choiceIndex: 3, vendorKey: "xai",       id: "grok-4.7",                 label: "Grok 4.7",   vendor: "xAI",       badge: "Realtime & Tech", tipKey: "tipGrok" },
    { choiceIndex: 4, vendorKey: "openai",    id: "gpt-4o",                   label: "GPT-4o",     vendor: "OpenAI",    badge: "UI & General",    tipKey: "tipOpenai" }
  ]

  function isVendorReady(vendorKey) {
    for (var i = 0; i < providerStatuses.length; i++) {
      if (providerStatuses[i] && providerStatuses[i].vendor === vendorKey)
        return providerStatuses[i].ready === true
    }
    return false
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
        font.pixelSize: Math.max(10, Style.font.caption - 1)
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
      color: tRow.checked ? Util.alpha(tRow.activeCol, 0.35) : Util.alpha(root.fg, 0.12)
      border.width: 1
      border.color: tRow.checked ? tRow.activeCol : root.line
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

  // Top-bar animated Spark Pupil icon (Animation A: Spin + Pulse)
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.barTooltip
    active: root.opened || root.analysing || root.hasUnreadAnswer
    useActiveColor: false
    iconComponent: Component {
      Item {
        id: iconRoot
        width: Style.space(18)
        height: Style.space(18)

        readonly property color strokeCol: root.iconColor
        readonly property bool animActive: root.analysing && !root.paused && root.visible && !(root.bar && root.bar.barHidden) && !Style.reduceMotion && Style.duration(100) > 0

        onStrokeColChanged: {
          eyeCanvas.requestPaint()
          sparkCanvas.requestPaint()
        }

        Canvas {
          id: eyeCanvas
          anchors.fill: parent
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var s = width / 24.0
            ctx.save()
            ctx.scale(s, s)
            ctx.strokeStyle = iconRoot.strokeCol
            ctx.lineWidth = 2.1
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(2, 12)
            ctx.bezierCurveTo(5, 6.8, 8.5, 5, 12, 5)
            ctx.bezierCurveTo(15.5, 5, 19, 6.8, 22, 12)
            ctx.bezierCurveTo(19, 17.2, 15.5, 19, 12, 19)
            ctx.bezierCurveTo(8.5, 19, 5, 17.2, 2, 12)
            ctx.closePath()
            ctx.stroke()
            ctx.restore()
          }
        }

        Canvas {
          id: sparkCanvas
          anchors.fill: parent
          transformOrigin: Item.Center
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var s = width / 24.0
            ctx.save()
            ctx.scale(s, s)
            ctx.fillStyle = iconRoot.strokeCol
            ctx.beginPath()
            ctx.moveTo(12, 7.1)
            ctx.lineTo(13.3, 10.7)
            ctx.lineTo(16.9, 12)
            ctx.lineTo(13.3, 13.3)
            ctx.lineTo(12, 16.9)
            ctx.lineTo(10.7, 13.3)
            ctx.lineTo(7.1, 12)
            ctx.lineTo(10.7, 10.7)
            ctx.closePath()
            ctx.fill()
            ctx.restore()
          }

          ParallelAnimation {
            running: iconRoot.animActive
            loops: Animation.Infinite
            onRunningChanged: {
              if (!running) {
                sparkCanvas.rotation = 0
                sparkCanvas.scale = 1.0
              }
            }
            SequentialAnimation {
              NumberAnimation { target: sparkCanvas; property: "rotation"; from: 0; to: 90; duration: Style.duration(950); easing.type: Easing.InOutSine }
              NumberAnimation { target: sparkCanvas; property: "rotation"; from: 90; to: 180; duration: Style.duration(950); easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              NumberAnimation { target: sparkCanvas; property: "scale"; from: 0.84; to: 1.16; duration: Style.duration(950); easing.type: Easing.InOutSine }
              NumberAnimation { target: sparkCanvas; property: "scale"; from: 1.16; to: 0.84; duration: Style.duration(950); easing.type: Easing.InOutSine }
            }
          }
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
            NumberAnimation { from: 1.0; to: 0.35; duration: Style.duration(700); easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.35; to: 1.0; duration: Style.duration(700); easing.type: Easing.InOutSine }
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

  // Native Omarchy Bar Popout: Quick Capture + All Aeye Settings + API Keys
  KeyboardPanel {
    id: popout
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: popoutKeys
    contentWidth: popout.fittedContentWidth(Style.space(376))
    contentHeight: popout.fittedContentHeight(popoutHeader.height + Style.space(10) + popoutCol.implicitHeight + Style.space(10) + hoverFooter.height)

    FocusScope {
      id: popoutKeys
      anchors.fill: parent
      Keys.onEscapePressed: root.close()

      // 1. PINNED TOP HEADER — Variant 5A Transparent Theme-Native Wordmark ([A-Eye] ✦ EYE | AI VISION)
      Item {
        id: popoutHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(34)

          Item {
            id: brandWordmark
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: wmRow.implicitWidth
            height: Style.space(32)

            Row {
              id: wmRow
              anchors.left: parent.left
              anchors.top: parent.top
              spacing: Style.space(5)

              // Variant D A-Eye mark acting directly as the letter A (100% transparent bg + live theme colors)
              Canvas {
                id: aEyeLogo
                width: Style.space(26)
                height: Style.space(26)
                anchors.verticalCenter: parent.verticalCenter
                property color colA: Commons.Color.accent
                property color colEye: root.fg
                property color colSpark: root.colAnalysing
                onColAChanged: requestPaint()
                onColEyeChanged: requestPaint()
                onColSparkChanged: requestPaint()
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.clearRect(0, 0, width, height)
                  var s = width / 100.0
                  ctx.save()
                  ctx.scale(s, s)
                  ctx.lineCap = "round"
                  ctx.lineJoin = "round"
                  // A apex & legs
                  ctx.strokeStyle = colA
                  ctx.lineWidth = 7.2
                  ctx.beginPath()
                  ctx.moveTo(35, 42); ctx.lineTo(50, 15); ctx.lineTo(65, 42)
                  ctx.moveTo(27, 68); ctx.lineTo(19, 85)
                  ctx.moveTo(73, 68); ctx.lineTo(81, 85)
                  ctx.stroke()
                  // Eye contour
                  ctx.strokeStyle = colEye
                  ctx.lineWidth = 6.0
                  ctx.beginPath()
                  ctx.moveTo(16, 55)
                  ctx.bezierCurveTo(28, 39, 38.5, 35.5, 50, 35.5)
                  ctx.bezierCurveTo(61.5, 35.5, 72, 39, 84, 55)
                  ctx.bezierCurveTo(72, 71, 61.5, 74.5, 50, 74.5)
                  ctx.bezierCurveTo(38.5, 74.5, 28, 71, 16, 55)
                  ctx.closePath()
                  ctx.stroke()
                  // 4-point Spark pupil
                  ctx.fillStyle = colSpark
                  ctx.beginPath()
                  ctx.moveTo(50, 40.5); ctx.lineTo(53.4, 51.6); ctx.lineTo(64.5, 55)
                  ctx.lineTo(53.4, 58.4); ctx.lineTo(50, 69.5); ctx.lineTo(46.6, 58.4)
                  ctx.lineTo(35.5, 55); ctx.lineTo(46.6, 51.6)
                  ctx.closePath()
                  ctx.fill()
                  ctx.restore()
                }
              }

              PlainText {
                anchors.verticalCenter: parent.verticalCenter
                text: "✦"
                color: root.colAnalysing
                font.family: root.face
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              PlainText {
                id: eyeWord
                anchors.verticalCenter: parent.verticalCenter
                text: "EYE"
                color: root.fg
                font.family: root.face
                font.pixelSize: Math.round(Style.font.body * 1.25)
                font.bold: true
                font.letterSpacing: 2.5
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Style.space(5)
                spacing: 0
                PlainText {
                  text: "AI"
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Math.max(8, Style.font.caption - 3)
                  font.bold: true
                  font.letterSpacing: 1.4
                }
                PlainText {
                  text: "VISION"
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Math.max(8, Style.font.caption - 3)
                  font.letterSpacing: 1.1
                }
              }
            }

            // Crisp accent underline under [A-Eye] ✦ EYE
            Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(3)
              anchors.bottom: parent.bottom
              width: aEyeLogo.width + Style.space(18) + eyeWord.implicitWidth
              height: 2
              radius: 1
              color: Util.alpha(Commons.Color.accent, 0.55)
            }
          }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onContainsMouseChanged: root.setPopoutHover(containsMouse, root.barTooltip)
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
        contentHeight: popoutCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 2

        Column {
          id: popoutCol
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
            border.color: root.hasUnreadAnswer ? root.colSuccess : root.line
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
            border.color: sBtnMouse.containsMouse ? Commons.Color.urgent : root.line

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

        Rectangle { width: parent.width; height: 1; color: root.line; opacity: 0.45 }

        // 3. AI VISION MODEL SELECTOR (only active/ready providers; inactive ones live in API & Providers)
        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            height: Style.space(16)
            PlainText {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.t("modelSec")
              color: root.dim
              font.family: root.face
              font.pixelSize: Math.max(10, Style.font.caption - 1)
              font.bold: true
            }
            PlainText {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: root.visionWhy !== ""
              text: root.visionWhy
              color: Util.alpha(root.fg, 0.45)
              font.family: root.face
              font.pixelSize: Math.max(10, Style.font.caption - 1)
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
              font.pixelSize: Math.max(10, Style.font.caption - 1)
              wrapMode: Text.WordWrap
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipApiSec"))
              onClicked: {
                root.keysExpanded = true
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
                width: (root.activeModels.length % 2 === 1 && index === root.activeModels.length - 1)
                  ? popoutCol.width
                  : (popoutCol.width - Style.space(6)) / 2
                height: Style.space(38)
                radius: Style.space(8)
                color: selected ? Util.alpha(Commons.Color.accent, 0.18) : (mMouse.containsMouse ? root.surfaceHover : root.surface)
                border.width: 1
                border.color: selected ? Commons.Color.accent : root.line
                Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(1)
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(4)
                    PlainText {
                      text: modelData.label
                      color: selected ? Commons.Color.accent : root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    PlainText {
                      text: "· " + modelData.badge
                      color: root.dim
                      font.family: root.face
                      font.pixelSize: Math.max(10, Style.font.caption - 1)
                    }
                  }
                  PlainText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.vendor
                    color: root.dim
                    font.family: root.face
                    font.pixelSize: Math.max(10, Style.font.caption - 1)
                  }
                }

                MouseArea {
                  id: mMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t(modelData.tipKey))
                  onClicked: if (root.svc) root.svc.requestPickModel(modelData.choiceIndex)
                }
              }
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.line; opacity: 0.45 }

        // 4. SETTINGS TOGGLES + LOCALE
        Column {
          width: parent.width
          spacing: Style.space(2)

          PlainText {
            text: root.t("settingsSec")
            color: root.dim
            font.family: root.face
            font.pixelSize: Math.max(10, Style.font.caption - 1)
            font.bold: true
          }

          ToggleRow {
            title: root.t("minSend")
            subtitle: root.t("minSendSub")
            tip: root.t("tipMinSend")
            checked: root.minimizeOnSend
            onToggled: if (root.svc) root.svc.requestSetMinimizeOnSend(!root.minimizeOnSend)
          }

          ToggleRow {
            title: root.t("autoScan")
            subtitle: root.t("autoScanSub")
            tip: root.t("tipAutoScan")
            checked: root.autosend
            onToggled: if (root.svc) root.svc.requestSetAutosend(!root.autosend)
          }

          ToggleRow {
            title: root.t("stealth")
            tip: root.t("tipStealth")
            checked: root.minimalMode
            onToggled: if (root.svc) root.svc.requestSetMinimalMode(!root.minimalMode)
          }

          ToggleRow {
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
            width: parent.width
            height: visible ? sysDebugWarnLbl.implicitHeight + Style.space(12) : 0
            radius: Style.space(7)
            color: Util.alpha(Commons.Color.urgent, 0.10)
            border.width: 1
            border.color: Util.alpha(Commons.Color.urgent, 0.45)

            PlainText {
              id: sysDebugWarnLbl
              anchors.centerIn: parent
              width: parent.width - Style.space(14)
              text: root.t("sysDebugWarn")
              color: root.fg
              font.family: root.face
              font.pixelSize: Math.max(9, Style.font.caption - 2)
              wrapMode: Text.WordWrap
            }
          }

          // HUD Placement & Hyprland Tiling Mode
          Column {
            width: parent.width
            topPadding: Style.space(4)
            bottomPadding: Style.space(4)
            spacing: Style.space(5)

            PlainText {
              leftPadding: Style.space(8)
              text: "⊞  " + root.t("hudPos")
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
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
                  width: (popoutCol.width - Style.space(16)) / 5
                  height: Style.space(26)
                  radius: Style.space(6)
                  color: active ? Util.alpha(Commons.Color.accent, 0.2) : (posMouse.containsMouse ? root.surfaceHover : root.surface)
                  border.width: 1
                  border.color: active ? Commons.Color.accent : root.line
                  Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                  PlainText {
                    anchors.centerIn: parent
                    text: modelData.icon + " " + root.t(modelData.key)
                    color: active ? Commons.Color.accent : root.fg
                    font.family: root.face
                    font.pixelSize: Math.max(9, Style.font.caption - 2)
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

          Rectangle {
            width: parent.width
            height: Style.space(32)
            radius: Style.space(8)
            color: locMouse.containsMouse ? root.surfaceHover : "transparent"

            PlainText {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "◎  " + root.t("language")
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.caption
            }

            Rectangle {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(22)
              width: locVal.implicitWidth + Style.space(14)
              radius: Style.space(6)
              color: root.surface
              border.width: 1
              border.color: root.line

              PlainText {
                id: locVal
                anchors.centerIn: parent
                text: root.localeDisplayLabel
                color: Commons.Color.accent
                font.family: root.face
                font.pixelSize: Math.max(10, Style.font.caption - 1)
                font.bold: true
              }
            }

            MouseArea {
              id: locMouse
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

        Rectangle { width: parent.width; height: 1; color: root.line; opacity: 0.45 }

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
              font.pixelSize: Math.max(10, Style.font.caption - 1)
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
              font.pixelSize: Math.max(10, Style.font.caption - 1)
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.providerStatuses
              delegate: Column {
                required property var modelData
                readonly property bool isEditing: root.editingVendor === modelData.vendor
                width: popoutCol.width
                spacing: Style.space(4)

                Rectangle {
                  width: parent.width
                  height: Style.space(30)
                  radius: Style.space(7)
                  color: isEditing ? Util.alpha(Commons.Color.accent, 0.14) : (pRowMouse.containsMouse ? root.surfaceHover : root.surface)
                  border.width: 1
                  border.color: isEditing ? Commons.Color.accent : root.line

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

                  PlainText {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.ready ? ("✓ " + modelData.detail) : ("⚠ " + root.t("setKey"))
                    color: modelData.ready ? root.colSuccess : Commons.Color.urgent
                    font.family: root.face
                    font.pixelSize: Math.max(10, Style.font.caption - 1)
                  }

                  MouseArea {
                    id: pRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.setPopoutHover(containsMouse, root.t("tipProviderRow") + " (" + modelData.envName + ")")
                    onClicked: {
                      root.editingVendor = isEditing ? "" : modelData.vendor
                      if (root.editingVendor !== "") Qt.callLater(function() { keyField.forceActiveFocus() })
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
                      font.pixelSize: Math.max(10, Style.font.caption - 1)
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
                      font.pixelSize: Math.max(10, Style.font.caption - 1)
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

        Rectangle { width: parent.width; height: 1; color: root.line; opacity: 0.45 }

        // 6. PINNED PROMPTS MANAGER
        Column {
          width: parent.width
          spacing: Style.space(6)

          PlainText {
            text: "★  " + root.t("pinnedSec")
            color: root.dim
            font.family: root.face
            font.pixelSize: Math.max(10, Style.font.caption - 1)
            font.bold: true
          }

          Flow {
            width: parent.width
            spacing: Style.space(5)
            visible: root.customPrompts.length > 0

            Repeater {
              model: root.customPrompts
              delegate: Rectangle {
                required property string modelData
                width: Math.min(popoutCol.width, pRow.implicitWidth + Style.space(14))
                height: Style.space(24)
                radius: height / 2
                color: root.surface
                border.width: 1
                border.color: root.line

                Row {
                  id: pRow
                  anchors.centerIn: parent
                  spacing: Style.space(5)
                  PlainText {
                    text: modelData
                    color: root.fg
                    font.family: root.face
                    font.pixelSize: Math.max(10, Style.font.caption - 1)
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, popoutCol.width - Style.space(34))
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
            border.color: addPromptInput.activeFocus ? Commons.Color.accent : root.line

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

        // Subtle scrollbar indicator when popout content scrolls
        Rectangle {
          visible: popoutScroll.contentHeight > popoutScroll.height + 2
          anchors.right: parent.right
          y: popoutScroll.visibleArea.yPosition * popoutScroll.height
          width: Style.space(3)
          height: Math.max(Style.space(22), popoutScroll.visibleArea.heightRatio * popoutScroll.height)
          radius: width / 2
          color: Util.alpha(Commons.Color.accent, 0.45)
        }
      }

      // 7. PINNED BOTTOM LIVE HOVER HINT FOOTER (never clipped regardless of popout height)
      Rectangle {
        id: hoverFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(Style.space(28), hintLbl.implicitHeight + Style.space(12))
        radius: Style.space(7)
        color: root.hoverTip !== "" ? Util.alpha(Commons.Color.accent, 0.12) : root.surface
        border.width: 1
        border.color: root.hoverTip !== "" ? Util.alpha(Commons.Color.accent, 0.45) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }

        PlainText {
          id: hintLbl
          anchors.centerIn: parent
          width: parent.width - Style.space(14)
          text: root.hoverTip !== "" ? ("ⓘ " + root.hoverTip) : root.t("hoverDefault")
          color: root.hoverTip !== "" ? root.fg : root.dim
          font.family: root.face
          font.pixelSize: Math.max(10, Style.font.caption - 1)
          wrapMode: Text.WordWrap
          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        }
      }
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null

  property bool windowOpen: false
  property string imagePath: ""
  property string answer: ""
  property string note: ""
  property string errorText: ""
  property string draft: ""
  property bool busy: false
  property bool userTyped: false

  property string provider: "agy"
  property string model: "gemini-3.8-flash-high"
  property bool autosend: false
  property bool minimizeOnSend: true
  property bool watch: false
  property string lang: "auto" // "auto" or locale code (en, no, sv, da, de, fr, es, pt, it, pl, ja, zh)
  property bool minimalMode: false
  property string hudPlacement: "bottom" // bottom | top | corner | dock-right | dock-left
  readonly property bool isDocked: hudPlacement === "dock-right" || hudPlacement === "dock-left"
  property bool remapping: false
  property bool focusPrimed: false
  property bool dragging: false
  property bool hasCustomPos: false
  property real customX: 0
  property real customY: 0
  property var customPrompts: []
  property var aiPrompts: []
  property int recommendedModelIdx: -1
  property string recommendedCategory: ""

  property var pendingAsk: null
  property bool askStop: false
  property bool gotAnswerPath: false
  property int generation: 0
  property int answerGen: -1
  property string answerMode: ""
  property string inflight: ""
  property string tool: "arrow"
  property var marks: []
  property var cropNorm: null
  property bool marking: false
  property string resizeCorner: ""
  property var dragFrom: null
  property var dragTo: null
  property string hint: ""
  property string hoverTip: ""
  property var hoverItem: null
  property bool tooltipShown: false
  property real tooltipX: 0
  property real tooltipY: 0
  property bool showReason: false
  property bool systemDebug: false
  property string lastSaveDir: "~/Documents"
  property bool saveDrawerOpen: false
  property string savePathText: ""
  property string saveStatus: ""
  property string saveStatusMsg: ""
  property string lastPromptSent: ""
  property string reasoning: ""
  property string streamStep: ""
  property string streamRaw: ""
  property string liveThink: ""
  property var answerBlocks: []
  property int copiedBlockIdx: -1
  property real answerFade: 1
  onAnswerChanged: answerBlocks = parseMarkdownBlocks(answer)
  property string omarchyAgent: "grok"
  property string visionWhy: ""
  property bool paused: false
  property bool editing: false
  property bool previewOpen: true
  property bool userPickedModel: false
  property bool copiedFeedback: false
  property bool silentRun: false
  property bool backgroundRun: false
  property bool hasUnreadAnswer: false
  property var providerStatuses: []

  // Live theme colors read directly from Omarchy's active theme (zero hardcoded UI colors)
  property string themeYellowHex: ""
  property string themeGreenHex: ""

  readonly property color fg: Color.popups.text
  readonly property color bg: Color.popups.background
  readonly property color line: Color.popups.border
  readonly property color dim: Color.muted
  readonly property color surface: Util.alpha(fg, 0.045)
  readonly property color surfaceHover: Util.alpha(fg, 0.09)
  readonly property color surfaceActive: Util.alpha(Color.accent, 0.18)

  readonly property color colAnalysing: themeYellowHex !== "" ? themeYellowHex : Color.accent
  readonly property color colSuccess: themeGreenHex !== "" ? themeGreenHex : Color.accent
  readonly property color colReady: Color.accent

  readonly property int pad: Style.space(16)
  readonly property int radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(12)
  readonly property string face: Style.font.family

  // Støttede språk i Omarchy
  readonly property var supportedLocales: [
    { code: "auto", label: "Auto (System)" },
    { code: "en",   label: "English (EN)" },
    { code: "no",   label: "Norsk (NO)" },
    { code: "sv",   label: "Svenska (SV)" },
    { code: "da",   label: "Dansk (DA)" },
    { code: "de",   label: "Deutsch (DE)" },
    { code: "fr",   label: "Français (FR)" },
    { code: "es",   label: "Español (ES)" },
    { code: "pt",   label: "Português (PT)" },
    { code: "it",   label: "Italiano (IT)" },
    { code: "pl",   label: "Polski (PL)" },
    { code: "ja",   label: "日本語 (JA)" },
    { code: "zh",   label: "中文 (ZH)" }
  ]

  readonly property string activeLang: {
    if (lang !== "auto") return lang
    var sys = String(Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "en").toLowerCase()
    if (sys.indexOf("nb") === 0 || sys.indexOf("nn") === 0 || sys.indexOf("no") === 0) return "no"
    var prefixes = ["sv", "da", "de", "fr", "es", "pt", "it", "pl", "ja", "zh"]
    for (var i = 0; i < prefixes.length; i++) {
      if (sys.indexOf(prefixes[i]) === 0) return prefixes[i]
    }
    return "en"
  }

  readonly property string localeDisplayLabel: {
    for (var i = 0; i < supportedLocales.length; i++) {
      if (supportedLocales[i].code === lang) {
        if (lang === "auto") return "Auto (" + activeLang.toUpperCase() + ")"
        return supportedLocales[i].label
      }
    }
    return lang.toUpperCase()
  }

  readonly property var i18nTable: ({
    scanning:   { en: "SCANNING…", no: "ANALYSERER…", sv: "ANALYSERAR…", da: "ANALYSERER…", de: "ANALYSIERT…", fr: "ANALYSE…", es: "ANALIZANDO…", pt: "ANALISANDO…", it: "ANALISI…", pl: "ANALIZA…", ja: "解析中…", zh: "分析中…" },
    paused:     { en: "PAUSED", no: "PAUSET", sv: "PAUSAD", da: "PAUSET", de: "PAUSIERT", fr: "EN PAUSE", es: "PAUSADO", pt: "PAUSADO", it: "IN PAUSA", pl: "WSTRZYMANO", ja: "一時停止", zh: "已暂停" },
    answered:   { en: "DONE", no: "KLART", sv: "KLART", da: "KLAR", de: "FERTIG", fr: "PRÊT", es: "LISTO", pt: "PRONTO", it: "PRONTO", pl: "GOTOWE", ja: "完了", zh: "完成" },
    ready:      { en: "READY", no: "KLAR", sv: "REDO", da: "KLAR", de: "BEREIT", fr: "PRÊT", es: "LISTO", pt: "PRONTO", it: "PRONTO", pl: "GOTOWY", ja: "準備完了", zh: "就绪" },
    autoOn:     { en: "AUTO: ON", no: "AUTO: PÅ", sv: "AUTO: PÅ", da: "AUTO: TIL", de: "AUTO: AN", fr: "AUTO: ON", es: "AUTO: SÍ", pt: "AUTO: ON", it: "AUTO: ON", pl: "AUTO: WŁ", ja: "自動: ON", zh: "自动: 开" },
    autoOff:    { en: "AUTO: OFF", no: "AUTO: AV", sv: "AUTO: AV", da: "AUTO: FRA", de: "AUTO: AUS", fr: "AUTO: OFF", es: "AUTO: NO", pt: "AUTO: OFF", it: "AUTO: OFF", pl: "AUTO: WYŁ", ja: "自動: OFF", zh: "自动: 关" },
    resume:     { en: "Resume", no: "Fortsett", sv: "Fortsätt", da: "Fortsæt", de: "Weiter", fr: "Reprendre", es: "Reanudar", pt: "Retomar", it: "Riprendi", pl: "Wznów", ja: "再開", zh: "继续" },
    pause:      { en: "Pause", no: "Pause", sv: "Paus", da: "Pause", de: "Pause", fr: "Pause", es: "Pausa", pt: "Pausa", it: "Pausa", pl: "Pauza", ja: "停止", zh: "暂停" },
    stop:       { en: "Stop", no: "Stopp", sv: "Stopp", da: "Stop", de: "Stopp", fr: "Arrêter", es: "Detener", pt: "Parar", it: "Ferma", pl: "Stop", ja: "中止", zh: "停止" },
    image:      { en: "Image", no: "Bilde", sv: "Bild", da: "Billede", de: "Bild", fr: "Image", es: "Imagen", pt: "Imagem", it: "Immagine", pl: "Obraz", ja: "画像", zh: "图像" },
    hideImage:  { en: "Hide Image", no: "Skjul bilde", sv: "Dölj bild", da: "Skjul billede", de: "Bild ausblenden", fr: "Masquer", es: "Ocultar", pt: "Ocultar", it: "Nascondi", pl: "Ukryj", ja: "隠す", zh: "隐藏图像" },
    doneEdit:   { en: "Done Editing", no: "Ferdig med redigering", sv: "Klar med redigering", da: "Færdig", de: "Fertig", fr: "Terminé", es: "Listo", pt: "Concluído", it: "Fatto", pl: "Gotowe", ja: "編集完了", zh: "完成编辑" },
    editMsg:    { en: "Editing in Omasnap. Save there to update.", no: "Redigerer i Omasnap. Lagre der for å oppdatere.", sv: "Redigerar i Omasnap. Spara där för att uppdatera.", da: "Redigerer i Omasnap. Gem der for at opdatere.", de: "Bearbeitung in Omasnap. Speichern zum Aktualisieren.", fr: "Édition dans Omasnap. Enregistrez pour mettre à jour.", es: "Editando en Omasnap. Guarda allí para actualizar.", pt: "Editando no Omasnap. Salve lá para atualizar.", it: "Modifica in Omasnap. Salva per aggiornare.", pl: "Edycja w Omasnap. Zapisz, aby zaktualizować.", ja: "Omasnapで編集中。保存すると更新されます。", zh: "正在 Omasnap 中编辑，保存后自动更新。" },
    stealth:    { en: "Stealth", no: "Stille", sv: "Tyst", da: "Stille", de: "Still", fr: "Discret", es: "Sigilo", pt: "Discreto", it: "Silenzioso", pl: "Cichy", ja: "ステルス", zh: "静默" },
    stealthOn:  { en: "Stealth: ON", no: "Stille: PÅ", sv: "Tyst: PÅ", da: "Stille: TIL", de: "Still: AN", fr: "Discret: ON", es: "Sigilo: SÍ", pt: "Discreto: ON", it: "Silenzioso: ON", pl: "Cichy: WŁ", ja: "ステルス: ON", zh: "静默: 开" },
    noResponse: { en: "No response from model.", no: "Ingen respons fra modellen.", sv: "Inget svar från modellen.", da: "Intet svar fra modellen.", de: "Keine Antwort vom Modell.", fr: "Aucune réponse du modèle.", es: "Sin respuesta del modelo.", pt: "Sem resposta do modelo.", it: "Nessuna risposta dal modello.", pl: "Brak odpowiedzi od modelu.", ja: "モデルから応答がありませんでした。", zh: "模型未返回响应。" },
    reasonOn:   { en: "Reasoning: ON", no: "Resonnering: PÅ", sv: "Resonemang: PÅ", da: "Ræsonnement: TIL", de: "Begründung: AN", fr: "Raisonnement: ON", es: "Razonamiento: SÍ", pt: "Raciocínio: ON", it: "Ragionamento: ON", pl: "Tok myślenia: WŁ", ja: "推論表示: ON", zh: "推理过程: 开" },
    reasonOff:  { en: "Reasoning: OFF", no: "Resonnering: AV", sv: "Resonemang: AV", da: "Ræsonnement: FRA", de: "Begründung: AUS", fr: "Raisonnement: OFF", es: "Razonamiento: NO", pt: "Raciocínio: OFF", it: "Ragionamento: OFF", pl: "Tok myślenia: WYŁ", ja: "推論表示: OFF", zh: "推理过程: 关" },
    arrow:      { en: "Arrow", no: "Pil", sv: "Pil", da: "Pil", de: "Pfeil", fr: "Flèche", es: "Flecha", pt: "Seta", it: "Freccia", pl: "Strzałka", ja: "矢印", zh: "箭头" },
    box:        { en: "Box", no: "Boks", sv: "Ruta", da: "Boks", de: "Kasten", fr: "Boîte", es: "Caja", pt: "Caixa", it: "Riquadro", pl: "Ramka", ja: "枠", zh: "方框" },
    crop:       { en: "Crop", no: "Beskjær", sv: "Beskär", da: "Beskær", de: "Zuschneiden", fr: "Recadrer", es: "Recortar", pt: "Cortar", it: "Ritaglia", pl: "Przytnij", ja: "切り抜き", zh: "裁剪" },
    applyCrop:  { en: "Apply Crop", no: "Bruk utsnitt", sv: "Använd beskärning", da: "Brug udsnit", de: "Anwenden", fr: "Appliquer", es: "Aplicar", pt: "Aplicar", it: "Applica", pl: "Zastosuj", ja: "適用", zh: "应用裁剪" },
    clear:      { en: "Clear", no: "Nullstill", sv: "Rensa", da: "Nulstil", de: "Löschen", fr: "Effacer", es: "Limpiar", pt: "Limpar", it: "Cancella", pl: "Wyczyść", ja: "クリア", zh: "清除" },
    inspecting: { en: " is inspecting the screenshot…", no: " analyserer skjermbildet…", sv: " analyserar skärmbilden…", da: " analyserer skærmbilledet…", de: " analysiert das Bildschirmfoto…", fr: " analyse la capture d'écran…", es: " está analizando la captura…", pt: " está analisando a captura…", it: " sta analizzando lo screenshot…", pl: " analizuje zrzut ekranu…", ja: " がスクリーンショットを解析中…", zh: " 正在分析截图…" },
    copy:       { en: "Copy", no: "Kopier", sv: "Kopiera", da: "Kopiér", de: "Kopieren", fr: "Copier", es: "Copiar", pt: "Copiar", it: "Copia", pl: "Kopiuj", ja: "コピー", zh: "复制" },
    copied:     { en: "Copied", no: "Kopiert", sv: "Kopierad", da: "Kopieret", de: "Kopiert", fr: "Copié", es: "Copiado", pt: "Copiado", it: "Copiato", pl: "Skopiowano", ja: "コピー済", zh: "已复制" },
    save:       { en: "Save", no: "Lagre", sv: "Spara", da: "Gem", de: "Speichern", fr: "Enregistrer", es: "Guardar", pt: "Salvar", it: "Salva", pl: "Zapisz", ja: "保存", zh: "保存" },
    saved:      { en: "Saved", no: "Lagret", sv: "Sparad", da: "Gemt", de: "Gespeichert", fr: "Enregistré", es: "Guardado", pt: "Salvo", it: "Salvato", pl: "Zapisano", ja: "保存済", zh: "已保存" },
    savePathHint:{ en: "~/Documents/aeye-note.txt (or .md, .pdf, .html, .json, any path…)", no: "~/Documents/aeye-notat.txt (eller .md, .pdf, .html, .json, valgfri sti…)", sv: "~/Documents/aeye-note.txt (eller .md, .pdf, .html, .json…)", da: "~/Documents/aeye-note.txt (eller .md, .pdf, .html, .json…)", de: "~/Documents/aeye-note.txt (oder .md, .pdf, .html, .json…)", fr: "~/Documents/aeye-note.txt (ou .md, .pdf, .html, .json…)", es: "~/Documents/aeye-note.txt (o .md, .pdf, .html, .json…)", pt: "~/Documents/aeye-note.txt (ou .md, .pdf, .html, .json…)", it: "~/Documents/aeye-note.txt (o .md, .pdf, .html, .json…)", pl: "~/Documents/aeye-note.txt (lub .md, .pdf, .html, .json…)", ja: "~/Documents/aeye-note.txt（.md/.pdf/.html/.json等）", zh: "~/Documents/aeye-note.txt（支持 .md/.pdf/.html/.json 或任意路径…）" },
    tipSave:    { en: "Export answer to any file (.txt, .md, .pdf, .html, .json, or custom path)", no: "Eksporter svaret til valgfri fil (.txt, .md, .pdf, .html, .json eller egen sti)", sv: "Exportera svaret till valfri fil (.txt, .md, .pdf, .html, .json)", da: "Eksportér svaret til valgfri fil (.txt, .md, .pdf, .html, .json)", de: "Antwort in beliebige Datei exportieren (.txt, .md, .pdf, .html, .json)", fr: "Exporter la réponse vers un fichier (.txt, .md, .pdf, .html, .json)", es: "Exportar respuesta a cualquier archivo (.txt, .md, .pdf, .html, .json)", pt: "Exportar resposta para qualquer arquivo (.txt, .md, .pdf, .html, .json)", it: "Esporta la risposta in qualsiasi file (.txt, .md, .pdf, .html, .json)", pl: "Eksportuj odpowiedź do pliku (.txt, .md, .pdf, .html, .json)", ja: "回答を任意のファイル形式で保存（.txt/.md/.pdf/.html/.json）", zh: "导出回答到任意文件（.txt/.md/.pdf/.html/.json 等）" },
    fixCli:     { en: "Fix in CLI", no: "Fiks i CLI", sv: "Fixa i CLI", da: "Ret i CLI", de: "Im CLI fixen", fr: "Corriger en CLI", es: "Corregir en CLI", pt: "Corrigir no CLI", it: "Risolvi in CLI", pl: "Napraw w CLI", ja: "CLIで修正", zh: "在 CLI 中修复" },
    tipFixCli:  { en: "Hand off screenshot + System Debug diagnosis to interactive omarchy-agent to review and apply fixes", no: "Send skjermbildet og System Debug-analysen til interaktiv omarchy-agent for å gå gjennom og fikse", sv: "Skicka diagnosen till interaktiv omarchy-agent för åtgärd", da: "Send diagnosen til interaktiv omarchy-agent til rettelse", de: "Diagnose an interaktiven omarchy-agent zur Behebung übergeben", fr: "Transférer le diagnostic vers omarchy-agent pour corriger", es: "Enviar diagnóstico a omarchy-agent para revisar y corregir", pt: "Enviar diagnóstico para omarchy-agent revisar e corrigir", it: "Invia diagnosi a omarchy-agent per applicare le correzioni", pl: "Przekaż diagnozę do interaktywnego omarchy-agent", ja: "診断結果を対話型 omarchy-agent に渡して修正する", zh: "将截图和诊断交接给交互式 omarchy-agent 审查并修复" },
    tipSysDebugHud: { en: "System Debug ON — read-only diagnostics (journalctl, failed units, Hyprland, disk/RAM) attached. Click to disable.", no: "System Debug PÅ — lesebeskyttet diagnostikk (journalctl, feilede tjenester, Hyprland, disk/RAM) legges ved. Klikk for å slå av.", sv: "System Debug PÅ — skrivskyddad diagnostik bifogas. Klicka för att stänga av.", da: "System Debug TIL — skrivebeskyttet diagnostik vedhæftes. Klik for at slå fra.", de: "System-Debug AN — Nur-Lese-Diagnose wird angehängt. Klicken zum Ausschalten.", fr: "System Debug ON — diagnostic lecture seule joint. Cliquer pour désactiver.", es: "System Debug SÍ — diagnóstico de solo lectura adjunto. Clic para desactivar.", pt: "System Debug ON — diagnóstico somente leitura anexado. Clique para desativar.", it: "System Debug ON — diagnostica sola lettura allegata. Clicca per disattivare.", pl: "System Debug WŁ — diagnostyka tylko do odczytu. Kliknij, aby wyłączyć.", ja: "システムデバッグON — 読み取り専用診断を添付。クリックでOFF。", zh: "系统调试已开启 — 附加只读系统诊断。点击关闭。" },
    pin:        { en: "+ Pin", no: "+ Lagre", sv: "+ Fäst", da: "+ Fastgør", de: "+ Pin", fr: "+ Épingler", es: "+ Fijar", pt: "+ Fixar", it: "+ Fissa", pl: "+ Przypnij", ja: "+ 保存", zh: "+ 固定" },
    send:       { en: "Send", no: "Send", sv: "Skicka", da: "Send", de: "Senden", fr: "Envoyer", es: "Enviar", pt: "Enviar", it: "Invia", pl: "Wyślij", ja: "送信", zh: "发送" },
    placeholder:{ en: "Ask about the screenshot, or type a prompt and click '+ Pin' to save it…", no: "Spør om bildet, eller skriv et eget spørsmål og trykk '+ Lagre'…", sv: "Fråga om bilden, eller skriv en fråga och klicka '+ Fäst'…", da: "Spørg om billedet, eller skriv et spørgsmål og tryk '+ Fastgør'…", de: "Frage zum Bild stellen oder per '+ Pin' als Favorit speichern…", fr: "Posez une question sur l'image ou cliquez sur '+ Épingler'…", es: "Pregunta sobre la captura o haz clic en '+ Fijar' para guardar…", pt: "Pergunte sobre a imagem ou clique em '+ Fixar' para salvar…", it: "Chiedi dell'immagine o clicca su '+ Fissa' per salvare…", pl: "Zapytaj o zrzut ekranu lub kliknij '+ Przypnij', aby zapisać…", ja: "画像について質問するか、入力して「+ 保存」でピン留め…", zh: "询问关于截图的问题，或输入后点击“+ 固定”保存为快捷按钮…" },
    defaultHint:{ en: "Tip: Type a favorite question and click '★ + Pin' to create your own buttons.", no: "Tips: Skriv et favorittspørsmål og trykk '★ + Lagre' for å lage dine egne knapper.", sv: "Tips: Skriv en favoritfråga och klicka '★ + Fäst' för egna knappar.", da: "Tip: Skriv et favoritspørgsmål og klik '★ + Fastgør' for egne knapper.", de: "Tipp: Frage eingeben und '★ + Pin' klicken, um eigene Buttons zu erstellen.", fr: "Astuce : Tapez une question et cliquez sur '★ + Épingler' pour créer vos boutons.", es: "Consejo: Escribe una pregunta y pulsa '★ + Fijar' para crear tus propios botones.", pt: "Dica: Digite uma pergunta e clique em '★ + Fixar' para criar seus botões.", it: "Consiglio: Scrivi una domanda e clicca '★ + Fissa' per creare i tuoi pulsanti.", pl: "Wskazówka: Wpisz pytanie i kliknij '★ + Przypnij', aby utworzyć własny przycisk.", ja: "ヒント: よく使う質問を入力して「★ + 保存」を押すと専用ボタンを作れます。", zh: "提示：输入常用问题并点击“★ + 固定”即可创建自定义快捷按钮。" },
    tipStatusReady:    { en: "Screenshot loaded — type a question or turn Auto ON to analyze", no: "Skjermbilde klart — skriv et spørsmål eller skru på Auto for analyse", sv: "Skärmbild klar — skriv en fråga eller slå på Auto för analys", da: "Skærmbillede klar — skriv et spørgsmål eller slå Auto til", de: "Screenshot bereit — Frage stellen oder Auto einschalten", fr: "Capture prête — posez une question ou activez Auto", es: "Captura lista — escribe una pregunta o activa Auto", pt: "Captura pronta — faça uma pergunta ou ative Auto", it: "Screenshot pronto — fai una domanda o attiva Auto", pl: "Zrzut gotowy — zadaj pytanie lub włącz Auto", ja: "準備完了 — 質問を入力するか自動解析をONにしてください", zh: "截图就绪 — 输入问题或开启自动分析" },
    tipStatusScanning: { en: "AI model is currently analyzing the screenshot", no: "AI-modellen analyserer skjermbildet nå", sv: "AI-modellen analyserar skärmbilden nu", da: "AI-modellen analyserer skærmbilledet nu", de: "Das KI-Modell analysiert das Bildschirmfoto", fr: "Le modèle IA analyse la capture d'écran", es: "El modelo de IA está analizando la captura", pt: "O modelo de IA está analisando a captura", it: "Il modello IA sta analizzando lo screenshot", pl: "Model AI analizuje zrzut ekranu", ja: "AIモデルがスクリーンショットを解析中です", zh: "AI模型正在分析截图" },
    tipStatusPaused:   { en: "Analysis is paused — click Resume to continue", no: "Analysen er pauset — trykk Fortsett for å kjøre videre", sv: "Analysen är pausad — klicka Fortsätt för att fortsätta", da: "Analysen er pauset — klik Fortsæt for at fortsætte", de: "Analyse pausiert — auf Weiter klicken zum Fortfahren", fr: "Analyse en pause — cliquez sur Reprendre", es: "Análisis pausado — pulsa Reanudar para continuar", pt: "Análise pausada — clique em Retomar", it: "Analisi in pausa — clicca Riprendi", pl: "Analiza wstrzymana — kliknij Wznów", ja: "解析を一時停止中 — 「再開」で続行します", zh: "分析已暂停 — 点击“继续”恢复" },
    tipStatusViewed:   { en: "Answer ready — ask a follow-up or copy the result", no: "Svar klart — still oppfølgingsspørsmål eller kopier svaret", sv: "Svar klart — ställ en följdfråga eller kopiera svaret", da: "Svar klar — stil et opfølgningsspørgsmål eller kopiér", de: "Antwort bereit — Rückfrage stellen oder kopieren", fr: "Réponse prête — posez une suite ou copiez", es: "Respuesta lista — pregunta más o copia el resultado", pt: "Resposta pronta — faça outra pergunta ou copie", it: "Risposta pronta — fai un'altra domanda o copia", pl: "Odpowiedź gotowa — dopytaj lub skopiuj wynik", ja: "回答完了 — 追加質問するか結果をコピーできます", zh: "回答就绪 — 可继续追问或复制结果" },
    tipStatusIdle:     { en: "No screenshot loaded — press Super+Shift+Print to capture", no: "Ingen skjermbilde lastet — trykk Super+Shift+Print for å ta ett", sv: "Ingen skärmbild — tryck Super+Shift+Print för att fånga", da: "Intet skærmbillede — tryk Super+Shift+Print", de: "Kein Bild geladen — Super+Shift+Print zum Aufnehmen", fr: "Aucune capture — appuyez sur Super+Shift+Print", es: "Sin captura — pulsa Super+Shift+Print", pt: "Sem captura — pressione Super+Shift+Print", it: "Nessuno screenshot — premi Super+Shift+Print", pl: "Brak zrzutu — naciśnij Super+Shift+Print", ja: "画像なし — Super+Shift+Print でキャプチャ", zh: "未加载截图 — 按 Super+Shift+Print 截取" },
    tipAuto:           { en: "Recommended for quick lookups: analyzes immediately on capture, gives a summary, and auto-generates 3 tailored follow-up questions (✦) you can click without typing. Turn OFF to annotate or type first.", no: "Smart for rask hjelp: analyserer bildet med én gang, gir en kort oppsummering og autogenererer 3 relevante oppfølgingsspørsmål (✦) du kan trykke på uten å skrive. Slå AV hvis du vil tegne eller spørre først.", sv: "Smart för snabb hjälp: analyserar direkt vid fångst, ger sammanfattning och autogenererar 3 skräddarsydda följdfrågor (✦) du kan klicka på direkt. Stäng AV om du vill rita eller skriva först.", da: "Smart til hurtig hjælp: analyserer med det samme, giver et resumé og autogenererer 3 relevante opfølgningsspørgsmål (✦) du kan klikke på uden at skrive. Slå FRA hvis du vil tegne eller skrive først.", de: "Empfohlen für schnelle Antworten: analysiert sofort, fasst zusammen und generiert automatisch 3 passende Rückfragen (✦) zum Anklicken ohne Tippen. Ausschalten, um erst zu markieren oder zu fragen.", fr: "Idéal pour aller vite : analyse dès la capture, résume et génère automatiquement 3 questions de suivi (✦) cliquables sans taper. Désactivez pour annoter ou écrire d'abord.", es: "Ideal para consultas rápidas: analiza al instante, resume y autogenera 3 preguntas de seguimiento (✦) listas para hacer clic sin escribir. Desactívalo si prefieres anotar o escribir primero.", pt: "Ótimo para consultas rápidas: analisa na hora, resume e gera automaticamente 3 perguntas sugeridas (✦) clicáveis sem digitar. Desative se preferir anotar ou perguntar antes.", it: "Consigliato per risposte rapide: analizza subito, riassume e genera automaticamente 3 domande di approfondimento (✦) cliccabili senza scrivere. Disattiva per annotare o scrivere prima.", pl: "Polecane do szybkiej pomocy: analizuje od razu, podsumowuje i automatycznie generuje 3 trafne pytania uzupełniające (✦) do kliknięcia bez pisania. Wyłącz, jeśli wolisz najpierw zaznaczyć lub napisać.", ja: "素早い確認に便利：撮影直後に要約し、入力不要でクリックできる3つの追質問（✦）を自動生成します。先に矢印描画や入力をしたい場合はOFFにしてください。", zh: "适合快速查看：截图后立即总结，并自动生成 3 个可一键点击的追问（✦），无需打字。如需先标注或手写问题可关闭。" },
    tipModelPill:      { en: "Click to cycle through available AI vision models", no: "Klikk for å bytte mellom tilgjengelige AI-modeller", sv: "Klicka för att växla mellan AI-modeller", da: "Klik for at skifte mellem AI-modeller", de: "Klicken, um zwischen den KI-Modellen zu wechseln", fr: "Cliquez pour changer de modèle IA", es: "Haz clic para cambiar entre modelos de IA", pt: "Clique para alternar entre os modelos de IA", it: "Clicca per cambiare modello IA", pl: "Kliknij, aby przełączyć model AI", ja: "クリックでAIビジョンモデルを切り替え", zh: "点击切换可用的 AI 视觉模型" },
    tipStealth:        { en: "Stealth mode: analyze silently in background and notify without opening HUD", no: "Stillemodus: analyser i bakgrunnen og vis svaret som varsel uten vindu", sv: "Tyst läge: analysera i bakgrunden och visa svar som notis utan fönster", da: "Stilletilstand: analysér i baggrunden og vis svar som notifikation", de: "Still-Modus: im Hintergrund analysieren und als Benachrichtigung anzeigen", fr: "Mode discret : analyser en arrière-plan et afficher une notification", es: "Modo sigilo: analiza en segundo plano y avisa sin abrir la ventana", pt: "Modo discreto: analisa em segundo plano e notifica sem abrir a janela", it: "Modalità silenziosa: analizza in background e notifica senza finestra", pl: "Tryb cichy: analizuj w tle i pokaż wynik jako powiadomienie", ja: "ステルスモード: ウィンドウを開かずバックグラウンド解析し通知で表示", zh: "静默模式：后台静默分析并通过通知显示结果" },
    tipImage:          { en: "Show or hide screenshot preview and arrow/box/crop tools", no: "Vis eller skjul forhåndsvisning og verktøy for pil, boks og beskjæring", sv: "Visa eller dölj förhandsvisning och rit-/beskärningsverktyg", da: "Vis eller skjul forhåndsvisning og tegne-/beskæringsværktøjer", de: "Vorschau sowie Pfeil-, Rahmen- und Zuschneidewerkzeuge ein-/ausblenden", fr: "Afficher ou masquer l'aperçu et les outils d'annotation/recadrage", es: "Mostrar u ocultar la vista previa y herramientas de anotación/recorte", pt: "Mostrar ou ocultar pré-visualização e ferramentas de anotação/recorte", it: "Mostra o nascondi l'anteprima e gli strumenti di annotazione/ritaglio", pl: "Pokaż lub ukryj podgląd oraz narzędzia strzałki, ramki i przycinania", ja: "プレビューと矢印・枠・切り抜きツールを表示/非表示", zh: "显示或隐藏截图预览与标注/裁剪工具" },
    tipOmasnap:        { en: "Open screenshot in Omasnap for full annotation editing", no: "Åpne skjermbildet i Omasnap for full redigering", sv: "Öppna skärmbilden i Omasnap för full redigering", da: "Åbn skærmbilledet i Omasnap til fuld redigering", de: "Screenshot in Omasnap für vollständige Bearbeitung öffnen", fr: "Ouvrir la capture dans Omasnap pour l'édition complète", es: "Abrir la captura en Omasnap para edición completa", pt: "Abrir a captura no Omasnap para edição completa", it: "Apri lo screenshot in Omasnap per la modifica completa", pl: "Otwórz zrzut ekranu w Omasnap do pełnej edycji", ja: "Omasnapで開いてフル編集する", zh: "在 Omasnap 中打开以进行完整编辑" },
    tipCli:            { en: "Hand off image & conversation to your terminal agent (omarchy-agent)", no: "Send bildet og samtalen videre til terminal-agenten (omarchy-agent)", sv: "Skicka vidare bild och konversation till terminal-agenten", da: "Send billede og samtale videre til terminal-agenten", de: "Bild und Verlauf an den Terminal-Agenten übergeben", fr: "Transférer l'image et le contexte vers l'agent terminal", es: "Continuar con la imagen y el contexto en el agente de terminal", pt: "Continuar a conversa com a imagem no agente de terminal", it: "Continua con immagine e contesto nell'agente da terminale", pl: "Przekaż obraz i rozmowę do agenta w terminalu", ja: "画像と会話履歴をターミナルエージェントに引き継ぐ", zh: "将图像和对话上下文交接给终端代理" },
    tipSettings:       { en: "Open settings for AI models, reasoning and language (Tab)", no: "Åpne innstillinger for AI-modell, resonnering og språk (Tab)", sv: "Öppna inställningar för modell, resonemang och språk (Tab)", da: "Åbn indstillinger for model, ræsonnement og sprog (Tab)", de: "Einstellungen für Modelle, Begründung und Sprache öffnen (Tab)", fr: "Ouvrir les paramètres de modèle, raisonnement et langue (Tab)", es: "Abrir ajustes de modelos, razonamiento e idioma (Tab)", pt: "Abrir configurações de modelos, raciocínio e idioma (Tab)", it: "Apri impostazioni per modelli, ragionamento e lingua (Tab)", pl: "Otwórz ustawienia modeli, toku myślenia i języka (Tab)", ja: "モデル・推論・言語設定を開く（Tab）", zh: "打开模型、推理与语言设置（Tab）" },
    tipClose:          { en: "Close Aeye HUD (Esc)", no: "Lukk Aeye-vinduet (Esc)", sv: "Stäng Aeye (Esc)", da: "Luk Aeye (Esc)", de: "Aeye schließen (Esc)", fr: "Fermer Aeye (Esc)", es: "Cerrar Aeye (Esc)", pt: "Fechar o Aeye (Esc)", it: "Chiudi Aeye (Esc)", pl: "Zamknij Aeye (Esc)", ja: "Aeye を閉じる（Esc）", zh: "关闭 Aeye（Esc）" },
    tipDoneEdit:       { en: "Return to Aeye and reload the edited screenshot", no: "Gå tilbake til Aeye og last inn det redigerte skjermbildet", sv: "Återgå till Aeye och ladda om den redigerade bilden", da: "Vend tilbage til Aeye og genindlæs det redigerede billede", de: "Zurück zu Aeye und bearbeitetes Bild neu laden", fr: "Revenir à Aeye et recharger l'image modifiée", es: "Volver a Aeye y recargar la imagen editada", pt: "Voltar ao Aeye e recarregar a imagem editada", it: "Torna a Aeye e ricarica l'immagine modificata", pl: "Wróć do Aeye i przeładuj edytowany zrzut", ja: "Aeyeに戻り編集後の画像を再読み込み", zh: "返回 Aeye 并重新加载编辑后的截图" },
    tipReason:         { en: "Ask the model to state which visual detail in the image drives its answer", no: "Be modellen forklare hvilken detalj i bildet svaret bygger på", sv: "Be modellen förklara vilken detalj i bilden svaret bygger på", da: "Bed modellen forklare hvilken detalje i billedet svaret bygger på", de: "Modell nennt zuerst das ausschlaggebende Bilddetail vor der Antwort", fr: "Demander au modèle d'indiquer quel détail visuel motive sa réponse", es: "Pedir al modelo que indique qué detalle visual fundamenta su respuesta", pt: "Pedir ao modelo para explicar qual detalhe visual motiva a resposta", it: "Chiedi al modello quale dettaglio visivo guida la risposta", pl: "Poproś model o wskazanie szczegółu obrazu, na którym opiera odpowiedź", ja: "回答の根拠となった画像上の箇所を1行で示させる", zh: "让模型先说明回答所依据的图像细节" },
    tipLocale:         { en: "Switch language for both the UI and AI responses", no: "Bytt språk for både grensesnittet og AI-svarene", sv: "Byt språk för både gränssnittet och AI-svaren", da: "Skift sprog for både brugerfladen og AI-svarene", de: "Sprache für Oberfläche und KI-Antworten wechseln", fr: "Changer la langue de l'interface et des réponses IA", es: "Cambiar el idioma de la interfaz y las respuestas de la IA", pt: "Alterar o idioma da interface e das respostas da IA", it: "Cambia la lingua dell'interfaccia e delle risposte IA", pl: "Zmień język interfejsu oraz odpowiedzi AI", ja: "UIとAI回答の言語を切り替える", zh: "切换界面和 AI 回复语言" },
    tipArrow:          { en: "Draw an arrow on the image — rendered onto the shot sent to the AI", no: "Tegn en pil på bildet — blir med på bildet som sendes til AI-en", sv: "Rita en pil på bilden — följer med till AI-modellen", da: "Tegn en pil på billedet — sendes med til AI-modellen", de: "Pfeil ins Bild zeichnen — wird für die KI mitgerendert", fr: "Dessiner une flèche — incluse dans l'image envoyée à l'IA", es: "Dibuja una flecha — se incluye en la imagen enviada a la IA", pt: "Desenhe uma seta — incluída na imagem enviada à IA", it: "Disegna una freccia — inclusa nell'immagine inviata all'IA", pl: "Narysuj strzałkę — zostanie wysłana razem z obrazem do AI", ja: "画像に矢印を描画（AIに送る画像に反映されます）", zh: "在图上画箭头（会一同渲染发送给 AI）" },
    tipBox:            { en: "Draw a highlight box on the image — rendered onto the shot sent to the AI", no: "Tegn en boks på bildet — blir med på bildet som sendes til AI-en", sv: "Rita en ram på bilden — följer med till AI-modellen", da: "Tegn en boks på billedet — sendes med til AI-modellen", de: "Rahmen ins Bild zeichnen — wird für die KI mitgerendert", fr: "Dessiner un cadre — inclus dans l'image envoyée à l'IA", es: "Dibuja un recuadro — se incluye en la imagen enviada a la IA", pt: "Desenhe um quadro — incluído na imagem enviada à IA", it: "Disegna un riquadro — incluso nell'immagine inviata all'IA", pl: "Narysuj ramkę — zostanie wysłana razem z obrazem do AI", ja: "画像に枠を描画（AIに送る画像に反映されます）", zh: "在图上画方框（会一同渲染发送给 AI）" },
    tipCrop:           { en: "Drag to select a smaller region to crop before asking", no: "Dra for å merke et mindre område du vil beskjære til", sv: "Dra för att markera ett mindre område att beskära till", da: "Træk for at markere et mindre område til beskæring", de: "Bereich aufziehen, um das Bild zuzuschneiden", fr: "Glissez pour sélectionner une zone à recadrer", es: "Arrastra para seleccionar una zona y recortarla", pt: "Arraste para selecionar uma região para recortar", it: "Trascina per selezionare un'area da ritagliare", pl: "Przeciągnij, aby zaznaczyć obszar do przycięcia", ja: "ドラッグして切り抜く範囲を選択", zh: "拖动选择要裁剪的区域" },
    tipApplyCrop:      { en: "Crop the screenshot to the selected rectangle", no: "Beskjær skjermbildet til det markerte området", sv: "Beskär skärmbilden till det markerade området", da: "Beskær skærmbilledet til det markerede område", de: "Ausgewählten Bereich jetzt zuschneiden", fr: "Appliquer le recadrage sélectionné", es: "Recortar la captura al área seleccionada", pt: "Aplicar o recorte selecionado", it: "Ritaglia lo screenshot all'area selezionata", pl: "Przytnij zrzut do zaznaczonego prostokąta", ja: "選択範囲でスクリーンショットを切り抜く", zh: "将截图裁剪为选定区域" },
    tipClearMarks:     { en: "Remove all drawn arrows, boxes and crop selection", no: "Fjern alle tegnede piler, bokser og utsnitt", sv: "Ta bort alla pilar, ramar och beskärningsval", da: "Fjern alle pile, bokse og beskæringsvalg", de: "Alle Pfeile, Rahmen und den Zuschnitt entfernen", fr: "Effacer toutes les flèches, cadres et le recadrage", es: "Eliminar todas las flechas, recuadros y recorte", pt: "Remover todas as setas, quadros e recorte", it: "Rimuovi tutte le frecce, riquadri e ritagli", pl: "Usuń wszystkie strzałki, ramki i zaznaczenie", ja: "描画した矢印・枠・切り抜き選択をすべて消去", zh: "清除所有绘制的箭头、方框和裁剪框" },
    tipPause:          { en: "Pause or resume the active AI analysis", no: "Sett pågående AI-analyse på pause eller fortsett", sv: "Pausa eller återuppta pågående analys", da: "Sæt analysen på pause eller genoptag", de: "Laufende Analyse pausieren oder fortsetzen", fr: "Mettre en pause ou reprendre l'analyse", es: "Pausar o reanudar el análisis actual", pt: "Pausar ou retomar a análise ativa", it: "Metti in pausa o riprendi l'analisi", pl: "Wstrzymaj lub wznów bieżącą analizę", ja: "実行中の解析を一時停止/再開", zh: "暂停或继续当前 AI 分析" },
    tipStop:           { en: "Cancel the active AI request (Esc)", no: "Avbryt pågående AI-forespørsel (Esc)", sv: "Avbryt pågående AI-förfrågan (Esc)", da: "Annuller den igangværende forespørgsel (Esc)", de: "Laufende KI-Anfrage abbrechen (Esc)", fr: "Annuler la requête IA en cours (Esc)", es: "Cancelar la solicitud actual (Esc)", pt: "Cancelar a solicitação atual (Esc)", it: "Annulla la richiesta IA attiva (Esc)", pl: "Anuluj bieżące zapytanie AI (Esc)", ja: "実行中のAIリクエストを中止（Esc）", zh: "取消当前 AI 请求（Esc）" },
    tipCopy:           { en: "Copy the AI answer to your clipboard", no: "Kopier AI-svaret til utklippstavlen", sv: "Kopiera svaret till urklipp", da: "Kopiér svaret til udklipsholderen", de: "Antwort in die Zwischenablage kopieren", fr: "Copier la réponse dans le presse-papiers", es: "Copiar la respuesta al portapapeles", pt: "Copiar a resposta para a área de transferência", it: "Copia la risposta negli appunti", pl: "Skopiuj odpowiedź do schowka", ja: "回答をクリップボードにコピー", zh: "复制回答到剪贴板" },
    tipAiChip:         { en: "Click to use this AI-suggested follow-up question", no: "Klikk for å fylle inn dette oppfølgingsforslaget", sv: "Klicka för att använda detta förslag", da: "Klik for at bruge dette forslag", de: "Klicken, um diese vorgeschlagene Rückfrage zu übernehmen", fr: "Cliquez pour utiliser cette suggestion", es: "Haz clic para usar esta pregunta sugerida", pt: "Clique para usar esta sugestão", it: "Clicca per usare questa domanda suggerita", pl: "Kliknij, aby użyć tej podpowiedzi", ja: "クリックしてAI提案の質問を入力欄にセット", zh: "点击使用此 AI 推荐追问" },
    tipCustomChip:     { en: "Click to use pinned prompt · Right-click or × to delete", no: "Klikk for å bruke lagret spørsmål · Høyreklikk eller × for å slette", sv: "Klicka för att använda · Högerklicka eller × för att ta bort", da: "Klik for at bruge · Højreklik eller × for at slette", de: "Klicken zum Verwenden · Rechtsklick oder × zum Löschen", fr: "Cliquez pour utiliser · Clic droit ou × pour supprimer", es: "Clic para usar · Clic derecho o × para eliminar", pt: "Clique para usar · Botão direito ou × para excluir", it: "Clicca per usare · Tasto destro o × per eliminare", pl: "Kliknij, aby użyć · PPM lub × aby usunąć", ja: "クリックで使用 · 右クリックまたは×で削除", zh: "点击使用固定提示 · 右键或 × 删除" },
    tipClearInput:     { en: "Clear the input field", no: "Tøm tekstfeltet", sv: "Rensa textfältet", da: "Ryd tekstfeltet", de: "Eingabefeld leeren", fr: "Vider le champ de saisie", es: "Borrar el campo de texto", pt: "Limpar o campo de texto", it: "Svuota il campo di testo", pl: "Wyczyść pole tekstowe", ja: "入力欄をクリア", zh: "清空输入框" },
    tipPin:            { en: "Save the typed question as a permanent quick-action button", no: "Lagre spørsmålet i feltet som en fast hurtigknapp", sv: "Spara frågan som en permanent snabbknapp", da: "Gem spørgsmålet som en fast genvejsknap", de: "Eingetippte Frage als dauerhaften Schnellbutton speichern", fr: "Enregistrer la question comme bouton rapide permanent", es: "Guardar la pregunta como botón rápido permanente", pt: "Salvar a pergunta como botão rápido permanente", it: "Salva la domanda come pulsante rapido permanente", pl: "Zapisz wpisane pytanie jako stały przycisk", ja: "入力中の質問を常設のクイックボタンとして保存", zh: "将输入的问题保存为永久快捷按钮" },
    tipSend:           { en: "Send your question and screenshot to the AI (Enter)", no: "Send spørsmålet og bildet til AI-en (Enter)", sv: "Skicka frågan och bilden till AI:n (Enter)", da: "Send spørgsmålet og billedet til AI'en (Enter)", de: "Frage und Screenshot an die KI senden (Enter)", fr: "Envoyer la question et l'image à l'IA (Entrée)", es: "Enviar la pregunta y la captura a la IA (Enter)", pt: "Enviar a pergunta e a captura para a IA (Enter)", it: "Invia la domanda e lo screenshot all'IA (Invio)", pl: "Wyślij pytanie i zrzut ekranu do AI (Enter)", ja: "質問とスクリーンショットをAIに送信（Enter）", zh: "将问题和截图发送给 AI（Enter）" },
    tipModelFlash:     { en: "Gemini Flash — fast everyday vision analysis", no: "Gemini Flash — rask bildeanalyse til hverdagsbruk", sv: "Gemini Flash — snabb vardagsanalys", da: "Gemini Flash — hurtig hverdagsanalyse", de: "Gemini Flash — schnelle Alltagsanalyse", fr: "Gemini Flash — analyse visuelle rapide", es: "Gemini Flash — análisis rápido para el día a día", pt: "Gemini Flash — análise rápida do dia a dia", it: "Gemini Flash — analisi rapida quotidiana", pl: "Gemini Flash — szybka codzienna analiza", ja: "Gemini Flash — 高速な普段使い向けモデル", zh: "Gemini Flash — 快速日常视觉分析" },
    tipModelArgon:     { en: "Gemini Argon — deeper visual reasoning for complex screens", no: "Gemini Argon — dypere resonnering for komplekse skjermbilder", sv: "Gemini Argon — djupare analys för komplexa bilder", da: "Gemini Argon — dybere analyse af komplekse billeder", de: "Gemini Argon — tiefere Analyse für komplexe Inhalte", fr: "Gemini Argon — raisonnement approfondi", es: "Gemini Argon — razonamiento profundo para pantallas complejas", pt: "Gemini Argon — raciocínio profundo para telas complexas", it: "Gemini Argon — ragionamento approfondito", pl: "Gemini Argon — głębsze rozumowanie wizualne", ja: "Gemini Argon — 複雑な画面向けの深い推論モデル", zh: "Gemini Argon — 适用于复杂画面的深度推理" },
    tipModelSonnet:    { en: "Claude Sonnet 5.5 — strong for code, logs & stacktraces", no: "Claude Sonnet 5.5 — sterk på kode, logger og feilmeldinger", sv: "Claude Sonnet 5.5 — stark på kod, loggar och fel", da: "Claude Sonnet 5.5 — stærk til kode, logs og fejl", de: "Claude Sonnet 5.5 — stark bei Code, Logs & Stacktraces", fr: "Claude Sonnet 5.5 — idéal pour code et erreurs", es: "Claude Sonnet 5.5 — ideal para código y errores", pt: "Claude Sonnet 5.5 — ótimo para código e logs", it: "Claude Sonnet 5.5 — ottimo per codice ed errori", pl: "Claude Sonnet 5.5 — świetny do kodu i logów", ja: "Claude Sonnet 5.5 — コード・ログ・エラー解析に強い", zh: "Claude Sonnet 5.5 — 擅长代码、日志和报错分析" },
    tipModelGrok:      { en: "Grok 4.7 — direct xAI vision model", no: "Grok 4.7 — direkte xAI-visjonsmodell", sv: "Grok 4.7 — direkt xAI-modell", da: "Grok 4.7 — direkte xAI-model", de: "Grok 4.7 — direktes xAI-Modell", fr: "Grok 4.7 — modèle vision direct de xAI", es: "Grok 4.7 — modelo directo de xAI", pt: "Grok 4.7 — modelo direto da xAI", it: "Grok 4.7 — modello diretto xAI", pl: "Grok 4.7 — bezpośredni model xAI", ja: "Grok 4.7 — xAIのダイレクトモデル", zh: "Grok 4.7 — xAI 直连视觉模型" },
    tipModelOpenai:    { en: "GPT-4o — OpenAI multimodal vision model", no: "GPT-4o — OpenAIs multimodale visjonsmodell", sv: "GPT-4o — OpenAIs multimodala modell", da: "GPT-4o — OpenAIs multimodale model", de: "GPT-4o — multimodales OpenAI-Modell", fr: "GPT-4o — modèle vision d'OpenAI", es: "GPT-4o — modelo visual de OpenAI", pt: "GPT-4o — modelo visual da OpenAI", it: "GPT-4o — modello visivo di OpenAI", pl: "GPT-4o — multimodalny model OpenAI", ja: "GPT-4o — OpenAIのマルチモーダルモデル", zh: "GPT-4o — OpenAI 多模态视觉模型" },
    tipMinimize:       { en: "Minimize to top bar — keep running in background and notify when ready", no: "Minimer til toppbaren — la analysen kjøre i bakgrunnen og få varsel når klar", sv: "Minimera till toppanelen — fortsätt i bakgrunden och avisera när klart", da: "Minimer til topbaren — fortsæt i baggrunden og giv besked når klar", de: "In die Top-Bar minimieren — läuft im Hintergrund weiter", fr: "Réduire dans la barre — continue en arrière-plan et notifie", es: "Minimizar a la barra — sigue en segundo plano y avisa al terminar", pt: "Minimizar para a barra — continua em segundo plano e notifica", it: "Riduci nella barra — continua in background e notifica", pl: "Minimalizuj do paska — działa w tle i powiadamia po zakończeniu", ja: "バーに最小化（バックグラウンド実行し完了時に通知）", zh: "最小化到顶栏（后台继续运行并在完成后通知）" },
    notifReadyTitle:   { en: "Answer ready", no: "Svar klart", sv: "Svar klart", da: "Svar klar", de: "Antwort bereit", fr: "Réponse prête", es: "Respuesta lista", pt: "Resposta pronta", it: "Risposta pronta", pl: "Odpowiedź gotowa", ja: "回答完了", zh: "回答就绪" },
    notifReadyBody:    { en: "Click to open Aeye and read the answer.", no: "Klikk for å åpne Aeye og lese svaret.", sv: "Klicka för att öppna Aeye och läsa svaret.", da: "Klik for at åbne Aeye og læse svaret.", de: "Klicken, um Aeye zu öffnen und die Antwort zu lesen.", fr: "Cliquez pour ouvrir Aeye et lire la réponse.", es: "Haz clic para abrir Aeye y leer la respuesta.", pt: "Clique para abrir o Aeye e ler a resposta.", it: "Clicca per aprire Aeye e leggere la risposta.", pl: "Kliknij, aby otworzyć Aeye i przeczytać odpowiedź.", ja: "クリックして Aeye を開き回答を表示します。", zh: "点击打开 Aeye 查看回答。" },
    notifOpenBtn:      { en: "View Answer", no: "Vis svar", sv: "Visa svar", da: "Vis svar", de: "Antwort ansehen", fr: "Voir la réponse", es: "Ver respuesta", pt: "Ver resposta", it: "Mostra risposta", pl: "Zobacz odpowiedź", ja: "回答を表示", zh: "查看回答" },
    recCode:           { en: "Code / error detected", no: "Kode / feilmelding oppdaget", sv: "Kod / fel upptäckt", da: "Kode / fejl fundet", de: "Code / Fehler erkannt", fr: "Code / erreur détecté", es: "Código / error detectado", pt: "Código / erro detectado", it: "Codice / errore rilevato", pl: "Wykryto kod / błąd", ja: "コード・エラーを検出", zh: "检测到代码/报错" },
    recGrammar:        { en: "Writing / grammar detected", no: "Tekst / grammatikk oppdaget", sv: "Text / grammatik upptäckt", da: "Tekst / grammatik fundet", de: "Text / Grammatik erkannt", fr: "Texte / grammaire détecté", es: "Texto / gramática detectado", pt: "Texto / gramática detectado", it: "Testo / grammatica rilevato", pl: "Wykryto tekst / gramatykę", ja: "文章・文法を検出", zh: "检测到文本/语法" },
    recRealtime:       { en: "Live / current info detected", no: "Sanntids- / fersk info oppdaget", sv: "Aktuell info upptäckt", da: "Aktuel info fundet", de: "Aktuelle Info erkannt", fr: "Info récente détectée", es: "Info actual detectada", pt: "Info recente detectada", it: "Info recente rilevata", pl: "Wykryto bieżące dane", ja: "最新・リアルタイム情報を検出", zh: "检测到实时/最新信息" },
    recDeep:           { en: "Complex chart / diagram detected", no: "Kompleks graf / diagram oppdaget", sv: "Komplext diagram upptäckt", da: "Komplekst diagram fundet", de: "Komplexes Diagramm erkannt", fr: "Graphique complexe détecté", es: "Gráfico complejo detectado", pt: "Gráfico complexo detectado", it: "Grafico complesso rilevato", pl: "Wykryto złożony wykres", ja: "複雑な図表を検出", zh: "检测到复杂图表" },
    recSwitchTo:       { en: "Switch to", no: "Bytt til", sv: "Byt till", da: "Skift til", de: "Wechseln zu", fr: "Passer à", es: "Cambiar a", pt: "Trocar para", it: "Passa a", pl: "Przełącz na", ja: "切替:", zh: "切换到" },
    tipRecModel:       { en: "Auto-analyze noticed a better active AI model for this screenshot — click to switch before asking your follow-up", no: "Auto-analyser merket at en annen aktiv AI-modell er sterkere på denne typen skjermbilde — klikk for å bytte før neste spørsmål", sv: "Auto-analys hittade en bättre aktiv AI-modell för denna skärmbild — klicka för att byta", da: "Auto-analyse fandt en bedre aktiv AI-model til dette billede — klik for at skifte", de: "Auto-Analyse empfiehlt ein besseres aktives KI-Modell für diesen Screenshot — zum Wechseln klicken", fr: "L'analyse auto recommande un meilleur modèle IA actif pour cette capture — cliquez pour changer", es: "Auto-análisis recomienda un mejor modelo IA activo para esta captura — haz clic para cambiar", pt: "A auto-análise recomenda um modelo de IA ativo melhor para esta captura — clique para trocar", it: "L'auto-analisi consiglia un modello IA attivo migliore per questo screenshot — clicca per cambiare", pl: "Auto-analiza sugeruje lepszy aktywny model AI dla tego zrzutu — kliknij, aby przełączyć", ja: "この画面により適した有効モデルが見つかりました — クリックして切り替えます", zh: "自动分析发现更适合当前截图的已启用模型 — 点击切换" },
    tipDragHud:        { en: "Drag header to move HUD anywhere · Double-click to snap back · Click outside to interact with other apps", no: "Dra i topplinjen for å flytte HUD-en fritt · Dobbelklikk for å nullstille · Klikk utenfor for å jobbe i andre vinduer", sv: "Dra i rubriken för att flytta · Dubbelklicka för att återställa · Klicka utanför för andra appar", da: "Træk i toppen for at flytte · Dobbeltklik for at nulstille · Klik udenfor for andre vinduer", de: "Leiste ziehen zum Verschieben · Doppelklick zum Zurücksetzen · Außerhalb klicken für andere Apps", fr: "Glissez l'en-tête pour déplacer · Double-clic pour réinitialiser · Cliquez hors du HUD pour vos apps", es: "Arrastra la barra para mover · Doble clic para restablecer · Haz clic fuera para usar otras apps", pt: "Arraste o topo para mover · Duplo clique para resetar · Clique fora para usar outros apps", it: "Trascina l'intestazione per spostare · Doppio clic per ripristinare · Clicca fuori per altre app", pl: "Przeciągnij nagłówek, aby przesunąć · Podwójny klik resetuje · Kliknij obok, aby używać innych okien", ja: "ヘッダーをドラッグで移動・ダブルクリックで位置リセット・外側クリックで他アプリを操作可能", zh: "拖动顶部移动窗口 · 双击复位 · 点击窗口外可直接操作其他应用" },
    tipCyclePlacement: { en: "Switch HUD layout: Bottom · Top · Corner · Hyprland Tiled Right · Hyprland Tiled Left", no: "Bytt HUD-plassering: Bunn · Topp · Hjørne · Hyprland Tiled Høyre · Hyprland Tiled Venstre", sv: "Växla layout: Botten · Topp · Hörn · Hyprland Tiled Höger · Vänster", da: "Skift placering: Bund · Top · Hjørne · Hyprland Tiled Højre · Venstre", de: "HUD-Layout wechseln: Unten · Oben · Ecke · Hyprland Tiled Rechts · Links", fr: "Changer la disposition : Bas · Haut · Coin · Hyprland Tiled Droite · Gauche", es: "Cambiar ubicación: Abajo · Arriba · Esquina · Hyprland Tiled Derecha · Izquierda", pt: "Trocar posição: Base · Topo · Canto · Hyprland Tiled Direita · Esquerda", it: "Cambia posizione: Basso · Alto · Angolo · Hyprland Tiled Destra · Sinistra", pl: "Zmień układ: Dół · Góra · Róg · Hyprland Tiled Prawy · Lewy", ja: "配置を切替：下・上・右下・Hyprlandタイル右・左", zh: "切换窗口位置：底部 · 顶部 · 右下角 · Hyprland 平铺右侧 · 左侧" },
    posBottomName:     { en: "Bottom", no: "Bunn", sv: "Botten", da: "Bund", de: "Unten", fr: "Bas", es: "Abajo", pt: "Base", it: "Basso", pl: "Dół", ja: "下", zh: "底部" },
    posTopName:        { en: "Top", no: "Topp", sv: "Topp", da: "Top", de: "Oben", fr: "Haut", es: "Arriba", pt: "Topo", it: "Alto", pl: "Góra", ja: "上", zh: "顶部" },
    posCornerName:     { en: "Corner", no: "Hjørne", sv: "Hörn", da: "Hjørne", de: "Ecke", fr: "Coin", es: "Esquina", pt: "Canto", it: "Angolo", pl: "Róg", ja: "右下", zh: "角落" },
    posDockRightName:  { en: "Hyprland Tile Right", no: "Hyprland Tile Høyre", sv: "Hyprland Tile Höger", da: "Hyprland Tile Højre", de: "Hyprland Tile Rechts", fr: "Hyprland Tile Droite", es: "Hyprland Tile Derecha", pt: "Hyprland Tile Direita", it: "Hyprland Tile Destra", pl: "Hyprland Tile Prawy", ja: "Hyprland 右タイル", zh: "Hyprland 右平铺" },
    posDockLeftName:   { en: "Hyprland Tile Left", no: "Hyprland Tile Venstre", sv: "Hyprland Tile Vänster", da: "Hyprland Tile Venstre", de: "Hyprland Tile Links", fr: "Hyprland Tile Gauche", es: "Hyprland Tile Izquierda", pt: "Hyprland Tile Esquerda", it: "Hyprland Tile Sinistra", pl: "Hyprland Tile Lewy", ja: "Hyprland 左タイル", zh: "Hyprland 左平铺" },
    moveHudTo:         { en: "Click to move to", no: "Klikk for å flytte til", sv: "Klicka för att flytta till", da: "Klik for at flytte til", de: "Klicken zum Wechseln zu", fr: "Cliquer pour déplacer vers", es: "Clic para mover a", pt: "Clique para mover para", it: "Clicca per spostare in", pl: "Kliknij, aby przenieść do", ja: "クリックで移動:", zh: "点击切换到" },
    inlineToolsHint:   { en: "↗ Draw arrows, boxes or crop directly on the image before sending", no: "↗ Tegn piler, bokser eller beskjær direkte på bildet før du sender", sv: "↗ Rita pilar, ramar eller beskär direkt på bilden innan du skickar", da: "↗ Tegn pile, bokse eller beskær direkte på billedet før afsendelse", de: "↗ Pfeile, Rahmen oder Zuschnitt direkt hier ins Bild zeichnen", fr: "↗ Dessinez flèches, cadres ou recadrez directement ici avant d'envoyer", es: "↗ Dibuja flechas, recuadros o recorta aquí mismo antes de enviar", pt: "↗ Desenhe setas, quadros ou recorte direto aqui antes de enviar", it: "↗ Disegna frecce, riquadri o ritaglia qui prima di inviare", pl: "↗ Rysuj strzałki, ramki lub przytnij obraz bezpośrednio tutaj", ja: "↗ 送信前にここで直接矢印・枠・切り抜きができます", zh: "↗ 发送前可直接在图上画箭头、框选或裁剪" }
  })

  function t(key) {
    var entry = i18nTable[key]
    if (!entry) return key
    return entry[activeLang] || entry["en"] || key
  }

  readonly property var modelChoices: [
    { provider: "agy", vendorKey: "gemini", id: "gemini-3.8-flash-high", label: "Flash", vendor: "Gemini", badge: "Fast", tipKey: "tipModelFlash" },
    { provider: "agy", vendorKey: "gemini", id: "gemini-4-argon-high", label: "Argon", vendor: "Gemini", badge: "Deep", tipKey: "tipModelArgon" },
    { provider: "agy", vendorKey: "anthropic", id: "claude-sonnet-5-5-medium", label: "Sonnet 5.5", vendor: "Anthropic", badge: "Code", tipKey: "tipModelSonnet" },
    { provider: "grok", vendorKey: "xai", id: "grok-4.7", label: "Grok 4.7", vendor: "xAI", badge: "Direct", tipKey: "tipModelGrok" },
    { provider: "openai", vendorKey: "openai", id: "gpt-4o", label: "GPT-4o", vendor: "OpenAI", badge: "Vision", tipKey: "tipModelOpenai" }
  ]

  function isVendorReady(vendorKey) {
    for (var i = 0; i < providerStatuses.length; i++) {
      if (providerStatuses[i] && providerStatuses[i].vendor === vendorKey)
        return providerStatuses[i].ready === true
    }
    return false
  }

  function activeModelIndices() {
    var out = []
    for (var i = 0; i < modelChoices.length; i++) {
      if (isVendorReady(modelChoices[i].vendorKey)) out.push(i)
    }
    return out
  }

  function cycleActiveModel() {
    var active = activeModelIndices()
    if (active.length === 0) return
    var cur = modelIndex()
    var pos = active.indexOf(cur)
    var nextIdx = pos >= 0 ? active[(pos + 1) % active.length] : active[0]
    pickModelAt(nextIdx)
  }

  readonly property string modelLabel: {
    for (var i = 0; i < modelChoices.length; i++)
      if (modelChoices[i].id === model) return modelChoices[i].label
    return model
  }

  readonly property string stage: {
    if (imagePath === "") return "idle"
    if (inflight !== "" || busy) return "analysing"
    if (answer !== "") return "viewed"
    return "ready"
  }

  readonly property color stageColor: {
    if (stage === "analysing") return colAnalysing
    if (stage === "viewed") return colSuccess
    if (stage === "ready") return colReady
    return dim
  }

  readonly property string stageLabel: {
    if (stage === "analysing") return paused ? t("paused") : t("scanning")
    if (stage === "viewed") return t("answered")
    return t("ready")
  }

  readonly property string stageTip: {
    if (stage === "analysing") return paused ? t("tipStatusPaused") : t("tipStatusScanning")
    if (stage === "viewed") return t("tipStatusViewed")
    if (stage === "ready") return t("tipStatusReady")
    return t("tipStatusIdle")
  }

  function setHover(item, active, text) {
    if (active && text !== "") {
      hoverTip = text
      hoverItem = item
      tooltipShown = false
      tooltipDelay.restart()
    } else if (!active && hoverItem === item) {
      clearHover()
    }
  }

  function clearHover() {
    hoverTip = ""
    hoverItem = null
    tooltipShown = false
    tooltipDelay.stop()
  }

  function positionTooltip() {
    if (!hoverItem || hoverTip === "" || !windowOpen) {
      tooltipShown = false
      return
    }
    var topCenter = hoverItem.mapToItem(mainCard, hoverItem.width / 2, 0)
    var bottomPos = hoverItem.mapToItem(mainCard, 0, hoverItem.height)
    var tw = tooltipBox.implicitWidth
    var th = tooltipBox.implicitHeight
    var margin = Style.space(10)
    var tx = Math.max(margin, Math.min(mainCard.width - tw - margin, topCenter.x - tw / 2))
    var ty = bottomPos.y + Style.space(6)
    if (ty + th + Style.space(6) > mainCard.height) {
      ty = Math.max(Style.space(6), topCenter.y - th - Style.space(6))
    }
    tooltipX = tx
    tooltipY = ty
    tooltipShown = true
  }

  readonly property string producerKind: {
    if (provider === "openai" || model.indexOf("gpt") >= 0) return "openai"
    if (provider === "grok") return "xai"
    if (model.indexOf("claude") >= 0) return "anthropic"
    return "gemini"
  }

  readonly property string producerName: {
    if (producerKind === "openai") return "OpenAI"
    if (producerKind === "xai") return "xAI"
    if (producerKind === "anthropic") return "Anthropic"
    return "Gemini"
  }

  function applyThemeColors(raw) {
    var lines = String(raw || "").split("\n")
    var y = ""
    var g = ""
    var c3 = ""
    var c2 = ""
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (!m) continue
      if (m[1] === "yellow") y = m[2]
      else if (m[1] === "green") g = m[2]
      else if (m[1] === "color3") c3 = m[2]
      else if (m[1] === "color2") c2 = m[2]
    }
    themeYellowHex = y || c3
    themeGreenHex = g || c2
  }

  function loadProviders() {
    if (providersProc.running) return
    providersProc.command = [binPath(), "providers"]
    providersProc.running = true
  }

  function applyProviders(raw) {
    try {
      var arr = JSON.parse(String(raw || "[]"))
      if (Array.isArray(arr)) {
        providerStatuses = arr
        var cur = modelChoices[modelIndex()]
        if (cur && !isVendorReady(cur.vendorKey)) {
          var active = activeModelIndices()
          if (active.length > 0) {
            var fallback = modelChoices[active[0]]
            provider = fallback.provider
            model = fallback.id
          }
        }
      }
    } catch (e) {}
  }

  function setApiKey(vendor, apiKey) {
    if (!vendor) return
    keySetProc.command = [binPath(), "key-set", String(vendor), String(apiKey || "")]
    keySetProc.running = true
  }

  function pluginDir() {
    var dir = manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
    if (dir.length > 0) return dir.replace(/\/$/, "")
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.7eleven77.aeye"
  }

  function binPath() {
    return pluginDir() + "/bin/aeye"
  }

  function fileUrl(path) {
    if (!path) return ""
    return "file://" + encodeURI(path)
  }

  function applyConfig(raw) {
    var obj
    try { obj = JSON.parse(String(raw || "{}")) } catch (e) { return }
    if (obj.visionOverride === true && obj.provider && obj.model) {
      userPickedModel = true
      provider = String(obj.provider)
      model = String(obj.model)
    }
    if (obj.autosend !== undefined && obj.autosend !== null) autosend = obj.autosend === true
    if (obj.minimizeOnSend !== undefined && obj.minimizeOnSend !== null) minimizeOnSend = obj.minimizeOnSend === true
    if (obj.showReason !== undefined && obj.showReason !== null) showReason = obj.showReason === true
    if (obj.systemDebug !== undefined && obj.systemDebug !== null) systemDebug = obj.systemDebug === true
    if (obj.lastSaveDir && String(obj.lastSaveDir).length > 0) lastSaveDir = String(obj.lastSaveDir)
    if (obj.watch !== undefined && obj.watch !== null) watch = obj.watch === true
    if (obj.lang && String(obj.lang).length > 0) lang = String(obj.lang)
    if (obj.minimalMode !== undefined && obj.minimalMode !== null) minimalMode = obj.minimalMode === true
    if (obj.hudPlacement && String(obj.hudPlacement).length > 0) {
      var hp = String(obj.hudPlacement)
      if (hp === "bottom" || hp === "top" || hp === "corner" || hp === "dock-right" || hp === "dock-left")
        hudPlacement = hp
    }
    if (Array.isArray(obj.customPrompts)) {
      var clean = []
      for (var i = 0; i < obj.customPrompts.length; i++) {
        var p = String(obj.customPrompts[i] || "").replace(/^\s+|\s+$/g, "")
        if (p.length > 0 && clean.indexOf(p) < 0) clean.push(p)
      }
      customPrompts = clean
    }
  }

  function saveConfig(key, value, type) {
    var cmd = [binPath(), "config-set", key, String(value), type || "string"]
    if (configProc.running) configProc.queue = configProc.queue.concat([cmd])
    else {
      configProc.command = cmd
      configProc.running = true
    }
  }

  function saveConfigPatch(obj) {
    var cmd = [binPath(), "config-patch", JSON.stringify(obj)]
    if (configProc.running) configProc.queue = configProc.queue.concat([cmd])
    else {
      configProc.command = cmd
      configProc.running = true
    }
  }

  function pickAutosend(on) {
    autosend = on
    saveConfig("autosend", on ? "true" : "false", "bool")
    if (on && windowOpen && imagePath !== "" && answer === "" && note === "" && !busy && inflight === "") {
      startRead()
    }
  }

  function pickMinimizeOnSend(on) {
    minimizeOnSend = on
    saveConfig("minimizeOnSend", on ? "true" : "false", "bool")
  }

  function pickShowReason(on) {
    showReason = on
    saveConfig("showReason", on ? "true" : "false", "bool")
  }

  function pickSystemDebug(on) {
    systemDebug = on
    saveConfig("systemDebug", on ? "true" : "false", "bool")
  }

  function pickMinimalMode(on) {
    minimalMode = on
    saveConfig("minimalMode", on ? "true" : "false", "bool")
  }

  function pickHudPlacement(mode) {
    var allowed = ["bottom", "top", "corner", "dock-right", "dock-left"]
    if (allowed.indexOf(mode) < 0) mode = "bottom"
    var prev = hudPlacement
    var wasDocked = prev === "dock-right" || prev === "dock-left"
    var willDock = mode === "dock-right" || mode === "dock-left"
    hudPlacement = mode
    hasCustomPos = false
    saveConfig("hudPlacement", mode, "string")
    // Brief surface remap when entering/leaving/flipping Hyprland tiled dock so
    // Hyprland immediately recalculates exclusiveZone and tiles windows cleanly.
    if (windowOpen && (wasDocked !== willDock || (willDock && prev !== mode))) {
      remapping = true
      remapTimer.restart()
    }
  }

  function nextHudPlacement() {
    var order = ["bottom", "top", "corner", "dock-right", "dock-left"]
    var idx = order.indexOf(hudPlacement)
    return order[(idx + 1) % order.length]
  }

  function placementIcon(mode) {
    if (mode === "top") return "⬆"
    if (mode === "corner") return "⬊"
    if (mode === "dock-right") return "◨"
    if (mode === "dock-left") return "◧"
    return "⬇"
  }

  function placementLabel(mode) {
    if (mode === "top") return t("posTopName")
    if (mode === "corner") return t("posCornerName")
    if (mode === "dock-right") return t("posDockRightName")
    if (mode === "dock-left") return t("posDockLeftName")
    return t("posBottomName")
  }

  function cycleHudPlacement() {
    pickHudPlacement(nextHudPlacement())
  }

  function cycleLocale(dir) {
    var idx = 0
    for (var i = 0; i < supportedLocales.length; i++) {
      if (supportedLocales[i].code === lang) { idx = i; break }
    }
    var nextIdx = (idx + (dir < 0 ? -1 : 1) + supportedLocales.length) % supportedLocales.length
    lang = supportedLocales[nextIdx].code
    saveConfig("lang", lang, "string")
    hint = "Locale: " + localeDisplayLabel
  }

  function addCustomPromptText(rawText) {
    var text = String(rawText || "").replace(/^\s+|\s+$/g, "")
    if (text.length === 0) return false
    if (customPrompts.indexOf(text) >= 0) return false
    var next = customPrompts.concat([text])
    customPrompts = next
    saveConfig("customPrompts", JSON.stringify(next), "json")
    return true
  }

  function addCustomPrompt() {
    if (addCustomPromptText(draft)) draft = ""
  }

  function removeCustomPrompt(phrase) {
    var next = []
    for (var i = 0; i < customPrompts.length; i++) {
      if (customPrompts[i] !== phrase) next.push(customPrompts[i])
    }
    customPrompts = next
    saveConfig("customPrompts", JSON.stringify(next), "json")
  }

  function pickModelAt(index) {
    userPickedModel = true
    var choice = modelChoices[(index + modelChoices.length) % modelChoices.length]
    provider = choice.provider
    model = choice.id
    recommendedModelIdx = -1
    recommendedCategory = ""
    // Single atomic write prevents FileView from reloading half-updated provider/model pairs
    saveConfigPatch({ visionOverride: true, provider: choice.provider, model: choice.id })
    hint = ""
  }

  function modelIndex() {
    for (var i = 0; i < modelChoices.length; i++)
      if (modelChoices[i].id === model) return i
    return 0
  }

  function usePrompt(phrase) {
    draft = phrase
    userTyped = true
    focusField()
  }

  function copyAnswer() {
    if (!answer) return
    if (copyProc.running) copyProc.running = false
    copyProc.command = [binPath(), "copy", answer]
    copyProc.running = true
    copiedBlockIdx = -1
    copiedFeedback = true
    copyResetTimer.restart()
  }

  function copyCodeBlock(rawCode, idx) {
    if (!rawCode) return
    if (copyProc.running) copyProc.running = false
    copyProc.command = [binPath(), "copy", String(rawCode)]
    copyProc.running = true
    copiedBlockIdx = idx
    copyResetTimer.restart()
  }

  function pad2(n) { return n < 10 ? ("0" + n) : String(n) }

  function defaultSavePath(ext) {
    var d = new Date()
    var stamp = d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + "-" + pad2(d.getHours()) + pad2(d.getMinutes())
    var dir = String(lastSaveDir || "~/Documents").replace(/\/+$/, "")
    var suffix = ext || ".txt"
    return dir + "/aeye-" + stamp + suffix
  }

  function openSaveDrawer() {
    saveDrawerOpen = !saveDrawerOpen
    if (saveDrawerOpen) {
      saveStatus = ""
      saveStatusMsg = ""
      if (savePathText === "") savePathText = defaultSavePath(".txt")
      Qt.callLater(function() { savePathInput.forceActiveFocus() })
    }
  }

  function setSaveFolder(dir) {
    var cleanDir = String(dir || "~/Documents").replace(/\/+$/, "")
    if (cleanDir === "") cleanDir = "~"
    var cur = String(savePathText || "").replace(/^\s+|\s+$/g, "")
    var base = ""
    if (cur !== "") {
      var slash = cur.lastIndexOf("/")
      base = slash >= 0 ? cur.substring(slash + 1) : cur
    }
    if (base === "") {
      var d = new Date()
      base = "aeye-" + d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + "-" + pad2(d.getHours()) + pad2(d.getMinutes()) + ".txt"
    }
    savePathText = cleanDir + "/" + base
    lastSaveDir = cleanDir
    saveConfig("lastSaveDir", cleanDir, "string")
  }

  function setSaveExtension(ext) {
    var cur = String(savePathText || defaultSavePath(ext)).replace(/^\s+|\s+$/g, "")
    var slash = cur.lastIndexOf("/")
    var dir = slash >= 0 ? cur.substring(0, slash + 1) : ""
    var fname = slash >= 0 ? cur.substring(slash + 1) : cur
    if (fname === "") fname = "aeye-note"
    var dot = fname.lastIndexOf(".")
    if (dot > 0) fname = fname.substring(0, dot) + ext
    else fname = fname + ext
    savePathText = dir + fname
  }

  function runExportFile() {
    var dest = String(savePathText || "").replace(/^\s+|\s+$/g, "")
    if (dest.length === 0 || !answer) return
    var slash = dest.lastIndexOf("/")
    if (slash > 0) {
      var dir = dest.substring(0, slash)
      if (dir !== "" && dir !== lastSaveDir) {
        lastSaveDir = dir
        saveConfig("lastSaveDir", dir, "string")
      }
    }
    var payload = JSON.stringify({
      model: producerName + " " + modelLabel,
      prompt: lastPromptSent || "",
      reasoning: showReason ? (reasoning || "") : "",
      answer: answer,
      sysdebug: systemDebug
    })
    saveStatus = ""
    saveStatusMsg = ""
    if (exportProc.running) exportProc.running = false
    exportProc.command = [binPath(), "export-file", dest, payload]
    exportProc.running = true
  }

  function onExportLine(line) {
    var s = String(line || "").replace(/\r?\n$/, "")
    if (s.indexOf("OK\t") === 0) {
      var savedTo = s.substring(3)
      var home = String(Quickshell.env("HOME") || "")
      if (home !== "" && savedTo.indexOf(home) === 0) savedTo = "~" + savedTo.substring(home.length)
      saveStatus = "ok"
      saveStatusMsg = t("saved") + ": " + savedTo
      saveResetTimer.restart()
    } else if (s.indexOf("ERR\t") === 0) {
      saveStatus = "err"
      saveStatusMsg = s.substring(4)
    }
  }

  function escapeHtml(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  function colorCss(c) {
    return String(c || "#ffffff")
  }

  // Strictly HTML-escaped inline Markdown (code spans, bold, italic, links)
  function formatInlineHtml(raw) {
    var src = String(raw || "")
    var codes = []
    // Stash inline code spans first so ** / * inside code aren't touched
    src = src.replace(/`([^`\n]+)`/g, function(_, inner) {
      var idx = codes.length
      codes.push(escapeHtml(inner))
      return "\uE000CODE" + idx + "\uE001"
    })
    var out = escapeHtml(src)
    // Links [text](url) -> clean underlined accent label
    out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function(_, label) {
      return "<span style=\"color:" + colorCss(Color.accent) + "\"><u>" + label + "</u></span>"
    })
    // Bold **text**
    out = out.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
    // Italic *text*
    out = out.replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<i>$2</i>")
    // Restore inline code spans styled with live theme accent
    out = out.replace(/\uE000CODE(\d+)\uE001/g, function(_, n) {
      var code = codes[parseInt(n, 10)] || ""
      return "<code style=\"color:" + colorCss(Color.accent) + "\">" + code + "</code>"
    })
    return out
  }

  // Lightweight, 100% HTML-escaped theme-native syntax highlighter for fenced code blocks
  function highlightCodeHtml(rawCode, lang) {
    var colKw = colorCss(Color.accent)
    var colStr = colorCss(root.colSuccess)
    var colNum = colorCss(root.colAnalysing)
    var colCom = colorCss(root.dim)
    var kwRe = /^(const|let|var|function|async|await|return|if|else|elif|for|while|switch|case|break|continue|import|export|from|default|class|extends|new|try|catch|except|finally|throw|raise|def|lambda|pass|with|as|in|not|and|or|true|false|null|undefined|None|True|False|local|then|fi|do|done|esac|echo|printf|sudo|git|npm|pnpm|python3|bash|omarchy|property|readonly|signal|component)$/
    var lines = String(rawCode || "").split("\n")
    var outLines = []

    for (var li = 0; li < lines.length; li++) {
      var line = lines[li]
      var trimmed = line.replace(/^\s+/, "")
      // Full-line comments
      if (trimmed.indexOf("//") === 0 || (trimmed.indexOf("#") === 0 && lang !== "css")) {
        outLines.push("<span style=\"color:" + colCom + "\"><i>" + escapeHtml(line) + "</i></span>")
        continue
      }
      var res = ""
      var i = 0
      while (i < line.length) {
        var ch = line.charAt(i)
        // Trailing // comment
        if (ch === "/" && i + 1 < line.length && line.charAt(i + 1) === "/") {
          res += "<span style=\"color:" + colCom + "\"><i>" + escapeHtml(line.substring(i)) + "</i></span>"
          break
        }
        // Quoted strings ("...", '...', `...`)
        if (ch === "\"" || ch === "'" || ch === "`") {
          var q = ch
          var j = i + 1
          while (j < line.length) {
            if (line.charAt(j) === "\\" && j + 1 < line.length) { j += 2; continue }
            if (line.charAt(j) === q) { j += 1; break }
            j += 1
          }
          res += "<span style=\"color:" + colStr + "\">" + escapeHtml(line.substring(i, j)) + "</span>"
          i = j
          continue
        }
        // Identifiers / keywords
        if (/[A-Za-z_]/.test(ch)) {
          var k = i + 1
          while (k < line.length && /[A-Za-z0-9_-]/.test(line.charAt(k))) k += 1
          var word = line.substring(i, k)
          if (kwRe.test(word)) res += "<span style=\"color:" + colKw + "\"><b>" + escapeHtml(word) + "</b></span>"
          else res += escapeHtml(word)
          i = k
          continue
        }
        // Numbers
        if (/[0-9]/.test(ch)) {
          var m = i + 1
          while (m < line.length && /[0-9.xXa-fA-F]/.test(line.charAt(m))) m += 1
          res += "<span style=\"color:" + colNum + "\">" + escapeHtml(line.substring(i, m)) + "</span>"
          i = m
          continue
        }
        res += escapeHtml(ch)
        i += 1
      }
      outLines.push(res)
    }
    return "<pre style=\"margin:0;white-space:pre-wrap;\">" + outLines.join("\n") + "</pre>"
  }

  // Parse Markdown text into structured blocks (heading, bullet, paragraph, fenced code)
  function parseMarkdownBlocks(md) {
    var src = String(md || "").replace(/\r\n/g, "\n")
    if (src.replace(/^\s+|\s+$/g, "") === "") return []
    var lines = src.split("\n")
    var blocks = []
    var para = []
    var inCode = false
    var codeLang = ""
    var codeLines = []

    function flushPara() {
      if (para.length === 0) return
      var joined = para.join("<br/>")
      blocks.push({ kind: "paragraph", html: joined, raw: para.join("\n"), lang: "", marker: "" })
      para = []
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var fence = line.match(/^\s*```([A-Za-z0-9_+#.-]*)\s*$/)
      if (fence) {
        if (!inCode) {
          flushPara()
          inCode = true
          codeLang = String(fence[1] || "").toLowerCase()
          codeLines = []
        } else {
          var rawCode = codeLines.join("\n")
          blocks.push({ kind: "code", lang: codeLang, raw: rawCode, html: highlightCodeHtml(rawCode, codeLang), marker: "" })
          inCode = false
          codeLang = ""
          codeLines = []
        }
        continue
      }
      if (inCode) {
        codeLines.push(line)
        continue
      }
      var trimmed = line.replace(/^\s+|\s+$/g, "")
      if (trimmed === "") {
        flushPara()
        continue
      }
      var hm = trimmed.match(/^(#{1,6})\s+(.+)$/)
      if (hm) {
        flushPara()
        blocks.push({ kind: "heading", level: hm[1].length, html: formatInlineHtml(hm[2]), raw: hm[2], lang: "", marker: "" })
        continue
      }
      var bm = line.match(/^\s*([-*•]|\d+\.)\s+(.+)$/)
      if (bm) {
        flushPara()
        var mk = (bm[1] === "-" || bm[1] === "*") ? "•" : bm[1]
        blocks.push({ kind: "bullet", marker: mk, html: formatInlineHtml(bm[2]), raw: bm[2], lang: "" })
        continue
      }
      para.push(formatInlineHtml(trimmed))
    }
    if (inCode && codeLines.length > 0) {
      var openCode = codeLines.join("\n")
      blocks.push({ kind: "code", lang: codeLang, raw: openCode, html: highlightCodeHtml(openCode, codeLang), marker: "" })
    }
    flushPara()
    return blocks
  }

  function sendDesktopNotification(title, body) {
    notifyProc.command = [binPath(), "notify", title, body, imagePath]
    notifyProc.running = true
  }

  function sendReadyNotification(answerText) {
    notifyProc.command = [
      binPath(), "notify-ready",
      "✦ Aeye — " + t("notifReadyTitle"),
      t("notifReadyBody"),
      imagePath,
      t("notifOpenBtn"),
      t("copy"),
      String(answerText || "")
    ]
    notifyProc.running = true
  }

  function sendErrorNotification(errMsg) {
    notifyProc.command = [
      binPath(), "notify-error",
      "⚠ Aeye",
      String(errMsg || t("noResponse")),
      imagePath,
      t("notifOpenBtn")
    ]
    notifyProc.running = true
  }

  function runCapture() {
    if (captureProc.running) return
    captureProc.command = [binPath(), "capture"]
    captureProc.running = true
  }

  function imageContent() {
    var sw = shot.sourceSize.width
    var sh = shot.sourceSize.height
    if (!sw || !sh) return { x: 0, y: 0, w: shot.width, h: shot.height, sw: shot.width, sh: shot.height }
    var scale = Math.min(shot.width / sw, shot.height / sh)
    var w = sw * scale
    var h = sh * scale
    return { x: (shot.width - w) / 2, y: (shot.height - h) / 2, w: w, h: h, sw: sw, sh: sh }
  }

  function toNorm(mx, my) {
    var area = imageContent()
    var x = area.w > 0 ? (mx - area.x) / area.w : 0
    var y = area.h > 0 ? (my - area.y) / area.h : 0
    if (x < 0) x = 0
    if (y < 0) y = 0
    if (x > 1) x = 1
    if (y > 1) y = 1
    return { x: x, y: y }
  }

  function hitCorner(point) {
    if (!cropNorm) return ""
    var corners = [
      { id: "nw", x: cropNorm.x1, y: cropNorm.y1 },
      { id: "ne", x: cropNorm.x2, y: cropNorm.y1 },
      { id: "se", x: cropNorm.x2, y: cropNorm.y2 },
      { id: "sw", x: cropNorm.x1, y: cropNorm.y2 }
    ]
    for (var i = 0; i < corners.length; i++) {
      var dx = point.x - corners[i].x
      var dy = point.y - corners[i].y
      if (dx * dx + dy * dy < 0.0016) return corners[i].id
    }
    return ""
  }

  function moveCorner(id, point) {
    if (!cropNorm) return
    var next = { kind: "crop", x1: cropNorm.x1, y1: cropNorm.y1, x2: cropNorm.x2, y2: cropNorm.y2 }
    if (id === "nw" || id === "sw") next.x1 = point.x
    else next.x2 = point.x
    if (id === "nw" || id === "ne") next.y1 = point.y
    else next.y2 = point.y
    cropNorm = next
    markCanvas.requestPaint()
  }

  function commitDrag(from, to) {
    if (!from || !to) return
    if (Math.abs(from.x - to.x) < 0.01 && Math.abs(from.y - to.y) < 0.01) return
    if (tool === "crop") {
      cropNorm = { kind: "crop", x1: from.x, y1: from.y, x2: to.x, y2: to.y }
    } else {
      var next = marks.slice()
      next.push({ kind: tool, x1: from.x, y1: from.y, x2: to.x, y2: to.y })
      marks = next
    }
    markCanvas.requestPaint()
  }

  function clearMarks() {
    marks = []
    cropNorm = null
    markCanvas.requestPaint()
  }

  function applyCrop() {
    if (!cropNorm || !imagePath) return
    var area = imageContent()
    var x1 = Math.min(cropNorm.x1, cropNorm.x2)
    var y1 = Math.min(cropNorm.y1, cropNorm.y2)
    var x2 = Math.max(cropNorm.x1, cropNorm.x2)
    var y2 = Math.max(cropNorm.y1, cropNorm.y2)
    var x = Math.round(x1 * area.sw)
    var y = Math.round(y1 * area.sh)
    var w = Math.max(1, Math.round((x2 - x1) * area.sw))
    var h = Math.max(1, Math.round((y2 - y1) * area.sh))
    cropProc.command = [binPath(), "crop", imagePath, w + "x" + h + "+" + x + "+" + y]
    cropProc.running = true
  }

  function onCropLine(line) {
    var text = String(line || "")
    if (text.indexOf("OK\t") === 0) {
      var outPath = text.substring(3)
      if (outPath.length > 0) {
        imagePath = outPath
        marks = []
        cropNorm = null
        markCanvas.requestPaint()
        if (autosend) startRead()
      }
      return
    }
    if (text.indexOf("ERR\t") === 0) {
      errorText = text.substring(4)
    }
  }

  // Multi-line visual reasoning splitter — works both incrementally while streaming and on final answer
  function splitReason(text) {
    var raw = String(text || "").replace(/^\s+/, "")
    var re = /^(REASON|Derfor):\s*/i
    if (!re.test(raw)) return { reason: "", body: raw.replace(/\s+$/, "") }
    var afterPrefix = raw.replace(re, "")
    // Explicit ANSWER: delimiter (supports multi-line bullet reasoning!)
    var ansMatch = afterPrefix.match(/\n\s*(ANSWER|SVAR):\s*/i)
    if (ansMatch) {
      var idx = ansMatch.index
      return {
        reason: afterPrefix.substring(0, idx).replace(/^\s+|\s+$/g, ""),
        body: afterPrefix.substring(idx + ansMatch[0].length).replace(/^\s+|\s+$/g, "")
      }
    }
    // Fallback: split on first blank line once content follows
    var blankIdx = afterPrefix.search(/\n\s*\n/)
    if (blankIdx >= 0) {
      return {
        reason: afterPrefix.substring(0, blankIdx).replace(/^\s+|\s+$/g, ""),
        body: afterPrefix.substring(blankIdx).replace(/^\s+|\s+$/g, "")
      }
    }
    // Still streaming the REASON section (no ANSWER/blank line yet)
    return {
      reason: afterPrefix.replace(/\s+$/, ""),
      body: ""
    }
  }

  function stripReadMetaLines(text) {
    var lines = String(text || "").split("\n")
    var out = []
    var re = /^[-*•]?\s*(FORSLAG|SUGGESTION|CATEGORY):/i
    for (var i = 0; i < lines.length; i++) {
      if (!re.test(lines[i].replace(/^\s+/, ""))) out.push(lines[i])
    }
    return out.join("\n").replace(/^\s+|\s+$/g, "")
  }

  function focusField() {
    draftInput.forceActiveFocus()
  }

  function handleEscape() {
    if (busy || inflight !== "") {
      stopAsk()
      return
    }
    closeWindow()
  }

  function showWindow() {
    focusPrimed = false
    windowOpen = true
    silentRun = false
    backgroundRun = false
    hasUnreadAnswer = false
    focusPrimeTimer.restart()
    Qt.callLater(root.focusField)
  }

  function minimizeToBackground() {
    focusPrimeTimer.stop()
    focusPrimed = false
    dragging = false
    backgroundRun = true
    windowOpen = false
    clearHover()
  }

  function closeWindow() {
    focusPrimeTimer.stop()
    focusPrimed = false
    dragging = false
    windowOpen = false
    editing = false
    clearHover()
    if (askProc.running && !silentRun && !backgroundRun) {
      askStop = true
      pendingAsk = null
      askProc.running = false
    }
  }

  function noteShot(path) {
    var file = String(path || "").replace(/\s+$/g, "")
    if (file.length === 0 || !/\.(png|jpe?g|webp)$/i.test(file)) return
    if (windowOpen && file === imagePath) {
      refreshShot()
      return
    }
    if (!watch) return
    compose(file)
  }

  function refreshShot() {
    var current = imagePath
    imagePath = ""
    imagePath = current
  }

  function loadAgents() {
    if (agentProc.running) return
    agentProc.command = [binPath(), "agents"]
    agentProc.running = true
  }

  function applyAgents(raw) {
    var obj
    try { obj = JSON.parse(String(raw || "{}")) } catch (e) { return }
    if (obj.omarchy) omarchyAgent = String(obj.omarchy)
    visionWhy = obj.why ? String(obj.why) : ""
    if (!userPickedModel && obj.provider && obj.model) {
      provider = String(obj.provider)
      model = String(obj.model)
    }
  }

  function togglePause() {
    if (!busy && inflight === "") return
    paused = !paused
    controlProc.command = [binPath(), paused ? "pause" : "resume"]
    controlProc.running = true
  }

  function stopAsk() {
    paused = false
    askStop = true
    pendingAsk = null
    if (askProc.running) askProc.running = false
    controlProc.command = [binPath(), "stop"]
    controlProc.running = true
    busy = false
    inflight = ""
  }

  function openTerminal() {
    var lines = [
      systemDebug ? "System Debug fix session from Aeye." : "Follow-up session from Aeye.",
      "Agent: " + omarchyAgent,
      "Image: " + imagePath,
      ""
    ]
    if (note) lines.push("Context:\n" + note)
    if (draft) lines.push("Question:\n" + draft)
    else if (lastPromptSent) lines.push("Question:\n" + lastPromptSent)
    if (answer) lines.push("Previous Diagnosis / Answer:\n" + answer)
    lines.push(systemDebug
      ? "Review the diagnosis and screenshot above, inspect the relevant system state, and ask before applying any system changes."
      : "Read the image and continue from where the answer left off.")
    var text = lines.join("\n")
    termProc.command = [binPath(), "terminal", text]
    termProc.running = true
  }

  function launch(mode, follow, prior, imageOverride) {
    var image = imageOverride || imagePath
    if (!image) return
    generation += 1
    var gen = generation
    inflight = mode
    busy = mode !== "read"
    gotAnswerPath = false
    streamStep = ""
    streamRaw = ""
    liveThink = ""
    reasoning = ""
    if (mode !== "read") {
      answer = ""
      errorText = ""
      saveDrawerOpen = false
      saveStatus = ""
      saveStatusMsg = ""
      savePathText = ""
    }
    if (follow && String(follow).length > 0) lastPromptSent = String(follow)
    var cmd = [
      binPath(), "ask",
      "--provider", provider,
      "--model", model,
      "--mode", mode,
      "--lang", activeLang,
      "--image", image
    ]
    if (marks.length > 0) {
      cmd.push("--marks")
      cmd.push(JSON.stringify(marks))
    }
    if (showReason) cmd.push("--reason")
    if (systemDebug) cmd.push("--sysdebug")
    if (follow && String(follow).length > 0) {
      cmd.push("--follow")
      cmd.push(String(follow))
      cmd.push("--prior")
      cmd.push(String(prior || "").substring(0, 1500))
    }
    var job = { cmd: cmd, gen: gen, mode: mode }
    if (askProc.running) {
      askStop = true
      pendingAsk = job
      askProc.running = false
      return
    }
    askProc.gen = gen
    askProc.command = cmd
    askProc.running = true
  }

  function startRead() {
    launch("read", "", "")
    busy = false
  }

  function sendDraft() {
    var question = String(draft || "").replace(/^\s+|\s+$/g, "")
    if (question.length === 0 || !imagePath) return
    userTyped = true
    draft = ""
    hasUnreadAnswer = false
    launch("user", question, note, "")
    if (minimizeOnSend) {
      minimizeToBackground()
    }
  }

  function beginEdit() {
    if (!imagePath) return
    editing = true
    editProc.command = [binPath(), "edit", imagePath]
    editProc.running = true
  }

  function finishEdit() {
    editing = false
    refreshShot()
    if (windowOpen) Qt.callLater(root.focusField)
  }

  function onAskLine(line) {
    if (askStop) return
    if (askProc.gen !== generation) return
    var text = String(line || "")
    if (text.indexOf("STEP\t") === 0) {
      streamStep = text.substring(5)
      return
    }
    if (text.indexOf("THINK\t") === 0) {
      try {
        var tchunk = JSON.parse(text.substring(6))
        if (typeof tchunk === "string" && tchunk.length > 0) liveThink += tchunk
      } catch (e) {}
      return
    }
    if (text.indexOf("DELTA\t") === 0) {
      try {
        var chunk = JSON.parse(text.substring(6))
        if (typeof chunk === "string" && chunk.length > 0) {
          streamRaw += chunk
          var liveParts = splitReason(streamRaw)
          if (liveParts.reason !== "") reasoning = liveParts.reason
          var liveBody = inflight === "read" ? stripReadMetaLines(liveParts.body) : liveParts.body
          if (liveBody !== "" && (inflight !== "read" || (!userTyped && (autosend || silentRun || backgroundRun)))) {
            answerFade = 1
            answer = liveBody
          }
        }
      } catch (e) {}
      return
    }
    if (text.indexOf("OK\t") === 0) {
      gotAnswerPath = true
      answerGen = generation
      answerMode = inflight
      answerFile.path = text.substring(3)
      answerFile.reload()
      return
    }
    if (text.indexOf("ERR\t") === 0) {
      var errMsg = text.substring(4)
      busy = false
      inflight = ""
      streamStep = ""
      errorText = errMsg
      if (silentRun && !windowOpen) {
        sendDesktopNotification("⚠ Aeye", errMsg)
        silentRun = false
      } else if (backgroundRun && !windowOpen) {
        sendErrorNotification(errMsg)
        backgroundRun = false
      }
    }
  }

  function computeRecommendedModel(cat) {
    var targetId = ""
    if (cat === "code" || cat === "grammar") targetId = "claude-sonnet-5-5-medium"
    else if (cat === "realtime") targetId = "grok-4.7"
    else if (cat === "deep") targetId = "gemini-4-argon-high"
    if (targetId === "" || targetId === model) {
      recommendedModelIdx = -1
      recommendedCategory = ""
      return
    }
    for (var i = 0; i < modelChoices.length; i++) {
      if (modelChoices[i].id === targetId && isVendorReady(modelChoices[i].vendorKey)) {
        recommendedModelIdx = i
        recommendedCategory = cat
        return
      }
    }
    recommendedModelIdx = -1
    recommendedCategory = ""
  }

  function recommendedCategoryLabel() {
    if (recommendedCategory === "code") return t("recCode")
    if (recommendedCategory === "grammar") return t("recGrammar")
    if (recommendedCategory === "realtime") return t("recRealtime")
    if (recommendedCategory === "deep") return t("recDeep")
    return ""
  }

  function parseReadSuggestions(rawText) {
    var lines = String(rawText || "").split("\n")
    var cleanLines = []
    var extracted = []
    var detectedCat = ""
    var re = /^[-*•]?\s*(FORSLAG|SUGGESTION):\s*/i
    var catRe = /^[-*•]?\s*CATEGORY:\s*([a-zA-Z]+)/i
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i].replace(/^\s+|\s+$/g, "")
      var cm = l.match(catRe)
      if (cm) {
        detectedCat = String(cm[1] || "").toLowerCase()
      } else if (re.test(l)) {
        var q = l.replace(re, "").replace(/^\s+|\s+$/g, "")
        if (q.length > 0 && extracted.indexOf(q) < 0) extracted.push(q)
      } else {
        cleanLines.push(lines[i])
      }
    }
    aiPrompts = extracted
    computeRecommendedModel(detectedCat)
    return cleanLines.join("\n").replace(/^\s+|\s+$/g, "")
  }

  function takeAnswer(text) {
    if (answerGen !== generation) return
    streamStep = ""
    var parts = splitReason(text)
    if (parts.reason !== "") reasoning = parts.reason
    var bodyOnly = parts.body !== "" ? parts.body : (parts.reason === "" ? text : "")
    if (answerMode === "read") {
      var cleanedNote = parseReadSuggestions(bodyOnly)
      note = cleanedNote !== "" ? cleanedNote : bodyOnly
      busy = false
      inflight = ""
      answerMode = ""
      if (!userTyped && (autosend || silentRun || backgroundRun)) {
        answer = note
      }
      if (silentRun && !windowOpen && note !== "") {
        if (copyProc.running) copyProc.running = false
        copyProc.command = [binPath(), "copy", note]
        copyProc.running = true
        sendDesktopNotification(
          "✦ Aeye (" + producerName + " " + modelLabel + ")",
          note
        )
        silentRun = false
      } else if (backgroundRun && !windowOpen && note !== "") {
        hasUnreadAnswer = true
        backgroundRun = false
        sendReadyNotification(note)
      }
      return
    }
    answerFade = 1
    answer = bodyOnly !== "" ? bodyOnly : text
    busy = false
    errorText = ""
    inflight = ""
    if (backgroundRun && !windowOpen) {
      hasUnreadAnswer = true
      backgroundRun = false
      sendReadyNotification(answer)
      return
    }
  }

  function onAskExit() {
    if (askStop) {
      askStop = false
      if (pendingAsk) {
        var job = pendingAsk
        pendingAsk = null
        gotAnswerPath = false
        askProc.gen = job.gen
        inflight = job.mode
        askProc.command = job.cmd
        askProc.running = true
      }
      return
    }
    if (!gotAnswerPath) {
      if (silentRun && !windowOpen) {
        sendDesktopNotification("⚠ Aeye", t("noResponse"))
        silentRun = false
        busy = false
        inflight = ""
      } else if (backgroundRun && !windowOpen) {
        errorText = t("noResponse")
        sendErrorNotification(errorText)
        backgroundRun = false
        busy = false
        inflight = ""
      } else if ((busy || inflight !== "") && errorText === "") {
        busy = false
        inflight = ""
        errorText = t("noResponse")
      }
    }
  }

  function compose(path) {
    var given = String(path || "")
    var forceWindow = false
    if (given.charAt(0) === "{") {
      try {
        var payload = JSON.parse(given)
        given = payload.path ? String(payload.path) : ""
        if (payload.forceOpen === true) forceWindow = true
      } catch (e) {}
    }
    imagePath = given
    draft = ""
    answer = ""
    note = ""
    reasoning = ""
    streamStep = ""
    streamRaw = ""
    liveThink = ""
    errorText = ""
    userTyped = false
    backgroundRun = false
    hasUnreadAnswer = false
    marks = []
    cropNorm = null
    aiPrompts = []
    recommendedModelIdx = -1
    recommendedCategory = ""
    if (given.length > 0) previewOpen = true

    if (minimalMode && !forceWindow && given.length > 0) {
      silentRun = true
      windowOpen = false
      startRead()
    } else {
      showWindow()
      if (imagePath.length > 0 && autosend) {
        startRead()
      }
    }
  }

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = {} }
    if (payload.path) {
      payload.forceOpen = true
      compose(JSON.stringify(payload))
    } else {
      showWindow()
    }
  }

  function close() { closeWindow() }

  function ask(arg) {
    var payload = {}
    try { payload = JSON.parse(arg || "{}") } catch (e) { return "bad-json" }
    if (!payload.path) return "no-path"
    compose(String(payload.path))
    return "ok"
  }

  function offer(arg) {
    var payload = {}
    try { payload = JSON.parse(arg || "{}") } catch (e) { return "bad-json" }
    if (payload.path) compose(String(payload.path))
    else showWindow()
    return "ok"
  }

  function ping() { return "ok" }

  function status() {
    return JSON.stringify({
      phase: windowOpen ? (answer !== "" ? "chat" : "compose") : (backgroundRun ? "background" : "idle"),
      provider: provider,
      model: model,
      autosend: autosend,
      minimizeOnSend: minimizeOnSend,
      minimalMode: minimalMode,
      showReason: showReason,
      lang: lang,
      activeLang: activeLang,
      watch: watch,
      typed: userTyped,
      stage: stage,
      backgroundRun: backgroundRun,
      hasUnreadAnswer: hasUnreadAnswer,
      image: imagePath,
      open: windowOpen
    })
  }

  Component.onCompleted: {
    startWatch()
    loadAgents()
    loadProviders()
  }

  function startWatch() {
    if (watchProc.running) return
    watchProc.command = [binPath(), "watch"]
    watchProc.running = true
  }

  FileView {
    id: themeColorsFile
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyThemeColors(text())
  }

  Connections {
    target: Color
    function onAccentChanged() {
      themeColorsFile.reload()
      if (root.answer !== "") root.answerBlocks = root.parseMarkdownBlocks(root.answer)
    }
    function onBackgroundChanged() {
      themeColorsFile.reload()
      if (root.answer !== "") root.answerBlocks = root.parseMarkdownBlocks(root.answer)
    }
  }

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/omarchy/aeye.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.applyConfig(text())
  }

  FileView {
    id: answerFile
    onLoaded: root.takeAnswer(text())
  }

  Process {
    id: configProc
    property var queue: []
    onExited: {
      if (queue.length === 0) return
      var next = queue[0]
      queue = queue.slice(1)
      command = next
      running = true
    }
  }

  Process {
    id: watchProc
    property int fails: 0
    stdout: SplitParser { onRead: function(line) { root.noteShot(line) } }
    onExited: if (fails < 5) { fails += 1; restartTimer.restart() }
  }

  Process {
    id: askProc
    property int gen: 0
    stdout: SplitParser { onRead: function(line) { root.onAskLine(line) } }
    onExited: root.onAskExit()
  }

  Timer {
    id: restartTimer
    interval: 2000
    onTriggered: root.startWatch()
  }

  Timer {
    id: copyResetTimer
    interval: 1800
    onTriggered: {
      root.copiedFeedback = false
      root.copiedBlockIdx = -1
    }
  }

  Timer {
    id: tooltipDelay
    interval: 260
    onTriggered: root.positionTooltip()
  }

  // Brief Exclusive focus prime on open, then settle on OnDemand so clicking
  // outside mainCard interacts seamlessly with Hyprland & other applications.
  Timer {
    id: focusPrimeTimer
    interval: 80
    onTriggered: root.focusPrimed = true
  }

  Timer {
    id: remapTimer
    interval: 40
    onTriggered: {
      root.remapping = false
      if (root.windowOpen) {
        root.focusPrimed = false
        focusPrimeTimer.restart()
        Qt.callLater(root.focusField)
      }
    }
  }

  Process {
    id: agentProc
    stdout: StdioCollector { onStreamFinished: root.applyAgents(text) }
  }

  Process {
    id: providersProc
    stdout: StdioCollector { onStreamFinished: root.applyProviders(text) }
  }

  Process {
    id: keySetProc
    onExited: root.loadProviders()
  }

  Process { id: controlProc }
  Process { id: termProc }
  Process {
    id: editProc
    onExited: if (root.editing) root.finishEdit()
  }
  Process { id: copyProc }
  Process { id: notifyProc }
  Process { id: captureProc }

  Timer {
    id: saveResetTimer
    interval: 3200
    onTriggered: {
      if (root.saveStatus === "ok") {
        root.saveDrawerOpen = false
        root.saveStatus = ""
      }
    }
  }

  Process {
    id: exportProc
    stdout: SplitParser { onRead: function(line) { root.onExportLine(line) } }
  }

  Process {
    id: cropProc
    stdout: SplitParser { onRead: function(line) { root.onCropLine(line) } }
  }

  // Live reactive sync to shared Service.qml for BarWidget.qml
  Binding { target: root.service; property: "stage"; value: root.stage; when: root.service !== null }
  Binding { target: root.service; property: "paused"; value: root.paused; when: root.service !== null }
  Binding { target: root.service; property: "windowOpen"; value: root.windowOpen; when: root.service !== null }
  Binding { target: root.service; property: "backgroundRun"; value: root.backgroundRun; when: root.service !== null }
  Binding { target: root.service; property: "hasUnreadAnswer"; value: root.hasUnreadAnswer; when: root.service !== null }
  Binding { target: root.service; property: "hasAnswer"; value: root.answer !== ""; when: root.service !== null }
  Binding { target: root.service; property: "hasImage"; value: root.imagePath !== ""; when: root.service !== null }
  Binding { target: root.service; property: "producerName"; value: root.producerName; when: root.service !== null }
  Binding { target: root.service; property: "modelLabel"; value: root.modelLabel; when: root.service !== null }
  Binding { target: root.service; property: "visionWhy"; value: root.visionWhy; when: root.service !== null }
  Binding { target: root.service; property: "provider"; value: root.provider; when: root.service !== null }
  Binding { target: root.service; property: "model"; value: root.model; when: root.service !== null }
  Binding { target: root.service; property: "autosend"; value: root.autosend; when: root.service !== null }
  Binding { target: root.service; property: "minimizeOnSend"; value: root.minimizeOnSend; when: root.service !== null }
  Binding { target: root.service; property: "minimalMode"; value: root.minimalMode; when: root.service !== null }
  Binding { target: root.service; property: "showReason"; value: root.showReason; when: root.service !== null }
  Binding { target: root.service; property: "systemDebug"; value: root.systemDebug; when: root.service !== null }
  Binding { target: root.service; property: "lastSaveDir"; value: root.lastSaveDir; when: root.service !== null }
  Binding { target: root.service; property: "lang"; value: root.lang; when: root.service !== null }
  Binding { target: root.service; property: "activeLang"; value: root.activeLang; when: root.service !== null }
  Binding { target: root.service; property: "localeDisplayLabel"; value: root.localeDisplayLabel; when: root.service !== null }
  Binding { target: root.service; property: "hudPlacement"; value: root.hudPlacement; when: root.service !== null }
  Binding { target: root.service; property: "customPrompts"; value: root.customPrompts; when: root.service !== null }
  Binding { target: root.service; property: "providerStatuses"; value: root.providerStatuses; when: root.service !== null }
  Binding { target: root.service; property: "colAnalysing"; value: root.colAnalysing; when: root.service !== null }
  Binding { target: root.service; property: "colSuccess"; value: root.colSuccess; when: root.service !== null }

  Connections {
    target: root.service
    function onOpenHudRequested() { root.showWindow() }
    function onCaptureRequested() { root.runCapture() }
    function onPauseToggleRequested() { root.togglePause() }
    function onStopAskRequested() { root.stopAsk() }
    function onPickModelRequested(index) { root.pickModelAt(index) }
    function onSetAutosendRequested(on) { root.pickAutosend(on) }
    function onSetMinimizeOnSendRequested(on) { root.pickMinimizeOnSend(on) }
    function onSetMinimalModeRequested(on) { root.pickMinimalMode(on) }
    function onSetShowReasonRequested(on) { root.pickShowReason(on) }
    function onSetSystemDebugRequested(on) { root.pickSystemDebug(on) }
    function onCycleLocaleRequested(dir) { root.cycleLocale(dir) }
    function onSetHudPlacementRequested(placement) { root.pickHudPlacement(placement) }
    function onAddCustomPromptRequested(phrase) { root.addCustomPromptText(phrase) }
    function onRemoveCustomPromptRequested(phrase) { root.removeCustomPrompt(phrase) }
    function onRefreshProvidersRequested() { root.loadProviders() }
    function onSetApiKeyRequested(vendor, apiKey) { root.setApiKey(vendor, apiKey) }
  }

  component PlainText: Text {
    textFormat: Text.PlainText
  }

  component NavButton: Rectangle {
    id: navBtn
    property string icon: ""
    property string label: ""
    property string tip: ""
    property bool accent: false
    property bool active: false
    property bool danger: false
    property color customColor: Color.accent
    signal pressed()

    width: btnRow.implicitWidth + Style.space(18)
    height: Style.space(30)
    radius: Style.space(8)
    color: {
      if (danger && btnMouse.containsMouse) return Util.alpha(Color.urgent, 0.22)
      if (accent) return btnMouse.containsMouse ? Util.alpha(customColor, 0.32) : Util.alpha(customColor, 0.2)
      if (active) return Util.alpha(customColor, 0.18)
      return btnMouse.containsMouse ? root.surfaceHover : root.surface
    }
    border.width: 1
    border.color: {
      if (danger && btnMouse.containsMouse) return Color.urgent
      if (accent || active) return customColor
      return btnMouse.containsMouse ? Util.alpha(root.fg, 0.28) : root.line
    }

    Behavior on color { ColorAnimation { duration: Style.duration(130) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(130) } }

    Row {
      id: btnRow
      anchors.centerIn: parent
      spacing: Style.space(5)
      PlainText {
        visible: navBtn.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: navBtn.icon
        color: navBtn.danger && btnMouse.containsMouse ? Color.urgent : (navBtn.accent || navBtn.active ? navBtn.customColor : root.fg)
        font.family: root.face
        font.pixelSize: Style.font.caption
      }
      PlainText {
        visible: navBtn.label !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: navBtn.label
        color: navBtn.danger && btnMouse.containsMouse ? Color.urgent : (navBtn.active ? navBtn.customColor : root.fg)
        font.family: root.face
        font.pixelSize: Style.font.caption
        font.bold: navBtn.accent || navBtn.active
      }
    }

    onTipChanged: if (btnMouse.containsMouse && tip !== "") root.setHover(navBtn, true, tip)

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: root.setHover(navBtn, containsMouse, navBtn.tip)
      onClicked: {
        root.tooltipShown = false
        navBtn.pressed()
      }
    }
  }

  PanelWindow {
    id: win
    visible: root.windowOpen && !root.remapping
    anchors.top: true
    anchors.bottom: true
    anchors.left: !root.isDocked || root.hudPlacement === "dock-left"
    anchors.right: !root.isDocked || root.hudPlacement === "dock-right"
    implicitWidth: root.isDocked ? Style.space(460) : 0
    color: "transparent"
    // In dock-left/dock-right mode, ExclusionMode.Normal + explicit exclusiveZone
    // reserves exact space inside Hyprland's tiling layout so windows tile cleanly alongside Aeye.
    exclusionMode: root.windowOpen && root.isDocked ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.windowOpen && root.isDocked ? win.implicitWidth : 0
    WlrLayershell.namespace: "aeye"
    WlrLayershell.layer: WlrLayer.Top
    // Brief Exclusive prime on open for instant typing, then OnDemand so clicks
    // outside mainCard go straight to other apps on screen without closing HUD.
    WlrLayershell.keyboardFocus: root.windowOpen && !root.editing
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    Region {
      id: cardInputMask
      item: root.windowOpen ? mainCard : null
    }
    mask: root.isDocked || root.dragging ? null : cardInputMask

    FocusScope {
      id: winRoot
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.handleEscape()

      Rectangle {
        id: mainCard
        readonly property int headerNeededWidth: leftHeaderRow.implicitWidth + rightHeaderRow.implicitWidth + Style.space(28) + root.pad * 2
        readonly property real padEdge: Style.space(12)
        readonly property real floatingContentHeight: topSection.implicitHeight + Style.space(12) + middleCol.implicitHeight + (!root.editing ? Style.space(12) + bottomSection.implicitHeight : 0) + root.pad * 2
        width: {
          if (root.isDocked) return Math.max(Style.space(320), winRoot.width - Style.space(12))
          if (root.editing) return Math.min(winRoot.width - Style.space(32), 420)
          if (root.hudPlacement === "corner") return Math.min(winRoot.width - Style.space(32), Math.max(660, headerNeededWidth))
          return Math.min(winRoot.width - Style.space(32), Math.max(840, headerNeededWidth))
        }
        height: {
          if (root.isDocked) return Math.max(Style.space(240), winRoot.height - Style.space(12))
          return Math.min(winRoot.height - Style.space(64), floatingContentHeight)
        }
        x: {
          if (root.isDocked) return Style.space(6)
          if (root.hasCustomPos) return Math.max(Style.space(8), Math.min(winRoot.width - width - Style.space(8), root.customX))
          if (root.hudPlacement === "corner") return Math.max(Style.space(8), winRoot.width - width - padEdge)
          return Math.max(Style.space(8), (winRoot.width - width) / 2)
        }
        y: {
          if (root.isDocked) return Style.space(6)
          if (root.hasCustomPos) return Math.max(Style.space(44), Math.min(winRoot.height - height - Style.space(8), root.customY))
          if (root.hudPlacement === "top") return Style.space(48)
          return Math.max(Style.space(44), winRoot.height - height - padEdge)
        }
        radius: root.radius
        color: Util.alpha(root.bg, 0.96)
        border.width: root.stage === "analysing" ? 1.5 : 1
        border.color: root.stage === "analysing" ? root.colAnalysing : (root.stage === "viewed" ? Util.alpha(root.colSuccess, 0.5) : root.line)
        clip: true

        Behavior on width { enabled: !root.dragging && !root.isDocked; NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        Behavior on height { enabled: !root.dragging && !root.isDocked; NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Style.duration(220) } }

        Rectangle {
          id: topAccentBar
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: root.stage === "analysing" ? Style.space(4) : Style.space(2)
          color: root.stage === "analysing" ? Util.alpha(root.colAnalysing, 0.2) : (root.stage === "viewed" ? Util.alpha(root.colSuccess, 0.55) : Util.alpha(Color.accent, 0.3))

          Rectangle {
            id: pulseRunner
            visible: root.stage === "analysing"
            width: parent.width * 0.42
            height: parent.height
            radius: height / 2
            color: root.colAnalysing
            x: -width
            SequentialAnimation on x {
              running: pulseRunner.visible && !root.paused && Style.duration(100) > 0
              loops: Animation.Infinite
              NumberAnimation { from: -pulseRunner.width; to: topAccentBar.width; duration: Style.duration(950); easing.type: Easing.InOutSine }
              NumberAnimation { from: topAccentBar.width; to: -pulseRunner.width; duration: Style.duration(950); easing.type: Easing.InOutSine }
            }
          }
        }

        // TOP SECTION (Header bar + Editing mode)
        Column {
          id: topSection
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.leftMargin: root.pad
          anchors.rightMargin: root.pad
          anchors.topMargin: root.pad
          spacing: Style.space(10)

          // 1. HEADER BAR (draggable when floating; 2-row compact layout when Hyprland-docked)
          Item {
            id: headerBar
            visible: !root.editing
            width: parent.width
            height: root.isDocked ? Style.space(70) : Style.space(34)

            // Drag handle across header empty space when floating
            MouseArea {
              id: dragArea
              anchors.fill: parent
              enabled: !root.isDocked
              hoverEnabled: true
              cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
              property real pressWinX: 0
              property real pressWinY: 0
              property real startCardX: 0
              property real startCardY: 0
              onContainsMouseChanged: if (!root.dragging) root.setHover(headerBar, containsMouse, root.t("tipDragHud"))
              onPressed: function(mouse) {
                root.clearHover()
                var pt = dragArea.mapToItem(winRoot, mouse.x, mouse.y)
                pressWinX = pt.x
                pressWinY = pt.y
                startCardX = mainCard.x
                startCardY = mainCard.y
                root.customX = startCardX
                root.customY = startCardY
                root.hasCustomPos = true
                root.dragging = true
              }
              onPositionChanged: function(mouse) {
                if (!root.dragging) return
                var pt = dragArea.mapToItem(winRoot, mouse.x, mouse.y)
                root.customX = startCardX + (pt.x - pressWinX)
                root.customY = startCardY + (pt.y - pressWinY)
              }
              onReleased: root.dragging = false
              onCanceled: root.dragging = false
              onDoubleClicked: {
                root.dragging = false
                root.hasCustomPos = false
              }
            }

            Row {
              id: leftHeaderRow
              anchors.left: parent.left
              y: root.isDocked ? 0 : Math.round((parent.height - height) / 2)
              spacing: Style.space(8)

              PlainText {
                visible: !root.isDocked
                anchors.verticalCenter: parent.verticalCenter
                text: "⠿"
                color: dragArea.containsMouse || root.dragging ? Color.accent : Util.alpha(root.fg, 0.35)
                font.family: root.face
                font.pixelSize: Style.font.caption
              }

              // Variant 5A Transparent Theme-Native Wordmark ([A-Eye] ✦ EYE)
              Item {
                anchors.verticalCenter: parent.verticalCenter
                width: hudWmRow.implicitWidth
                height: Style.space(28)

                Row {
                  id: hudWmRow
                  anchors.left: parent.left
                  anchors.top: parent.top
                  spacing: Style.space(4)

                  Canvas {
                    id: hudAEyeLogo
                    width: Style.space(22)
                    height: Style.space(22)
                    anchors.verticalCenter: parent.verticalCenter
                    property color colA: Color.accent
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
                      ctx.strokeStyle = colA
                      ctx.lineWidth = 7.2
                      ctx.beginPath()
                      ctx.moveTo(35, 42); ctx.lineTo(50, 15); ctx.lineTo(65, 42)
                      ctx.moveTo(27, 68); ctx.lineTo(19, 85)
                      ctx.moveTo(73, 68); ctx.lineTo(81, 85)
                      ctx.stroke()
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
                    font.pixelSize: Math.max(9, Style.font.caption - 1)
                    font.bold: true
                  }

                  PlainText {
                    id: hudEyeWord
                    anchors.verticalCenter: parent.verticalCenter
                    text: "EYE"
                    color: root.fg
                    font.family: root.face
                    font.pixelSize: Math.round(Style.font.body * 1.15)
                    font.bold: true
                    font.letterSpacing: 2.2
                  }
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(2)
                  anchors.bottom: parent.bottom
                  width: hudWmRow.implicitWidth - Style.space(2)
                  height: 2
                  radius: 1
                  color: Util.alpha(Color.accent, 0.55)
                }
              }

              // Status Pill
              Rectangle {
                id: statusPill
                anchors.verticalCenter: parent.verticalCenter
                width: statusRow.implicitWidth + Style.space(18)
                height: Style.space(26)
                radius: height / 2
                color: Util.alpha(root.stageColor, root.stage === "analysing" ? 0.22 : 0.14)
                border.width: 1.2
                border.color: root.stageColor

                Row {
                  id: statusRow
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Item {
                    width: Style.space(8)
                    height: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                      id: pulseHalo
                      anchors.centerIn: parent
                      width: parent.width
                      height: parent.height
                      radius: width / 2
                      color: root.stageColor
                      visible: root.stage === "analysing" && !root.paused
                      SequentialAnimation on scale {
                        running: pulseHalo.visible && Style.duration(100) > 0
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 2.2; duration: Style.duration(750); easing.type: Easing.OutQuad }
                        NumberAnimation { from: 2.2; to: 1.0; duration: 0 }
                      }
                      SequentialAnimation on opacity {
                        running: pulseHalo.visible && Style.duration(100) > 0
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 0.0; duration: Style.duration(750); easing.type: Easing.OutQuad }
                        NumberAnimation { from: 0.0; to: 0.8; duration: 0 }
                      }
                    }

                    Rectangle {
                      anchors.centerIn: parent
                      width: Style.space(6)
                      height: Style.space(6)
                      radius: width / 2
                      color: root.stageColor
                    }
                  }

                  PlainText {
                    text: root.stageLabel
                    color: root.stageColor
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                  onContainsMouseChanged: root.setHover(statusPill, containsMouse, root.stageTip)
                }
              }

              // Model Selector Pill (quick cycle; full settings live in top-bar popout)
              Rectangle {
                id: modelPill
                anchors.verticalCenter: parent.verticalCenter
                width: modelBadgeRow.implicitWidth + Style.space(14)
                height: Style.space(26)
                radius: height / 2
                color: modelBadgeMouse.containsMouse ? root.surfaceHover : root.surface
                border.width: 1
                border.color: modelBadgeMouse.containsMouse ? Color.accent : root.line

                Row {
                  id: modelBadgeRow
                  anchors.centerIn: parent
                  spacing: Style.space(5)

                  PlainText {
                    text: "✦"
                    color: Color.accent
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                  }

                  PlainText {
                    text: root.producerName + " · " + root.modelLabel
                    color: root.fg
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: modelBadgeMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: root.setHover(modelPill, containsMouse, root.t("tipModelPill"))
                  onClicked: {
                    root.tooltipShown = false
                    root.cycleActiveModel()
                  }
                }
              }

              // Opt-in System Debug indicator pill (visible only when System Debug is enabled)
              Rectangle {
                id: sysDebugPill
                visible: root.systemDebug
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? sysDebugRow.implicitWidth + Style.space(14) : 0
                height: Style.space(26)
                radius: height / 2
                color: sysDebugMouse.containsMouse ? Util.alpha(Color.urgent, 0.25) : Util.alpha(Color.urgent, 0.14)
                border.width: 1
                border.color: Util.alpha(Color.urgent, 0.75)

                Row {
                  id: sysDebugRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  PlainText {
                    text: "⚠"
                    color: Color.urgent
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  PlainText {
                    text: "SYSDEBUG"
                    color: Color.urgent
                    font.family: root.face
                    font.pixelSize: Math.max(9, Style.font.caption - 1)
                    font.bold: true
                  }
                }

                MouseArea {
                  id: sysDebugMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: root.setHover(sysDebugPill, containsMouse, root.t("tipSysDebugHud"))
                  onClicked: {
                    root.clearHover()
                    root.pickSystemDebug(false)
                  }
                }
              }
            }

            Row {
              id: rightHeaderRow
              x: root.isDocked ? 0 : Math.max(0, parent.width - width)
              y: root.isDocked ? Style.space(36) : Math.round((parent.height - height) / 2)
              spacing: Style.space(5)

              NavButton {
                icon: root.previewOpen ? "▾" : "◫"
                label: root.isDocked ? "" : (root.previewOpen ? root.t("hideImage") : root.t("image"))
                tip: root.t("tipImage")
                active: root.previewOpen
                onPressed: root.previewOpen = !root.previewOpen
              }

              NavButton {
                icon: "✎"
                label: root.isDocked ? "Edit" : "Omasnap"
                tip: root.t("tipOmasnap")
                onPressed: root.beginEdit()
              }

              NavButton {
                icon: ">_"
                label: "CLI"
                tip: root.t("tipCli")
                onPressed: root.openTerminal()
              }

              // Clean 1px visual divider between actions and window chrome
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Style.space(16)
                color: root.line
                opacity: 0.7
              }

              NavButton {
                readonly property string nextMode: root.nextHudPlacement()
                icon: root.placementIcon(nextMode)
                label: ""
                tip: root.placementLabel(root.hudPlacement) + " → " + root.t("moveHudTo") + " " + root.placementLabel(nextMode)
                active: root.isDocked
                onPressed: root.cycleHudPlacement()
              }

              NavButton {
                icon: "—"
                label: ""
                tip: root.t("tipMinimize")
                onPressed: root.minimizeToBackground()
              }

              NavButton {
                icon: "✕"
                label: ""
                tip: root.t("tipClose")
                danger: true
                onPressed: root.closeWindow()
              }
            }
          }

          // 2. EDITING MODE
          Row {
            visible: root.editing
            width: parent.width
            spacing: Style.space(12)

            NavButton {
              icon: "✓"
              label: root.t("doneEdit")
              tip: root.t("tipDoneEdit")
              accent: true
              onPressed: root.finishEdit()
            }

            PlainText {
              anchors.verticalCenter: parent.verticalCenter
              text: root.t("editMsg")
              color: root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
            }
          }
        }

        // MIDDLE SCROLLABLE CONTENT (Preview + Scan + Answer + Smart Tip + Prompt Chips)
        Flickable {
          id: middleScroll
          visible: !root.editing
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: topSection.bottom
          anchors.bottom: bottomSection.top
          anchors.leftMargin: root.pad
          anchors.rightMargin: root.pad
          anchors.topMargin: Style.space(10)
          anchors.bottomMargin: Style.space(10)
          contentWidth: width
          contentHeight: middleCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height + 2

          Column {
            id: middleCol
            width: middleScroll.width
            spacing: Style.space(10)

            // 3. PREVIEW & DEDICATED INLINE ANNOTATION BAR (never covers screenshot!)
            Rectangle {
              id: frame
              width: parent.width
              visible: root.previewOpen && root.imagePath !== "" && !root.editing
              height: visible ? (root.isDocked ? Style.space(260) : Style.space(245)) : 0
              radius: Style.space(10)
              color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.55)
              border.width: 1
              border.color: root.stage === "analysing" ? root.colAnalysing : root.line
              clip: true

              // Dedicated slim top bar for Arrow / Box / Crop + hint (zero overlap on screenshot)
              Rectangle {
                id: annotBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.space(36)
                color: Util.alpha(root.fg, 0.04)

                PlainText {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.right: toolBarRow.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !root.isDocked && root.marks.length === 0 && root.cropNorm === null
                  text: root.t("inlineToolsHint")
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Math.max(10, Style.font.caption - 1)
                  elide: Text.ElideRight
                }

                Row {
                  id: toolBarRow
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Repeater {
                    model: [
                      { id: "arrow", icon: "↗", key: "arrow", tipKey: "tipArrow" },
                      { id: "box", icon: "▢", key: "box", tipKey: "tipBox" },
                      { id: "crop", icon: "✂", key: "crop", tipKey: "tipCrop" }
                    ]
                    delegate: NavButton {
                      required property var modelData
                      height: Style.space(26)
                      icon: modelData.icon
                      label: root.t(modelData.key)
                      tip: root.t(modelData.tipKey)
                      active: root.tool === modelData.id
                      onPressed: root.tool = modelData.id
                    }
                  }

                  NavButton {
                    visible: root.cropNorm !== null
                    height: Style.space(26)
                    icon: "✓"
                    label: root.isDocked ? "" : root.t("applyCrop")
                    tip: root.t("tipApplyCrop")
                    accent: true
                    onPressed: root.applyCrop()
                  }

                  NavButton {
                    visible: root.marks.length > 0 || root.cropNorm !== null
                    height: Style.space(26)
                    icon: "↺"
                    label: root.isDocked ? "" : root.t("clear")
                    tip: root.t("tipClearMarks")
                    onPressed: root.clearMarks()
                  }
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 1
                  color: root.line
                  opacity: 0.55
                }
              }

              // Clean unobstructed screenshot canvas below annotBar
              Item {
                id: shotViewport
                anchors.top: annotBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true

                Image {
                  id: shot
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  visible: frame.visible
                  source: root.fileUrl(root.imagePath)
                  fillMode: Image.PreserveAspectFit
                  asynchronous: false
                  smooth: true
                  mipmap: true
                  cache: false
                  onStatusChanged: if (status === Image.Ready) markCanvas.requestPaint()
                }

                Connections {
                  target: root
                  function onPreviewOpenChanged() {
                    if (root.previewOpen) Qt.callLater(function() { markCanvas.requestPaint() })
                  }
                }

                Rectangle {
                  id: laserLine
                  visible: root.stage === "analysing" && !root.paused
                  width: parent.width
                  height: Style.space(3)
                  color: root.colAnalysing
                  y: 0

                  Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Style.space(22)
                    color: Util.alpha(root.colAnalysing, 0.18)
                  }

                  SequentialAnimation on y {
                    running: laserLine.visible && Style.duration(100) > 0
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: shotViewport.height; duration: Style.duration(1250); easing.type: Easing.InOutSine }
                    NumberAnimation { from: shotViewport.height; to: 0; duration: Style.duration(1250); easing.type: Easing.InOutSine }
                  }
                }

                Canvas {
                  id: markCanvas
                  anchors.fill: shot
                  onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var area = root.imageContent()
                    function strokeMark(mark, dashed) {
                      var x1 = area.x + mark.x1 * area.w
                      var y1 = area.y + mark.y1 * area.h
                      var x2 = area.x + mark.x2 * area.w
                      var y2 = area.y + mark.y2 * area.h
                      ctx.strokeStyle = dashed ? "#ffffff" : "#d6ff4a"
                      ctx.fillStyle = "#d6ff4a"
                      ctx.lineWidth = 2.2
                      if (mark.kind === "box" || mark.kind === "crop") {
                        ctx.strokeRect(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1))
                        return
                      }
                      ctx.beginPath()
                      ctx.moveTo(x1, y1)
                      ctx.lineTo(x2, y2)
                      ctx.stroke()
                      var angle = Math.atan2(y2 - y1, x2 - x1)
                      ctx.beginPath()
                      ctx.moveTo(x2, y2)
                      ctx.lineTo(x2 + 11 * Math.cos(angle + 2.6), y2 + 11 * Math.sin(angle + 2.6))
                      ctx.lineTo(x2 + 11 * Math.cos(angle - 2.6), y2 + 11 * Math.sin(angle - 2.6))
                      ctx.closePath()
                      ctx.fill()
                    }
                    for (var i = 0; i < root.marks.length; i++) strokeMark(root.marks[i], false)
                    if (root.cropNorm) strokeMark(root.cropNorm, false)
                    if (root.marking && root.dragFrom && root.dragTo)
                      strokeMark({ kind: root.tool === "crop" ? "crop" : root.tool, x1: root.dragFrom.x, y1: root.dragFrom.y, x2: root.dragTo.x, y2: root.dragTo.y }, true)
                  }
                }

                MouseArea {
                  enabled: root.previewOpen
                  anchors.fill: shot
                  cursorShape: Qt.CrossCursor
                  acceptedButtons: Qt.LeftButton
                  onPressed: function(mouse) {
                    var point = root.toNorm(mouse.x, mouse.y)
                    root.resizeCorner = root.tool === "crop" ? root.hitCorner(point) : ""
                    root.dragFrom = point
                    root.dragTo = point
                    root.marking = root.resizeCorner === ""
                  }
                  onPositionChanged: function(mouse) {
                    var point = root.toNorm(mouse.x, mouse.y)
                    if (root.resizeCorner !== "") {
                      root.moveCorner(root.resizeCorner, point)
                      return
                    }
                    root.dragTo = point
                    markCanvas.requestPaint()
                  }
                  onReleased: function(mouse) {
                    if (root.resizeCorner !== "") {
                      root.resizeCorner = ""
                      root.marking = false
                      return
                    }
                    root.commitDrag(root.dragFrom, root.toNorm(mouse.x, mouse.y))
                    root.marking = false
                    root.dragFrom = null
                    root.dragTo = null
                  }
                }
              }
            }

          // 5. DOCK: ACTIVE SCAN BANNER, ANSWER CARD & PROMPTS
          Column {
            id: dock
            visible: !root.editing
            width: parent.width
            spacing: Style.space(10)

            Rectangle {
              width: parent.width
              visible: root.stage === "analysing"
              height: visible ? Style.space(44) : 0
              radius: Style.space(10)
              color: Util.alpha(root.colAnalysing, 0.12)
              border.width: 1
              border.color: Util.alpha(root.colAnalysing, 0.6)

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  Repeater {
                    model: 4
                    delegate: Rectangle {
                      required property int index
                      width: Style.space(4)
                      height: Style.space(14)
                      radius: width / 2
                      color: root.colAnalysing
                      SequentialAnimation on height {
                        running: root.stage === "analysing" && !root.paused && Style.duration(100) > 0
                        loops: Animation.Infinite
                        PauseAnimation { duration: Style.duration(index * 110) }
                        NumberAnimation { from: Style.space(6); to: Style.space(18); duration: Style.duration(280); easing.type: Easing.InOutSine }
                        NumberAnimation { from: Style.space(18); to: Style.space(6); duration: Style.duration(280); easing.type: Easing.InOutSine }
                      }
                    }
                  }
                }

                PlainText {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.paused
                    ? root.t("paused")
                    : (root.streamStep !== "" ? (root.producerName + " " + root.modelLabel + " · " + root.streamStep) : (root.producerName + " " + root.modelLabel + root.t("inspecting")))
                  color: root.colAnalysing
                  font.family: root.face
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, dock.width - Style.space(210))
                }
              }

              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                NavButton {
                  icon: root.paused ? "▶" : "⏸"
                  label: root.paused ? root.t("resume") : root.t("pause")
                  tip: root.t("tipPause")
                  customColor: root.colAnalysing
                  active: true
                  onPressed: root.togglePause()
                }
                NavButton {
                  icon: "■"
                  label: root.t("stop")
                  tip: root.t("tipStop")
                  danger: true
                  onPressed: root.stopAsk()
                }
              }
            }

            Rectangle {
              width: parent.width
              visible: root.errorText !== ""
              height: visible ? errText.implicitHeight + Style.space(16) : 0
              radius: Style.space(8)
              color: Util.alpha(Color.urgent, 0.14)
              border.width: 1
              border.color: Color.urgent

              PlainText {
                id: errText
                anchors.centerIn: parent
                width: parent.width - Style.space(24)
                text: "⚠ " + root.errorText
                color: Color.urgent
                font.family: root.face
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }
            }

            // 5a. LIVE VISUAL REASONING CARD (streams in real time while scanning + stays complete after answer)
            Rectangle {
              width: parent.width
              visible: root.showReason && (root.stage === "analysing" || root.reasoning !== "" || root.liveThink !== "")
              height: visible ? liveReasonCol.implicitHeight + Style.space(20) : 0
              radius: Style.space(10)
              color: Util.alpha(root.colAnalysing, root.stage === "analysing" ? 0.08 : 0.05)
              border.width: 1
              border.color: root.stage === "analysing" ? Util.alpha(root.colAnalysing, 0.55) : Util.alpha(root.line, 0.9)
              clip: true

              Rectangle {
                width: Style.space(3)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: root.colAnalysing
              }

              Column {
                id: liveReasonCol
                x: Style.space(14)
                y: Style.space(10)
                width: parent.width - Style.space(24)
                spacing: Style.space(6)

                Row {
                  spacing: Style.space(6)
                  PlainText {
                    text: "∴ Visual Reasoning"
                    color: root.colAnalysing
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  PlainText {
                    visible: root.stage === "analysing"
                    text: root.streamStep !== "" ? ("· " + root.streamStep) : "· LIVE"
                    color: root.dim
                    font.family: root.face
                    font.pixelSize: Math.max(10, Style.font.caption - 1)
                    elide: Text.ElideRight
                  }
                }

                TextEdit {
                  width: parent.width
                  visible: root.reasoning !== "" || root.liveThink !== ""
                  text: root.formatInlineHtml(root.reasoning !== "" ? root.reasoning : root.liveThink).replace(/\n/g, "<br/>")
                  textFormat: TextEdit.RichText
                  readOnly: true
                  selectByMouse: true
                  color: root.fg
                  selectionColor: Color.accent
                  selectedTextColor: Color.background
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  wrapMode: TextEdit.WordWrap
                  Keys.onEscapePressed: root.handleEscape()
                }

                PlainText {
                  width: parent.width
                  visible: root.stage === "analysing" && root.reasoning === "" && root.liveThink === ""
                  text: root.streamStep !== "" ? root.streamStep : (root.producerName + " " + root.modelLabel + root.t("inspecting"))
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  font.italic: true
                  wrapMode: Text.WordWrap
                }
              }
            }

            // 5b. ANSWER CARD (Rich Markdown + Syntax-Highlighted Code Blocks)
            Rectangle {
              width: parent.width
              visible: root.answer !== ""
              height: visible ? answerCol.implicitHeight + Style.space(24) : 0
              radius: Style.space(10)
              color: root.surface
              border.width: 1
              border.color: Util.alpha(root.colSuccess, 0.45)
              clip: true

              Rectangle {
                width: Style.space(4)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: root.colSuccess
              }

              Column {
                id: answerCol
                x: Style.space(16)
                y: Style.space(12)
                width: parent.width - Style.space(28)
                spacing: Style.space(8)

                Item {
                  width: parent.width
                  height: Style.space(24)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    PlainText {
                      text: "✦ " + root.producerName + " " + root.modelLabel + (root.stage === "analysing" ? " · streaming…" : "")
                      color: root.colSuccess
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    NavButton {
                      visible: root.systemDebug
                      height: Style.space(24)
                      icon: ">_"
                      label: root.isDocked ? "" : root.t("fixCli")
                      tip: root.t("tipFixCli")
                      customColor: Color.urgent
                      onPressed: root.openTerminal()
                    }

                    NavButton {
                      height: Style.space(24)
                      icon: root.saveStatus === "ok" ? "✓" : "↓"
                      label: root.saveStatus === "ok" ? root.t("saved") : root.t("save")
                      tip: root.t("tipSave")
                      active: root.saveDrawerOpen || root.saveStatus === "ok"
                      customColor: root.saveStatus === "ok" ? root.colSuccess : Color.accent
                      onPressed: root.openSaveDrawer()
                    }

                    NavButton {
                      height: Style.space(24)
                      icon: root.copiedFeedback ? "✓" : "⎘"
                      label: root.copiedFeedback ? root.t("copied") : root.t("copy")
                      tip: root.t("tipCopy")
                      active: root.copiedFeedback
                      customColor: root.colSuccess
                      onPressed: root.copyAnswer()
                    }
                  }
                }

                // Inline Universal File Export Drawer (.txt, .md, .pdf, .html, .json, or any custom path)
                Rectangle {
                  id: saveDrawer
                  visible: root.saveDrawerOpen
                  width: parent.width
                  height: visible ? saveDrawerCol.implicitHeight + Style.space(14) : 0
                  radius: Style.space(8)
                  color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.55)
                  border.width: 1
                  border.color: root.saveStatus === "err" ? Color.urgent : (root.saveStatus === "ok" ? root.colSuccess : root.line)
                  clip: true

                  Column {
                    id: saveDrawerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(7)
                    spacing: Style.space(6)

                    Flow {
                      width: parent.width
                      spacing: Style.space(5)

                      Repeater {
                        model: [
                          { label: "~/Documents", dir: "~/Documents" },
                          { label: "~/Desktop",   dir: "~/Desktop" },
                          { label: "~/Downloads", dir: "~/Downloads" },
                          { label: "~/",          dir: "~" }
                        ]
                        delegate: Rectangle {
                          required property var modelData
                          width: dirChipLbl.implicitWidth + Style.space(12)
                          height: Style.space(22)
                          radius: Style.space(5)
                          color: dirChipMouse.containsMouse ? root.surfaceHover : root.surface
                          border.width: 1
                          border.color: root.lastSaveDir === modelData.dir ? Color.accent : root.line

                          PlainText {
                            id: dirChipLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.lastSaveDir === modelData.dir ? Color.accent : root.fg
                            font.family: root.face
                            font.pixelSize: Math.max(9, Style.font.caption - 2)
                          }
                          MouseArea {
                            id: dirChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setSaveFolder(modelData.dir)
                          }
                        }
                      }

                      Rectangle {
                        width: 1
                        height: Style.space(20)
                        color: root.line
                        opacity: 0.65
                      }

                      Repeater {
                        model: [".txt", ".md", ".pdf", ".html", ".json"]
                        delegate: Rectangle {
                          required property string modelData
                          readonly property bool isCur: root.savePathText.toLowerCase().endsWith(modelData)
                          width: extChipLbl.implicitWidth + Style.space(12)
                          height: Style.space(22)
                          radius: Style.space(5)
                          color: isCur ? Util.alpha(Color.accent, 0.2) : (extChipMouse.containsMouse ? root.surfaceHover : root.surface)
                          border.width: 1
                          border.color: isCur ? Color.accent : root.line

                          PlainText {
                            id: extChipLbl
                            anchors.centerIn: parent
                            text: modelData
                            color: isCur ? Color.accent : root.fg
                            font.family: root.face
                            font.pixelSize: Math.max(9, Style.font.caption - 2)
                            font.bold: isCur
                          }
                          MouseArea {
                            id: extChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setSaveExtension(modelData)
                          }
                        }
                      }
                    }

                    Row {
                      width: parent.width
                      spacing: Style.space(6)

                      Rectangle {
                        width: parent.width - saveConfirmBtn.width - Style.space(6)
                        height: Style.space(28)
                        radius: Style.space(6)
                        color: savePathInput.activeFocus ? Util.alpha(root.fg, 0.08) : root.surface
                        border.width: 1
                        border.color: savePathInput.activeFocus ? Color.accent : root.line

                        PlainText {
                          anchors.left: parent.left
                          anchors.leftMargin: Style.space(8)
                          anchors.right: parent.right
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          visible: savePathInput.text.length === 0
                          text: root.t("savePathHint")
                          color: root.dim
                          font.family: root.face
                          font.pixelSize: Math.max(10, Style.font.caption - 1)
                          elide: Text.ElideRight
                        }

                        TextInput {
                          id: savePathInput
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(8)
                          anchors.rightMargin: Style.space(8)
                          verticalAlignment: TextInput.AlignVCenter
                          color: root.fg
                          font.family: root.face
                          font.pixelSize: Math.max(10, Style.font.caption - 1)
                          clip: true
                          selectByMouse: true
                          text: root.savePathText
                          onTextEdited: root.savePathText = text
                          onAccepted: root.runExportFile()
                          Keys.onEscapePressed: root.saveDrawerOpen = false
                        }
                      }

                      Rectangle {
                        id: saveConfirmBtn
                        width: saveConfirmLbl.implicitWidth + Style.space(16)
                        height: Style.space(28)
                        radius: Style.space(6)
                        color: saveConfirmMouse.containsMouse ? Qt.lighter(Color.accent, 1.12) : Color.accent

                        PlainText {
                          id: saveConfirmLbl
                          anchors.centerIn: parent
                          text: root.t("save") + " ↵"
                          color: Color.background
                          font.family: root.face
                          font.pixelSize: Math.max(10, Style.font.caption - 1)
                          font.bold: true
                        }

                        MouseArea {
                          id: saveConfirmMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.runExportFile()
                        }
                      }
                    }

                    PlainText {
                      visible: root.saveStatusMsg !== ""
                      width: parent.width
                      text: (root.saveStatus === "ok" ? "✓ " : "⚠ ") + root.saveStatusMsg
                      color: root.saveStatus === "ok" ? root.colSuccess : Color.urgent
                      font.family: root.face
                      font.pixelSize: Math.max(9, Style.font.caption - 1)
                      elide: Text.ElideMiddle
                    }
                  }
                }

                // Structured Markdown & Syntax-Highlighted Code Blocks (100% HTML-escaped)
                Column {
                  width: parent.width
                  spacing: Style.space(7)
                  opacity: root.answerFade
                  Behavior on opacity { NumberAnimation { duration: Style.duration(200) } }

                  Repeater {
                    model: root.answerBlocks
                    delegate: Item {
                      required property var modelData
                      required property int index
                      width: answerCol.width
                      height: {
                        if (modelData.kind === "code") return codeCard.implicitHeight
                        if (modelData.kind === "bullet") return bulletRow.implicitHeight
                        return richTextBlock.implicitHeight
                      }

                      // Heading or Paragraph block
                      TextEdit {
                        id: richTextBlock
                        visible: modelData.kind === "paragraph" || modelData.kind === "heading"
                        width: parent.width
                        text: modelData.html
                        textFormat: TextEdit.RichText
                        readOnly: true
                        selectByMouse: true
                        color: modelData.kind === "heading" ? Color.accent : root.fg
                        selectionColor: Color.accent
                        selectedTextColor: Color.background
                        font.family: root.face
                        font.pixelSize: modelData.kind === "heading" ? Math.round(Style.font.body * 1.08) : Style.font.body
                        font.bold: modelData.kind === "heading"
                        wrapMode: TextEdit.WordWrap
                        Keys.onEscapePressed: root.handleEscape()
                      }

                      // Bullet / numbered list item
                      Row {
                        id: bulletRow
                        visible: modelData.kind === "bullet"
                        width: parent.width
                        spacing: Style.space(8)

                        PlainText {
                          text: modelData.marker
                          color: Color.accent
                          font.family: root.face
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }

                        TextEdit {
                          width: parent.width - Style.space(24)
                          text: modelData.html
                          textFormat: TextEdit.RichText
                          readOnly: true
                          selectByMouse: true
                          color: root.fg
                          selectionColor: Color.accent
                          selectedTextColor: Color.background
                          font.family: root.face
                          font.pixelSize: Style.font.body
                          wrapMode: TextEdit.WordWrap
                          Keys.onEscapePressed: root.handleEscape()
                        }
                      }

                      // Fenced Code Block with Syntax Highlighting + 1-click Copy button
                      Rectangle {
                        id: codeCard
                        visible: modelData.kind === "code"
                        width: parent.width
                        implicitHeight: codeCol.implicitHeight + Style.space(14)
                        radius: Style.space(8)
                        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.72)
                        border.width: 1
                        border.color: root.line
                        clip: true

                        Column {
                          id: codeCol
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.top: parent.top
                          anchors.margins: Style.space(8)
                          spacing: Style.space(6)

                          Item {
                            width: parent.width
                            height: Style.space(20)

                            PlainText {
                              anchors.left: parent.left
                              anchors.verticalCenter: parent.verticalCenter
                              text: modelData.lang !== "" ? modelData.lang.toUpperCase() : "CODE"
                              color: root.dim
                              font.family: root.face
                              font.pixelSize: Math.max(9, Style.font.caption - 2)
                              font.bold: true
                              font.letterSpacing: 1.2
                            }

                            Rectangle {
                              anchors.right: parent.right
                              anchors.verticalCenter: parent.verticalCenter
                              width: cpCodeLbl.implicitWidth + Style.space(12)
                              height: Style.space(20)
                              radius: Style.space(5)
                              color: cpCodeMouse.containsMouse ? root.surfaceHover : root.surface
                              border.width: 1
                              border.color: root.copiedBlockIdx === index ? root.colSuccess : root.line

                              PlainText {
                                id: cpCodeLbl
                                anchors.centerIn: parent
                                text: root.copiedBlockIdx === index ? ("✓ " + root.t("copied")) : ("⎘ " + root.t("copy"))
                                color: root.copiedBlockIdx === index ? root.colSuccess : root.fg
                                font.family: root.face
                                font.pixelSize: Math.max(9, Style.font.caption - 2)
                              }

                              MouseArea {
                                id: cpCodeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyCodeBlock(modelData.raw, index)
                              }
                            }
                          }

                          Rectangle { width: parent.width; height: 1; color: root.line; opacity: 0.45 }

                          TextEdit {
                            width: parent.width
                            text: modelData.html
                            textFormat: TextEdit.RichText
                            readOnly: true
                            selectByMouse: true
                            color: root.fg
                            selectionColor: Color.accent
                            selectedTextColor: Color.background
                            font.family: root.face
                            font.pixelSize: Style.font.caption
                            wrapMode: TextEdit.WordWrap
                            Keys.onEscapePressed: root.handleEscape()
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // 5b. SMART MODEL RECOMMENDATION BANNER (from Auto-analyze domain detection)
            Rectangle {
              id: recBanner
              visible: root.recommendedModelIdx >= 0 && root.recommendedModelIdx < root.modelChoices.length
              width: parent.width
              height: visible ? Style.space(32) : 0
              radius: Style.space(8)
              color: recMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.accent, 0.11)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.55)
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                PlainText {
                  text: "✦"
                  color: root.colAnalysing
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                PlainText {
                  text: root.recommendedCategoryLabel() + " — " + root.t("recSwitchTo") + " " + (root.recommendedModelIdx >= 0 ? (root.modelChoices[root.recommendedModelIdx].vendor + " " + root.modelChoices[root.recommendedModelIdx].label) : "")
                  color: root.fg
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              PlainText {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                color: recDismissMouse.containsMouse ? Color.urgent : root.dim
                font.family: root.face
                font.pixelSize: Style.font.body
                font.bold: true
                MouseArea {
                  id: recDismissMouse
                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.recommendedModelIdx = -1
                    root.recommendedCategory = ""
                  }
                }
              }

              MouseArea {
                id: recMouse
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width - Style.space(28)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setHover(recBanner, containsMouse, root.t("tipRecModel"))
                onClicked: {
                  root.clearHover()
                  if (root.recommendedModelIdx >= 0) root.pickModelAt(root.recommendedModelIdx)
                }
              }
            }

            // 6. AI SUGGESTIONS (✦) + USER PINNED PROMPTS (★)
            Flow {
              width: parent.width
              spacing: Style.space(6)
              visible: root.aiPrompts.length > 0 || root.customPrompts.length > 0

              Repeater {
                model: root.aiPrompts
                delegate: Rectangle {
                  id: aiChip
                  required property string modelData
                  readonly property bool isSelected: root.draft === modelData

                  width: aiChipRow.implicitWidth + Style.space(18)
                  height: Style.space(28)
                  radius: height / 2
                  color: isSelected ? root.surfaceActive : (aiChipMouse.containsMouse ? root.surfaceHover : Util.alpha(Color.accent, 0.08))
                  border.width: 1
                  border.color: Color.accent

                  Row {
                    id: aiChipRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    PlainText {
                      text: "✦"
                      color: Color.accent
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    PlainText {
                      text: modelData
                      color: root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: aiChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.setHover(aiChip, containsMouse, root.t("tipAiChip"))
                    onClicked: {
                      root.tooltipShown = false
                      root.usePrompt(modelData)
                    }
                  }
                }
              }

              Repeater {
                model: root.customPrompts
                delegate: Rectangle {
                  id: customChip
                  required property string modelData
                  readonly property bool isSelected: root.draft === modelData

                  width: Math.min(dock.width, customChipRow.implicitWidth + Style.space(16))
                  height: Style.space(28)
                  radius: height / 2
                  color: isSelected ? Util.alpha(root.colSuccess, 0.2) : (customChipMouse.containsMouse ? root.surfaceHover : root.surface)
                  border.width: 1
                  border.color: isSelected ? root.colSuccess : (customChipMouse.containsMouse ? Util.alpha(root.fg, 0.35) : root.line)

                  Row {
                    id: customChipRow
                    anchors.centerIn: parent
                    spacing: Style.space(5)

                    PlainText {
                      text: "★"
                      color: root.colSuccess
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                    }

                    PlainText {
                      text: modelData
                      color: root.fg
                      font.family: root.face
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, dock.width - Style.space(48))
                    }

                    PlainText {
                      text: "×"
                      color: delMouse.containsMouse ? Color.urgent : root.dim
                      font.family: root.face
                      font.pixelSize: Style.font.body
                      font.bold: true

                      MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.setHover(customChip, containsMouse, root.t("tipCustomChip"))
                        onClicked: {
                          root.clearHover()
                          root.removeCustomPrompt(modelData)
                        }
                      }
                    }
                  }

                  MouseArea {
                    id: customChipMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width - Style.space(22)
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.setHover(customChip, containsMouse, root.t("tipCustomChip"))
                    onClicked: function(mouse) {
                      root.clearHover()
                      if (mouse.button === Qt.RightButton) root.removeCustomPrompt(modelData)
                      else root.usePrompt(modelData)
                    }
                  }
                }
              }
            }
          }
        }
        }

        // BOTTOM COMPOSER SECTION (Input Bar + Footer — pinned cleanly to bottom when docked!)
        Column {
          id: bottomSection
          visible: !root.editing
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: root.pad
          anchors.rightMargin: root.pad
          anchors.bottomMargin: root.pad
          spacing: Style.space(8)

          // 7. INPUT BAR
          Rectangle {
            id: inputBar
            width: parent.width
            height: Style.space(44)
            radius: Style.space(10)
            color: draftInput.activeFocus ? Util.alpha(root.fg, 0.06) : root.surface
            border.width: draftInput.activeFocus ? 1.5 : 1
            border.color: draftInput.activeFocus ? Color.accent : root.line

            PlainText {
              id: promptIcon
              anchors.left: parent.left
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              text: "❯"
              color: draftInput.activeFocus ? Color.accent : root.dim
              font.family: root.face
              font.pixelSize: Style.font.body
              font.bold: true
            }

            PlainText {
              anchors.left: promptIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: inputActions.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              visible: draftInput.text.length === 0
              text: root.t("placeholder")
              color: root.dim
              font.family: root.face
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            TextInput {
              id: draftInput
              anchors.left: promptIcon.right
              anchors.right: inputActions.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              verticalAlignment: TextInput.AlignVCenter
              color: root.fg
              font.family: root.face
              font.pixelSize: Style.font.body
              clip: true
              selectByMouse: true
              text: root.draft
              onTextEdited: {
                root.draft = text
                if (text.length > 0) root.userTyped = true
              }
              onAccepted: root.sendDraft()
              Keys.onEscapePressed: root.handleEscape()
            }

            Row {
              id: inputActions
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Rectangle {
                id: clearInputBtn
                visible: root.draft.length > 0
                width: Style.space(24)
                height: Style.space(24)
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: clearInputMouse.containsMouse ? root.surfaceHover : "transparent"

                PlainText {
                  anchors.centerIn: parent
                  text: "✕"
                  color: root.dim
                  font.family: root.face
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: clearInputMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: root.setHover(clearInputBtn, containsMouse, root.t("tipClearInput"))
                  onClicked: {
                    root.clearHover()
                    root.draft = ""
                    root.focusField()
                  }
                }
              }

              NavButton {
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(30)
                icon: "★"
                label: root.isDocked ? "" : root.t("pin")
                tip: root.t("tipPin")
                active: root.draft.replace(/^\s+|\s+$/g, "").length > 0
                customColor: root.colSuccess
                onPressed: root.addCustomPrompt()
              }

              Rectangle {
                id: sendBtn
                readonly property bool canSend: root.draft.replace(/^\s+|\s+$/g, "").length > 0 && root.imagePath !== ""
                width: sendRow.implicitWidth + Style.space(16)
                height: Style.space(30)
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.space(7)
                color: canSend ? (sendMouse.containsMouse ? Qt.lighter(Color.accent, 1.15) : Color.accent) : root.surface
                border.width: 1
                border.color: canSend ? Color.accent : root.line

                Row {
                  id: sendRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  PlainText {
                    text: root.t("send")
                    color: parent.parent.canSend ? Color.background : root.dim
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  PlainText {
                    text: "↵"
                    color: parent.parent.canSend ? Color.background : root.dim
                    font.family: root.face
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: sendMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: parent.canSend ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onContainsMouseChanged: root.setHover(sendBtn, containsMouse, root.t("tipSend"))
                  onClicked: {
                    root.tooltipShown = false
                    if (parent.canSend) root.sendDraft()
                  }
                }
              }
            }
          }

          // 8. FOOTER
          Item {
            width: parent.width
            height: Style.space(18)

            PlainText {
              anchors.left: parent.left
              anchors.right: shortcutLegend.visible ? shortcutLegend.left : parent.right
              anchors.rightMargin: shortcutLegend.visible ? Style.space(12) : 0
              anchors.verticalCenter: parent.verticalCenter
              text: root.hoverTip !== "" ? ("ⓘ " + root.hoverTip) : (root.hint !== "" ? root.hint : root.t("defaultHint"))
              color: root.hoverTip !== "" ? root.fg : root.dim
              font.family: root.face
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }
            }

            PlainText {
              id: shortcutLegend
              visible: !root.isDocked
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "↵ " + root.t("send") + "  ·  ★ " + root.t("pin") + "  ·  Esc"
              color: Util.alpha(root.fg, 0.38)
              font.family: root.face
              font.pixelSize: Style.font.caption
            }
          }
        }

        // 9. FLOATING HOVER TOOLTIP
        Rectangle {
          id: tooltipBox
          z: 100
          x: root.tooltipX
          y: root.tooltipY
          implicitWidth: Math.min(mainCard.width - Style.space(20), tooltipLabel.implicitWidth + Style.space(18))
          implicitHeight: tooltipLabel.implicitHeight + Style.space(10)
          radius: Style.space(7)
          color: Util.alpha(Color.tooltip.background, 0.97)
          border.width: 1
          border.color: Color.tooltip.border
          visible: opacity > 0.01
          opacity: root.tooltipShown && root.hoverTip !== "" ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }

          PlainText {
            id: tooltipLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, mainCard.width - Style.space(38))
            text: root.hoverTip
            color: Color.tooltip.text
            font.family: root.face
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}

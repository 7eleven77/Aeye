import QtQuick
import qs.Commons

// Canonical Aeye "Utvalg" brand mark (direction 2 from brand/logo/capture-icon-*):
// Solid sculptural eye framed by four crisp square screenshot corner brackets.
// Adapts live to the active Omarchy theme (Color.foreground / Color.accent):
// - Idle: crisp cutout pupil through the solid eye.
// - Active: pupil illuminates in the live theme accentColor.
// - Scanning: horizontal scan slit across the eye + pulsing accent pupil.
// - Ready: pupil illuminates in readyColor.
Item {
  id: mark

  property color color: Color.foreground
  property color accentColor: Color.accent
  property color readyColor: Color.accent
  property bool active: false
  property bool scanning: false
  property bool ready: false
  property real pulse: 0

  onColorChanged: plate.requestPaint()
  onAccentColorChanged: plate.requestPaint()
  onReadyColorChanged: plate.requestPaint()
  onActiveChanged: plate.requestPaint()
  onScanningChanged: plate.requestPaint()
  onReadyChanged: plate.requestPaint()
  onPulseChanged: plate.requestPaint()
  onWidthChanged: plate.requestPaint()
  onHeightChanged: plate.requestPaint()

  Canvas {
    id: plate
    anchors.fill: parent
    antialiasing: true

    function traceEye(ctx) {
      ctx.beginPath()
      ctx.moveTo(17.6, 41.5)
      ctx.bezierCurveTo(23.5, 32.5, 32.2, 29.1, 40.0, 29.1)
      ctx.bezierCurveTo(47.8, 29.1, 56.5, 32.5, 62.4, 41.5)
      ctx.bezierCurveTo(56.5, 47.9, 47.8, 50.7, 40.0, 50.7)
      ctx.bezierCurveTo(32.2, 50.7, 23.5, 47.9, 17.6, 41.5)
      ctx.closePath()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (width < 2 || height < 2) return

      var s = Math.min(width, height) / 80.0
      var lit = mark.active || mark.scanning || mark.ready
      var pupilCol = mark.scanning ? mark.accentColor : (mark.ready ? mark.readyColor : mark.accentColor)
      var p = mark.scanning ? mark.pulse : 0.0

      ctx.save()
      ctx.translate((width - 80.0 * s) / 2.0, (height - 80.0 * s) / 2.0)
      ctx.scale(s, s)

      // 1. Four crisp square screenshot viewfinder corner brackets
      ctx.strokeStyle = mark.color
      ctx.lineWidth = 6.6
      ctx.lineCap = "square"
      ctx.lineJoin = "miter"
      ctx.globalAlpha = 1.0
      ctx.beginPath()
      ctx.moveTo(7.2, 25.2);  ctx.lineTo(7.2, 7.2);   ctx.lineTo(25.2, 7.2)
      ctx.moveTo(54.8, 7.2);  ctx.lineTo(72.8, 7.2);  ctx.lineTo(72.8, 25.2)
      ctx.moveTo(7.2, 54.8);  ctx.lineTo(7.2, 72.8);  ctx.lineTo(25.2, 72.8)
      ctx.moveTo(54.8, 72.8); ctx.lineTo(72.8, 72.8); ctx.lineTo(72.8, 54.8)
      ctx.stroke()

      // 2. Solid sculptural eye body
      ctx.fillStyle = mark.color
      traceEye(ctx)
      ctx.fill()

      // 3. Scanning slit or pupil cutout (clean transparency on both dark and light themes)
      ctx.save()
      ctx.globalCompositeOperation = "destination-out"
      ctx.fillStyle = "#000000"
      if (mark.scanning) {
        ctx.fillRect(23.0, 38.6, 34.0, 4.4)
      }
      ctx.beginPath()
      ctx.arc(40.0, 40.8, 6.4, 0, Math.PI * 2)
      ctx.fill()
      ctx.restore()

      // 4. Illuminated theme-accent pupil when active / scanning / ready
      if (lit) {
        ctx.fillStyle = pupilCol
        ctx.globalAlpha = mark.scanning ? (0.78 + 0.22 * p) : 1.0
        ctx.beginPath()
        ctx.arc(40.0, 40.8, 6.2 + (mark.scanning ? 0.9 * p : 0.0), 0, Math.PI * 2)
        ctx.fill()
      }

      ctx.restore()
    }
  }

  SequentialAnimation {
    running: mark.scanning && mark.visible && !Style.reduceMotion && Style.duration(100) > 0
    loops: Animation.Infinite
    onRunningChanged: if (!running) mark.pulse = 0
    NumberAnimation {
      target: mark
      property: "pulse"
      from: 0.0
      to: 1.0
      duration: Style.duration(750)
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: mark
      property: "pulse"
      from: 1.0
      to: 0.0
      duration: Style.duration(750)
      easing.type: Easing.InOutSine
    }
  }
}

// components/notch/modules/AudioWaveform.qml
// Ondulation animée réagissant à l'audio en cours (via cava), collée au bord bas de la barre.
import QtQuick 2.15
import Quickshell.Io

Item {
    id: root

    property bool active: false  // ne lance cava que si un son est en cours
    property color waveColor: "#5599CCFF"
    property int barCount: 16
    property real maxRange: 40

    property var levels: []

    height: 16

    Process {
        id: cavaProc
        running: root.active
        command: ["cava", "-p", "/home/emmanuel/dotfiles/quickshell/components/notch/modules/cava_waveform.conf"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                var parts = data.trim().split(";")
                var values = []
                for (var i = 0; i < parts.length; i++) {
                    var n = parseInt(parts[i], 10)
                    values.push(isNaN(n) ? 0 : n)
                }
                root.levels = values
                waveCanvas.requestPaint()
            }
        }
    }

    onActiveChanged: {
        if (!active) {
            root.levels = []
            waveCanvas.requestPaint()
        }
    }

    Canvas {
        id: waveCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var n = root.levels.length
            if (n === 0 || width <= 0) {
                return
            }

            // Baseline en haut (collée au bord bas de la barre) : les pointes
            // pendent VERS LE BAS, comme des stalactites qui réagissent au son.
            var pts = []
            pts.push({ x: 0, y: 0 })
            for (var i = 0; i < n; i++) {
                var x = (i + 1) * width / (n + 1)
                var v = Math.max(0, Math.min(root.levels[i], root.maxRange))
                var h = (v / root.maxRange) * height
                pts.push({ x: x, y: h })
            }
            pts.push({ x: width, y: 0 })

            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (var j = 1; j < pts.length - 1; j++) {
                var midX = (pts[j].x + pts[j + 1].x) / 2
                var midY = (pts[j].y + pts[j + 1].y) / 2
                ctx.quadraticCurveTo(pts[j].x, pts[j].y, midX, midY)
            }
            ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
            ctx.lineTo(width, 0)
            ctx.lineTo(0, 0)
            ctx.closePath()

            ctx.fillStyle = root.waveColor
            ctx.fill()
        }
    }
}

import QtQuick 2.15
import Quickshell.Io

Rectangle {
    id: bluetoothModule
    height: 60
    radius: 50
    color: bluetoothEnabled ? "#60404040" : "#502a2a2a"  // Plus transparent
    border.color: "#30FFFFFF"  // Bordure subtile blanche
    border.width: 1
    
    signal clicked()  // Signal émis quand on clique sur le module

    property bool bluetoothEnabled: false

    Process {
        id: bluetoothCheck
        running: false
        command: ["sh", "-c", "timeout 1 bluetoothctl show | grep -q 'Powered: yes' && echo POWERED_ON || echo POWERED_OFF"]

        stdout: StdioCollector {
            onStreamFinished: bluetoothModule.bluetoothEnabled = (this.text ? this.text.trim() : "") === "POWERED_ON"
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: bluetoothCheck.running = true
    }
    
    Component.onCompleted: bluetoothCheck.running = true
    
    Behavior on color { ColorAnimation { duration: 200 } }

    property bool hovered: false

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        
        onClicked: {
            bluetoothModule.clicked()  // Émettre le signal
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Icône à gauche avec canvas
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: "#35FFFFFF"
            anchors.verticalCenter: parent.verticalCenter
            
            Canvas {
                id: bluetoothCanvas
                width: 18
                height: 18
                anchors.centerIn: parent
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = bluetoothEnabled ? "white" : "#60FFFFFF"
                    ctx.fillStyle = bluetoothEnabled ? "white" : "#60FFFFFF"
                    ctx.lineWidth = 1.5
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    
                    var centerX = width / 2
                    var centerY = height / 2
                    var h = height * 0.45  // Hauteur du logo
                    var w = width * 0.28   // Largeur des triangles
                    
                    // Ligne verticale centrale
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY - h)
                    ctx.lineTo(centerX, centerY + h)
                    ctx.stroke()
                    
                    // Triangle supérieur droit (forme en B)
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY - h)
                    ctx.lineTo(centerX + w, centerY - h * 0.25)
                    ctx.lineTo(centerX, centerY)
                    ctx.closePath()
                    ctx.stroke()
                    
                    // Triangle inférieur droit
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.lineTo(centerX + w, centerY + h * 0.25)
                    ctx.lineTo(centerX, centerY + h)
                    ctx.closePath()
                    ctx.stroke()
                    
                    // Ligne diagonale supérieure gauche
                    ctx.beginPath()
                    ctx.moveTo(centerX - w * 0.85, centerY - h * 0.55)
                    ctx.lineTo(centerX + w, centerY + h * 0.25)
                    ctx.stroke()
                    
                    // Ligne diagonale inférieure gauche
                    ctx.beginPath()
                    ctx.moveTo(centerX - w * 0.85, centerY + h * 0.55)
                    ctx.lineTo(centerX + w, centerY - h * 0.25)
                    ctx.stroke()
                }
                
                Connections {
                    target: bluetoothModule
                    function onBluetoothEnabledChanged() {
                        bluetoothCanvas.requestPaint()
                    }
                }
            }
        }

        // Textes à droite
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Titre
            Text {
                text: "Bluetooth"
                color: "white"
                font.pixelSize: 13
                font.bold: true
            }

            // Sous-titre
            Text {
                text: bluetoothEnabled ? "Enabled" : "Disabled"
                color: "#999999"
                font.pixelSize: 11
            }
        }
    }

    // Indicateur d'état (petit point)
    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: bluetoothEnabled ? "#0A84FF" : "transparent"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 20
        anchors.topMargin: 10
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}

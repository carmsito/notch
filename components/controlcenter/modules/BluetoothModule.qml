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
                    ctx.fillStyle = bluetoothEnabled ? "white" : "#60FFFFFF"
                    ctx.strokeStyle = bluetoothEnabled ? "white" : "#60FFFFFF"
                    
                    var centerX = width / 2
                    var centerY = height / 2
                    var halfHeight = height * 0.35
                    var halfWidth = width * 0.25
                    
                    // Ligne verticale centrale
                    ctx.lineWidth = width * 0.12
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY - halfHeight)
                    ctx.lineTo(centerX, centerY + halfHeight)
                    ctx.stroke()
                    
                    // Triangle supérieur (forme en zigzag)
                    ctx.lineWidth = width * 0.12
                    ctx.lineJoin = "miter"
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY - halfHeight)
                    ctx.lineTo(centerX + halfWidth, centerY)
                    ctx.lineTo(centerX, centerY)
                    ctx.stroke()
                    
                    // Triangle inférieur
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY + halfHeight)
                    ctx.lineTo(centerX + halfWidth, centerY)
                    ctx.lineTo(centerX, centerY)
                    ctx.stroke()
                    
                    // Diagonale gauche haut
                    ctx.beginPath()
                    ctx.moveTo(centerX - halfWidth * 0.8, centerY - halfHeight * 0.6)
                    ctx.lineTo(centerX + halfWidth, centerY)
                    ctx.stroke()
                    
                    // Diagonale gauche bas
                    ctx.beginPath()
                    ctx.moveTo(centerX - halfWidth * 0.8, centerY + halfHeight * 0.6)
                    ctx.lineTo(centerX + halfWidth, centerY)
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
        anchors.margins: 10
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}

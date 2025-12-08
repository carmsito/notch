import QtQuick 2.15
import Quickshell.Io

Rectangle {
    id: wifiModule
    height: 60
    radius: 50
    color: wifiEnabled ? "#60404040" : "#502a2a2a"  // Plus transparent
    border.color: "#30FFFFFF"  // Bordure subtile blanche
    border.width: 1

    signal clicked()

    Process {
        id: wifiCheck
        running: false
        command: ["sh","-c","nmcli -t -f WIFI radio | grep -qi enabled && echo ON || echo OFF"]
        stdout: StdioCollector { onStreamFinished: { wifiModule.wifiEnabled = (this.text||"").trim() === "ON" } }
    }
    
    Process {
        id: activeConnectionCheck
        running: false
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active | awk -F: 'NR==1{print $1\"|\"$2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = (this.text || "").trim()
                if (out === "") {
                    wifiModule.connectionName = ""
                    wifiModule.connectionType = ""
                    return
                }
                var parts = out.split("|")
                wifiModule.connectionName = parts[0]
                wifiModule.connectionType = parts[1]
            }
        }
    }
    
    Process {
        id: wifiSignalCheck
        running: false
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL device wifi | awk '/^\\*/{gsub(/[^0-9]/,\"\",$2); print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var sig = (this.text || "").trim()
                if (sig !== "" && sig !== "0") {
                    wifiModule.signalStrength = parseInt(sig)
                } else {
                    wifiModule.signalStrength = 0
                }
            }
        }
    }
    
    property bool wifiEnabled: false
    property string connectionName: ""
    property string connectionType: ""
    property int signalStrength: 0

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiCheck.running = true
            activeConnectionCheck.running = true
            if (wifiModule.connectionType === "802-11-wireless" || wifiModule.connectionType === "wifi") {
                wifiSignalCheck.running = true
            }
        }
    }
    
    Behavior on color { ColorAnimation { duration: 200 } }

    property bool hovered: false

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        
        onClicked: { wifiModule.clicked() }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Icône à gauche avec canvas pour le signal Wi-Fi
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: "#35FFFFFF"
            anchors.verticalCenter: parent.verticalCenter
            
            Item {
                width: 18
                height: 18
                anchors.centerIn: parent
            
            Canvas {
                id: wifiCanvas
                anchors.fill: parent
                visible: connectionType === "802-11-wireless" || connectionType === "wifi"
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "white"
                    
                    var centerX = width / 2
                    var centerY = height * 0.85
                    
                    // Point central
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, width * 0.08, 0, Math.PI * 2)
                    ctx.fill()
                    
                    // Barres Wi-Fi
                    var bars = [
                        {radius: 0.25, angle: 60, strength: 25},
                        {radius: 0.4, angle: 70, strength: 50},
                        {radius: 0.55, angle: 80, strength: 75}
                    ]
                    
                    ctx.lineWidth = width * 0.1
                    ctx.lineCap = "round"
                    
                    for (var i = 0; i < bars.length; i++) {
                        var bar = bars[i]
                        if (signalStrength >= bar.strength) {
                            ctx.strokeStyle = "white"
                        } else {
                            ctx.strokeStyle = "#30FFFFFF"
                        }
                        
                        var startAngle = (270 - bar.angle / 2) * Math.PI / 180
                        var endAngle = (270 + bar.angle / 2) * Math.PI / 180
                        
                        ctx.beginPath()
                        ctx.arc(centerX, centerY, width * bar.radius, startAngle, endAngle)
                        ctx.stroke()
                    }
                }
                
                Connections {
                    target: wifiModule
                    function onSignalStrengthChanged() {
                        wifiCanvas.requestPaint()
                    }
                }
            }
            
            Canvas {
                id: ethernetCanvas
                anchors.fill: parent
                visible: connectionType.indexOf("ethernet") !== -1
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "white"
                    ctx.strokeStyle = "white"
                    
                    var centerX = width / 2
                    var centerY = height / 2
                    
                    // Moniteur
                    var monitorWidth = width * 0.55
                    var monitorHeight = height * 0.4
                    var monitorX = centerX - monitorWidth / 2
                    var monitorY = centerY - monitorHeight / 2 - height * 0.1
                    
                    ctx.lineWidth = width * 0.08
                    ctx.strokeRect(monitorX, monitorY, monitorWidth, monitorHeight)
                    
                    // Pied
                    var standWidth = width * 0.25
                    var standHeight = height * 0.15
                    ctx.fillRect(centerX - standWidth / 2, monitorY + monitorHeight, standWidth, standHeight)
                    
                    // Câble
                    ctx.lineWidth = width * 0.1
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(centerX, monitorY + monitorHeight + standHeight)
                    ctx.lineTo(centerX, height * 0.85)
                    ctx.stroke()
                    
                    // Connecteur RJ45
                    var connectorWidth = width * 0.25
                    var connectorHeight = height * 0.15
                    ctx.fillRect(centerX - connectorWidth / 2, height * 0.82, connectorWidth, connectorHeight)
                }
            }
            
            Image {
                anchors.fill: parent
                source: wifiEnabled ? "image://icon/network-wireless-connected-symbolic" : "image://icon/network-wireless-disconnected-symbolic"
                sourceSize.width: 18
                sourceSize.height: 18
                visible: connectionName === ""
            }
            }
        }

        // Textes à droite
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Titre
            Text {
                text: connectionName !== "" ? connectionName : "Wi-Fi"
                color: "white"
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                width: wifiModule.width - 80
            }

            // Sous-titre
            Text {
                text: {
                    if (connectionName !== "") {
                        if (connectionType === "802-11-wireless" || connectionType === "wifi") {
                            return "Connected"
                        } else if (connectionType.indexOf("ethernet") !== -1) {
                            return "Ethernet"
                        } else {
                            return "Connected"
                        }
                    }
                    return wifiEnabled ? "Enabled" : "Disabled"
                }
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
        color: wifiEnabled ? "#32D74B" : "transparent"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 20
        anchors.topMargin: 10
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}

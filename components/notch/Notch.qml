import QtQuick 2.15
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../controlcenter/modules"
import "../bar/modules"
import "../testcontainer"
import "modules"

Item {
    id: root

    width: hovered ? expandedWidth : collapsedWidth

    property int collapsedHeight: 40
    // property int expandedHeight: 340  // Augmenté pour contenir 5 modules (2x70 + 3x70 + 4x10 spacing)
    property int expandedHeight: 380

    property int collapsedRadius: 20
    property int expandedRadius: 15

    property int collapsedWidth: 700 
    property int expandedWidth: 475  // Largeur pour contenir les modules

    property int hoverTriggerWidth: 150 

    property bool hovered: false
    property bool isInteractingWithModules: false
    property bool showingBluetoothDevices: false  // Affichage de la liste Bluetooth
    property bool showingWifiNetworks: false      // Affichage de la liste Wi‑Fi
    property bool needsKeyboardFocus: false       // Pour demander le focus clavier
    // Empêche le hover initial de s'activer au démarrage (barre démarre compacte)
    property bool startupLock: true

    // Navigation entre conteneurs
    property var containers: ["Control Center", "Test Container"]
    property int currentContainerIndex: 0
    property string currentContainerTitle: containers[currentContainerIndex]

    implicitHeight: hoverStrip.height + notchRect.height

    // --- LOGIQUE ---
    Battery { id: batteryData }
    
    property string wifiPath: "/sys/class/net/wlan0/operstate"
    property var wifiFile: File.exists(wifiPath) ? File.read(wifiPath) : "down"
    property bool isWifiConnected: wifiFile && wifiFile.trim() === "up"

    Time { id: timeSource }

    // Timer pour éviter le clignotement du hover
    Timer {
        id: hoverTimer
        interval: 150  // Petit délai pour éviter fermeture trop brusque
        repeat: false
        onTriggered: {
            root.hovered = false
            // Reset le showingBluetoothDevices quand on quitte complètement
            root.showingBluetoothDevices = false
            // Reset le showingWifiNetworks quand on quitte complètement
            root.showingWifiNetworks = false
        }
    }

    // Petit verrou au démarrage pour forcer la barre en mode compact
    Timer {
        id: startupTimer
        interval: 350
        repeat: false
        running: true
        onTriggered: {
            // Déverrouille le hover après un court délai et assure que la barre est compacte
            root.startupLock = false
            root.hovered = false
        }
    }

    Component.onCompleted: {
        // S'assurer qu'on démarre en compact
        root.startupLock = true
        // Démarre le timer (déjà running: true) pour l'enlever
    }

    // --- VISUEL ---

    // 1. Zone de détection hover AU-DESSUS
    Item {
        id: hoverStrip
        width: hoverTriggerWidth 
        height: 8  // Augmenter légèrement pour meilleure détection
        anchors.horizontalCenter: notchRect.horizontalCenter
        anchors.bottom: notchRect.top
        anchors.bottomMargin: -4  // Chevaucher légèrement avec le rectangle

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                if (!root.startupLock) {
                    root.hovered = true
                    hoverTimer.stop()
                }
            }
            onExited: {
                // Ne redémarre le timer que si on n'est pas dans le rectangle principal
                if (!globalHoverArea.containsMouse) {
                    hoverTimer.restart()
                }
            }
        }
    }

    // 2. Le rectangle principal
    Rectangle {
        id: notchRect
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        width: root.width
        height: hovered ? expandedHeight : collapsedHeight
        radius: hovered ? expandedRadius : collapsedRadius

        color: hovered ? '#a2000000' : '#d1000000'
        border.color: hovered ? "#30FFFFFF" : "#33FFFFFF"
        border.width: 1

        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutExpo } }
        Behavior on radius { NumberAnimation { duration: 100; easing.type: Easing.OutExpo } }
        Behavior on color { ColorAnimation { duration: 100 } }

        // --- CONTENU ---

        // ==================================================
        // 1. GAUCHE (WORKSPACES + BATTERIE)
        // ==================================================
        Row {
            id: leftGroup
            
            // LOGIQUE D'EXPANSION :
            // Si on interagit avec les workspaces (wsWidget.isInteracting) :
            // -> On casse l'ancrage à gauche et on se centre
            // -> On prend toute la largeur
            anchors.left: wsWidget.isInteracting ? undefined : parent.left
            anchors.leftMargin: wsWidget.isInteracting ? 0 : 12
            
            anchors.horizontalCenter: wsWidget.isInteracting ? parent.horizontalCenter : undefined
            anchors.verticalCenter: parent.verticalCenter
            
            width: wsWidget.isInteracting ? parent.width : undefined

            spacing: 10
            
            // Gestion visibilité globale (disparait si la notch s'ouvre en mode expanded)
            opacity: root.hovered ? 0 : 1
            visible: opacity > 0 
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // --- WORKSPACES ---
            Workspaces {
                id: wsWidget
                anchors.verticalCenter: parent.verticalCenter
                // On passe la largeur totale disponible à Workspaces pour qu'il sache s'étendre
                fullWidth: notchRect.width
            }

            // --- BATTERIE (DOIT DISPARAITRE QUAND WORKSPACES S'ÉTEND) ---
            Row {
                spacing: 6
                // Si on joue avec les workspaces, la batterie se cache pour laisser la place
                visible: !wsWidget.isInteracting 
                opacity: visible ? 1 : 0
                
                AppleBattery {
                    width: 26
                    height: 12
                    level: batteryData.batteryLevel
                    charging: batteryData.isCharging
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                }
                Text {
                    text: batteryData.batteryLevel + "%"
                    color: batteryData.isCharging ? "#32D74B" : "white"
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                }
            }
        }

        // 2. HORLOGE (CENTRE)
        ClockWidget {
            id: centerClock
            anchors.centerIn: parent
            time: timeSource.time
            color: "white"
            
            // Disparait si on joue avec les Workspaces ou si hover
            visible: !wsWidget.isInteracting && !root.hovered
        }

        // 3. CONNEXION ICONS (DROITE) - Wi-Fi/Ethernet/Bluetooth
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            opacity: root.hovered ? 0 : 1
            // Disparait si on joue avec les Workspaces
            visible: opacity > 0 && !wsWidget.isInteracting
            
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Icône de connexion (Wi-Fi, Ethernet ou Bluetooth selon l'état)
            Item {
                width: 22
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                
                property string connectionType: wifiMod.connectionType
                property int wifiSignal: wifiMod.signalStrength
                property bool bluetoothEnabled: bluetoothMod.bluetoothEnabled
                
                // Canvas Wi-Fi
                Canvas {
                    id: compactWifiCanvas
                    anchors.fill: parent
                    visible: parent.connectionType === "802-11-wireless" || parent.connectionType === "wifi"
                    
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
                            if (parent.wifiSignal >= bar.strength) {
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
                        target: wifiMod
                        function onSignalStrengthChanged() {
                            compactWifiCanvas.requestPaint()
                        }
                    }
                    
                    Component.onCompleted: {
                        requestPaint()
                    }
                }
                
                // Canvas Ethernet
                Canvas {
                    anchors.fill: parent
                    visible: parent.connectionType.indexOf("ethernet") !== -1
                    
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
                
                // Canvas Bluetooth
                Canvas {
                    anchors.fill: parent
                    visible: parent.connectionType === "" && parent.bluetoothEnabled
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = "white"
                        ctx.strokeStyle = "white"
                        
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
                }
                
                // Icône par défaut si rien n'est actif
                Image {
                    anchors.fill: parent
                    source: "image://icon/network-wireless-disconnected-symbolic"
                    sourceSize.width: 16
                    sourceSize.height: 16
                    visible: parent.connectionType === "" && !parent.bluetoothEnabled
                }
            }
        }

        // ==================================================
        // 4. HEADER DE NAVIGATION (EXPANDED MODE)
        // ==================================================
        Rectangle {
            id: navigationHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: "transparent"
            
            opacity: root.hovered && !root.showingBluetoothDevices && !root.showingWifiNetworks ? 1 : 0
            visible: opacity > 0
            
            Behavior on opacity { 
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10

                // Bouton précédent (gauche)
                Rectangle {
                    id: leftNavButton
                    width: 35
                    height: 35
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 8
                    color: leftNavMouseArea.containsMouse ? "#40FFFFFF" : "#20FFFFFF"
                    border.color: "#30FFFFFF"
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    // Icône flèche gauche
                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        font.pixelSize: 24
                        font.bold: true
                        color: root.currentContainerIndex > 0 ? "#ffffff" : "#555555"
                    }

                    MouseArea {
                        id: leftNavMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.currentContainerIndex > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        
                        onClicked: {
                            if (root.currentContainerIndex > 0) {
                                root.currentContainerIndex--
                                root.currentContainerTitle = root.containers[root.currentContainerIndex]
                            }
                        }
                    }
                }

                // Titre du conteneur
                Item {
                    width: parent.width - 80
                    height: 35
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: titleText.width + 24
                        height: 28
                        radius: 14
                        color: "#502a2a2a"
                        border.color: "#30FFFFFF"
                        border.width: 1
                        
                        Text {
                            id: titleText
                            anchors.centerIn: parent
                            text: root.currentContainerTitle
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "SF Pro Display"
                            color: "#ffffff"
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }
                }

                // Bouton suivant (droite)
                Rectangle {
                    id: rightNavButton
                    width: 35
                    height: 35
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 8
                    color: rightNavMouseArea.containsMouse ? "#40FFFFFF" : "#20FFFFFF"
                    border.color: "#30FFFFFF"
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    // Icône flèche droite
                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 24
                        font.bold: true
                        color: root.currentContainerIndex < root.containers.length - 1 ? "#ffffff" : "#555555"
                    }

                    MouseArea {
                        id: rightNavMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.currentContainerIndex < root.containers.length - 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        
                        onClicked: {
                            if (root.currentContainerIndex < root.containers.length - 1) {
                                root.currentContainerIndex++
                                root.currentContainerTitle = root.containers[root.currentContainerIndex]
                            }
                        }
                    }
                }
            }
        }

        // ==================================================
        // 5. MODULES WIFI/BLUETOOTH/BRIGHTNESS/VOLUME (EXPANDED MODE)
        // ==================================================
        Column {
            id: controlCenterModules
            anchors.top: parent.top
            anchors.topMargin: 55  // Augmenté pour laisser place au header de navigation
            anchors.horizontalCenter: parent.horizontalCenter
            width: 460  // Largeur fixe pour centrer correctement tous les modules
            spacing: 10
            
            opacity: root.hovered && !root.showingBluetoothDevices && !root.showingWifiNetworks ? 1 : 0
            
            Behavior on opacity { 
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
            }

            // Afficher uniquement si on est sur Control Center
            visible: root.currentContainerIndex === 0 && opacity > 0

            // Rangée WiFi + Bluetooth
            Row {
                spacing: 10

                WifiModule {
                    id: wifiMod
                    width: 225
                    height: 70
                    onClicked: {
                        root.showingWifiNetworks = true
                    }
                }

                BluetoothModule {
                    id: bluetoothMod
                    width: 225
                    height: 70
                    
                    onClicked: {
                        root.showingBluetoothDevices = true
                    }
                }
            }

            // Module Luminosité Laptop (toute la largeur)
            BrightnessModule {
                id: brightnessLaptop
                width: 450
                anchors.horizontalCenter: parent.horizontalCenter
                displayName: "Display"
                deviceName: ""  // Device par défaut (laptop)
                onInteractionStarted: {
                    hoverTimer.stop()
                }
                
                onInteractionEnded: {
                    // Ne rien faire, laisser le hover naturel gérer
                }
            }
            
            // Module Luminosité ScreenPad
            BrightnessModule {
                id: brightnessScreenpad
                width: 450
                anchors.horizontalCenter: parent.horizontalCenter
                displayName: "ScreenPad"
                deviceName: "asus_screenpad"
                
                onInteractionStarted: {
                    hoverTimer.stop()
                }
                
                onInteractionEnded: {
                    // Ne rien faire, laisser le hover naturel gérer
                }
            }
            
            // Module Volume
            VolumeModule {
                id: volumeMod
                width: 450
                anchors.horizontalCenter: parent.horizontalCenter
                
                onInteractionStarted: {
                    hoverTimer.stop()
                }
                
                onInteractionEnded: {
                    // Ne rien faire, laisser le hover naturel gérer
                }
            }
        }
        
        // ==================================================
        // TEST CONTAINER (EXPANDED MODE - Index 1)
        // ==================================================
        TestContainer {
            id: testContainer
            anchors.top: parent.top
            anchors.topMargin: 55
            anchors.horizontalCenter: parent.horizontalCenter
            
            opacity: root.hovered && !root.showingBluetoothDevices && !root.showingWifiNetworks ? 1 : 0
            
            Behavior on opacity { 
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
            }

            // Afficher uniquement si on est sur Test Container
            visible: root.currentContainerIndex === 1 && opacity > 0
        }
        
        // MouseArea invisible par-dessus TOUT pour maintenir le hover
        // Laisse passer les clics mais capture le hover
        MouseArea {
            id: globalHoverArea
            anchors.fill: parent
            anchors.topMargin: -8
            anchors.bottomMargin: -40
            anchors.leftMargin: -5
            anchors.rightMargin: -5
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            enabled: root.hovered && !wsWidget.isInteracting
            z: 1000  // Au-dessus de tout
            
            onEntered: {
                if (!root.startupLock) {
                    root.hovered = true
                    hoverTimer.stop()
                }
            }
            
            onExited: {
                hoverTimer.restart()
            }
        }
        
        // ==================================================
        // 6. BLUETOOTH DEVICES LIST (WHEN BLUETOOTH CLICKED)
        // ==================================================
        BluetoothDevicesList {
            id: bluetoothList
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            
            opacity: root.hovered && root.showingBluetoothDevices ? 1 : 0
            visible: root.currentContainerIndex === 0 && opacity > 0
            
            Behavior on opacity { 
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
            }
            
            onClose: {
                root.showingBluetoothDevices = false
            }
        }

        // ==================================================
        // 7. WIFI NETWORKS LIST (WHEN WIFI CLICKED)
        // ==================================================
        WifiNetworksList {
            id: wifiList
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            opacity: root.hovered && root.showingWifiNetworks ? 1 : 0
            visible: root.currentContainerIndex === 0 && opacity > 0

            Behavior on opacity { 
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
            }

            onClose: {
                root.showingWifiNetworks = false
            }
            
            // Propager l'état du focus clavier
            onIsEnteringPasswordChanged: {
                root.needsKeyboardFocus = isEnteringPassword
            }
        }
    }
}
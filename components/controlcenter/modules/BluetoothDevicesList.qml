import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    id: root
    width: 320
    
    property bool bluetoothEnabled: false
    property var devices: []  // Liste des appareils Bluetooth
    property var scannedDevices: []  // Liste des appareils découverts par scan
    property bool initialCheckDone: false
    property int activeDeviceIndex: -1  // Index du device avec panneau actif
    property bool pollingEnabled: true
    
    signal close()
    
    // MouseArea global pour fermer les panneaux d'actions
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            // Fermer tous les panneaux d'actions
            for (var i = 0; i < devicesColumn.children.length; i++) {
                var child = devicesColumn.children[i]
                if (child.showingActions !== undefined) {
                    child.showingActions = false
                }
            }
            root.activeDeviceIndex = -1
        }
    }
    
    Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 15
        anchors.leftMargin: 20
        anchors.rightMargin: 0
        spacing: 8
        z: 1
        
        // En-tête avec bouton retour, titre et toggle
        Row {
            width: 320
            height: 32
            spacing: 8
            
            // Bouton retour (flèche gauche)
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: backButtonMouse.containsMouse ? "#30FFFFFF" : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    text: "‹"
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                }
                
                MouseArea {
                    id: backButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // Reset l'état
                        root.activeDeviceIndex = -1
                        root.scannedDevices = []
                        scanProc.running = false
                        
                        // Reset scroll position
                        devicesFlickable.contentY = 0
                        
                        // Fermer tous les panneaux
                        for (var i = 0; i < devicesColumn.children.length; i++) {
                            var child = devicesColumn.children[i]
                            if (child.showingActions !== undefined) {
                                child.showingActions = false
                            }
                        }
                        
                        root.close()
                    }
                }
            }
            
            Text {
                text: "Bluetooth"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Item { 
                width: 245
                height: 1
            }
            
            // Toggle Bluetooth
            Rectangle {
                width: 48
                height: 28
                radius: 14
                color: root.bluetoothEnabled ? "#007AFF" : "#4CFFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: "white"
                    x: root.bluetoothEnabled ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Toggle clicked, current state:", root.bluetoothEnabled)
                        toggleBluetooth.targetEnabled = !root.bluetoothEnabled
                        toggleBluetooth.running = true
                    }
                }
            }
        }
        
        // Spacer
        Item { width: 1; height: 3 }
        
        // Séparateur
        Rectangle {
            width: 430
            height: 1
            color: "#18FFFFFF"
        }
    }
    
    // Zone scrollable pour les devices
    Flickable {
        id: devicesFlickable
        anchors.top: headerColumn.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 8
        anchors.bottomMargin: 12
        
        contentHeight: devicesColumn.height
        clip: true
        
        Column {
            id: devicesColumn
            width: 430
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter
        
        // Spacer
        Item { width: 1; height: 3 }
        
        // Liste des appareils
        Repeater {
            model: root.devices
            
            Column {
                width: 430
                spacing: 4
                
                property bool showingActions: false
                property int deviceIndex: index
                
                Rectangle {
                    id: deviceItem
                    width: 430
                    height: 48
                    radius: 8
                    color: root.activeDeviceIndex === deviceIndex ? "#25FFFFFF" : 
                           (deviceMouse.containsMouse ? "#15FFFFFF" : "transparent")
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        z: 0
                        
                        // Icône de l'appareil
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: "#35FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: modelData.icon || "🎧"
                                font.pixelSize: 16
                                anchors.centerIn: parent
                            }
                        }
                        
                        // Nom et infos de l'appareil
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 80
                            
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: modelData.name || "Unknown Device"
                                    color: "white"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: parent.width - (deviceInfo.connected ? 60 : 0)
                                }
                                Item { width: 1; height: 1 }
                                Text {
                                    text: deviceInfo.connected ? "connected" : ""
                                    color: "#00FF99"
                                    font.pixelSize: 12
                                    visible: deviceInfo.connected
                                    horizontalAlignment: Text.AlignRight
                                    width: 60
                                }
                            }
                            
                            // Batterie si disponible
                            Row {
                                spacing: 4
                                visible: modelData.battery !== undefined
                                
                                Text {
                                    text: "🔋 " + (modelData.batteryLeft || "100") + "%"
                                    color: "#99FFFFFF"
                                    font.pixelSize: 9
                                }
                                
                                Text {
                                    text: "🔋 " + (modelData.batteryRight || "100") + "%"
                                    color: "#99FFFFFF"
                                    font.pixelSize: 9
                                    visible: modelData.batteryRight !== undefined
                                }
                            }
                        }
                    }
                    
                    MouseArea {
                        id: deviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        z: 1
                        onClicked: {
                            var wasShowing = parent.parent.showingActions
                            var currentIndex = deviceIndex
                            
                            // Fermer tous les panneaux
                            for (var i = 0; i < root.devices.length; i++) {
                                var child = devicesColumn.children[i + 1] // +1 car le premier est le spacer
                                if (child && child.showingActions !== undefined) {
                                    child.showingActions = false
                                }
                            }
                            root.activeDeviceIndex = -1
                            
                            // Si ce n'était pas déjà ouvert, l'ouvrir
                            if (!wasShowing) {
                                parent.parent.showingActions = true
                                root.activeDeviceIndex = currentIndex
                            }
                        }
                    }
                }

                // Panneau d'actions (connect / disconnect / forget) - EN DESSOUS
                Rectangle {
                    id: actionPanel
                    width: 430
                    height: showingActions ? 110 : 0
                    visible: height > 0
                    color: "#B0000000"
                    radius: 8
                    clip: true
                    
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    border.color: "#30FFFFFF"
                    border.width: 1
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width - 40
                        
                        // Etat connecté
                        Text {
                            text: deviceInfo.connected ? "Connected" : (deviceInfo.paired ? "Paired" : "Not Paired")
                            color: "white"
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                        }
                        
                        Row {
                            spacing: 8
                            width: parent.width
                            
                            // Bouton Connect / Disconnect
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 28
                                radius: 6
                                color: actionMouse.containsMouse ? "#40FFFFFF" : "#20FFFFFF"
                                Text { 
                                    anchors.centerIn: parent
                                    text: deviceInfo.connected ? "Disconnect" : "Connect"
                                    color: "white"; font.pixelSize: 11; font.bold: true
                                }
                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (deviceInfo.connected) {
                                            disconnectProc.running = true
                                        } else {
                                            connectProc.running = true
                                        }
                                        parent.parent.parent.parent.parent.showingActions = false
                                        root.activeDeviceIndex = -1
                                    }
                                }
                            }
                            
                            // Bouton Forget
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 28
                                radius: 6
                                color: forgetMouse.containsMouse ? "#FF3B30" : "#80222222"
                                Text { anchors.centerIn: parent; text: "Forget"; color: "white"; font.pixelSize: 11; font.bold: true }
                                MouseArea {
                                    id: forgetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        forgetProc.running = true
                                        parent.parent.parent.parent.parent.showingActions = false
                                        root.activeDeviceIndex = -1
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Process & state inside delegate for device info
                Item {
                    id: deviceInfo
                    property bool connected: false
                    property bool paired: false
                    
                    Process {
                        id: infoProc
                        running: false
                        command: ["sh", "-c", "timeout 6 sh -c \"printf 'info " + modelData.address + "\\nquit\\n' | bluetoothctl\""]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                var txt = this.text || ""
                                if (txt.indexOf("Device ") === -1) {
                                    return
                                }
                                deviceInfo.connected = /Connected:\s+yes/.test(txt)
                                deviceInfo.paired = /Paired:\s+yes/.test(txt)
                            }
                        }
                    }
                    Timer {
                        interval: 12000; running: root.pollingEnabled && root.visible; repeat: true; triggeredOnStart: true
                        onTriggered: infoProc.running = true
                    }
                }
                
                // Operations
                Process {
                    id: connectProc
                    running: false
                    command: ["sh", "-c", "timeout 8 sh -c \"printf 'connect " + modelData.address + "\\nquit\\n' | bluetoothctl\""]
                    stdout: StdioCollector { onStreamFinished: { infoProc.running = true; listDevices.running = true } }
                }
                Process {
                    id: disconnectProc
                    running: false
                    command: ["sh", "-c", "timeout 8 sh -c \"printf 'disconnect " + modelData.address + "\\nquit\\n' | bluetoothctl\""]
                    stdout: StdioCollector { onStreamFinished: { infoProc.running = true; listDevices.running = true } }
                }
                Process {
                    id: forgetProc
                    running: false
                    command: ["sh", "-c", "timeout 8 sh -c \"printf 'remove " + modelData.address + "\\nquit\\n' | bluetoothctl\""]
                    stdout: StdioCollector { onStreamFinished: { infoProc.running = true; listDevices.running = true } }
                }
            }
        }
        
        // Séparateur avant scan
        Item { width: 1; height: 3 }
        Rectangle {
            width: 430
            height: 1
            color: "#18FFFFFF"
        }
        Item { width: 1; height: 3 }
        
        // Bouton Scan
        Rectangle {
            width: 430
            height: 32
            radius: 8
            color: scanMouse.containsMouse ? "#25FFFFFF" : "transparent"
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Row {
                anchors.centerIn: parent
                spacing: 8
                
                Text {
                    text: scanProc.running ? "⟳" : "🔍"
                    color: "white"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    
                    RotationAnimator on rotation {
                        running: scanProc.running
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
                
                Text {
                    text: scanProc.running ? "Scanning..." : "Scan for Devices"
                    color: "#88FFFFFF"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !scanProc.running
                onClicked: {
                    root.scannedDevices = []
                    scanProc.running = true
                }
            }
        }
        
        // Liste des devices scannés
        Repeater {
            model: root.scannedDevices
            
            Rectangle {
                width: 430
                height: 42
                radius: 8
                color: scannedMouse.containsMouse ? "#20FFFFFF" : "transparent"
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    
                    Text {
                        text: "📱"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        width: parent.width - 100
                        
                        Text {
                            text: modelData.name || "Unknown Device"
                            color: "white"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        
                        Text {
                            text: modelData.address || ""
                            color: "#66FFFFFF"
                            font.pixelSize: 9
                        }
                    }
                    
                    Text {
                        text: "Pair"
                        color: "#007AFF"
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: scannedMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        var addr = modelData.address
                        console.log("Pairing device:", addr)
                        // Lancer l'appairage
                        pairProc.command = ["bluetoothctl", "pair", addr]
                        // Préparer la commande trust + connect pour après
                        trustAndConnectProc.command = ["sh", "-c", "bluetoothctl trust " + addr + " && bluetoothctl connect " + addr]
                        pairProc.running = true
                    }
                }
            }
        }
        
        // Bouton "Bluetooth Settings..."
        Rectangle {
            width: 430
            height: 32
            radius: 8
            color: settingsMouse.containsMouse ? "#25FFFFFF" : "transparent"
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                text: "Bluetooth Settings..."
                color: "#88FFFFFF"
                font.pixelSize: 11
                anchors.centerIn: parent
            }
            
            MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    openSettings.running = true
                }
            }
        }
        }
    }
    
    // Process pour lister les appareils Bluetooth
    Process {
        id: listDevices
        running: false
        command: ["sh", "-c", "timeout 6 sh -c \"printf 'devices\\nquit\\n' | bluetoothctl\""]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text ? this.text.trim() : ""
                if (out === "") {
                    if (!scanProc.running) {
                        root.devices = []
                    }
                    return
                }
                var lines = out.split("\n")
                var devicesList = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    var match = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.+)$/)
                    if (match) {
                        var address = match[1].toUpperCase()
                        var name = match[2]
                        var exists = false
                        for (var d = 0; d < devicesList.length; d++) {
                            if (devicesList[d].address === address) {
                                exists = true
                                break
                            }
                        }
                        if (!exists) {
                            devicesList.push({ address: address, name: name, icon: getDeviceIcon(name) })
                        }
                    }
                }
                root.devices = devicesList
            }
        }
    }
    
    // Process pour vérifier l'état Bluetooth
    Process {
        id: checkBluetooth
        running: false
        command: ["sh", "-c", "if timeout 2 nmcli radio bluetooth 2>/dev/null | grep -qi 'enabled'; then echo POWERED_ON; elif timeout 6 sh -c \"printf 'show\\nquit\\n' | bluetoothctl\" 2>/dev/null | grep -q 'Powered: yes'; then echo POWERED_ON; else echo POWERED_OFF; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text ? this.text.trim() : ""
                var wasPowered = root.bluetoothEnabled
                root.bluetoothEnabled = (out === "POWERED_ON")
                root.initialCheckDone = true
                if (root.bluetoothEnabled && (!wasPowered || root.devices.length === 0)) {
                    listDevices.running = true
                }
            }
        }
    }
    
    // Process pour toggle Bluetooth
    Process {
        id: toggleBluetooth
        running: false
        command: ["sh", "-c", targetEnabled ? "rfkill unblock bluetooth >/dev/null 2>&1 || true; timeout 2 nmcli radio bluetooth on >/dev/null 2>&1 || timeout 2 bluetoothctl power on >/dev/null 2>&1" : "timeout 2 nmcli radio bluetooth off >/dev/null 2>&1 || timeout 2 bluetoothctl power off >/dev/null 2>&1"]
        
        property bool wasEnabling: false
        property bool targetEnabled: false
        
        onRunningChanged: {
            if (running) {
                // Mémoriser si on est en train d'activer
                wasEnabling = targetEnabled
                console.log("Toggle BT starting, enabling:", wasEnabling, "target:", targetEnabled ? "on" : "off")
            }
        }
        
        onExited: function(exitCode, exitStatus) {
            console.log("Toggle BT finished, exitCode:", exitCode, "was enabling:", wasEnabling)
            // Attendre 500ms que le changement prenne effet
            checkBluetoothTimer.restart()
        }
    }
    
    // Timer pour vérifier l'état après toggle
    Timer {
        id: checkBluetoothTimer
        interval: 500
        repeat: false
        onTriggered: {
            checkBluetooth.running = true
            // Si on activait BT, scanner après la vérification
            if (toggleBluetooth.wasEnabling) {
                scanDevicesTimer.restart()
            }
        }
    }
    
    // Timer pour scanner après activation
    Timer {
        id: scanDevicesTimer
        interval: 1000
        repeat: false
        onTriggered: {
            listDevices.running = true
        }
    }
    
    // Process pour connecter un appareil
    Process {
        id: connectDevice
        running: false
    }
    
    // Process pour scanner les appareils
    Process {
        id: scanProc
        running: false
        command: ["sh", "-c", "printf 'scan on\\nquit\\n' | bluetoothctl >/dev/null 2>&1; sleep 10; timeout 6 sh -c \"printf 'scan off\\ndevices\\nquit\\n' | bluetoothctl\""]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text ? this.text.trim() : ""
                if (!out) {
                    return
                }

                var lines = out.split("\n")
                var scanned = []

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    var match = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.+)$/)
                    if (match) {
                        var address = match[1].toUpperCase()
                        var name = match[2]
                        var exists = false

                        for (var j = 0; j < scanned.length; j++) {
                            if (scanned[j].address === address) {
                                exists = true
                                break
                            }
                        }

                        if (!exists) {
                            scanned.push({ address: address, name: name })
                        }
                    }
                }

                root.scannedDevices = scanned
            }
        }
        
        onRunningChanged: {
            if (running) {
                console.log("Starting bluetoothctl timed scan...")
                // Reset scan list au lancement d'un nouveau scan.
                root.scannedDevices = []
                scanTimer.start()
                scanListPoll.running = true
                listDevices.running = true
            } else {
                console.log("Stopping bluetoothctl timed scan...")
                scanTimer.stop()
                scanListPoll.running = false
                listDevices.running = true
                // Les devices restent affichés même après l'arrêt du scan
            }
        }
    }
    
    // Timer pour arrêter le scan après 10 secondes
    Timer {
        id: scanTimer
        interval: 10000
        repeat: false
        onTriggered: {
            scanProc.running = false
        }
    }

    Timer {
        id: scanListPoll
        interval: 1800
        repeat: true
        running: false
        onTriggered: {
            listDevices.running = true
        }
    }
    
    
    // Process pour apparier un appareil
    Process {
        id: pairProc
        running: false
        
        onExited: {
            if (exitCode === 0) {
                console.log("Pairing successful, now trusting and connecting...")
                // Après l'appairage, trust et connect l'appareil
                trustAndConnectProc.running = true
            } else {
                console.log("Pairing failed with exit code:", exitCode)
                // Rafraîchir quand même la liste
                listDevices.running = true
            }
        }
    }
    
    // Process pour trust et connecter après appairage
    Process {
        id: trustAndConnectProc
        running: false
        command: ["sh", "-c", ""]  // Sera défini dynamiquement
        
        onExited: {
            console.log("Trust and connect finished")
            // Rafraîchir la liste des appareils après la connexion
            listDevices.running = true
            // Arrêter le scan et vider la liste des scannés
            scanProc.running = false
            root.scannedDevices = []
        }
    }
    
    // Process pour ouvrir les paramètres Bluetooth
    Process {
        id: openSettings
        running: false
        command: ["blueman-manager"]
    }
    
    // Timer pour rafraîchir la liste
    Timer {
        interval: 4000
        repeat: true
        running: root.pollingEnabled && root.visible
        onTriggered: {
            checkBluetooth.running = true
            // Ne scanner que si Bluetooth est activé
            if (root.bluetoothEnabled) {
                listDevices.running = true
            }
        }
    }
    
    // Initialisation
    Component.onCompleted: {
        if (pollingEnabled) {
            checkBluetooth.running = true
            // Scanner au démarrage si BT activé sera fait par le timer
        }
    }

    onPollingEnabledChanged: {
        if (!pollingEnabled) {
            scanProc.running = false
            scanListPoll.running = false
            return
        }
        if (!checkBluetooth.running) checkBluetooth.running = true
        if (root.bluetoothEnabled && !listDevices.running) listDevices.running = true
    }
    
    // Fonction pour obtenir l'icône selon le type d'appareil
    function getDeviceIcon(name) {
        var lowerName = name.toLowerCase()
        if (lowerName.includes("airpods") || lowerName.includes("headphone") || lowerName.includes("headset")) {
            return "🎧"
        } else if (lowerName.includes("controller") || lowerName.includes("gamepad")) {
            return "🎮"
        } else if (lowerName.includes("keyboard")) {
            return "⌨️"
        } else if (lowerName.includes("mouse")) {
            return "🖱️"
        } else if (lowerName.includes("speaker")) {
            return "🔊"
        } else {
            return "📱"
        }
    }
}

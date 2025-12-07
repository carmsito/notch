import QtQuick 2.15
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    width: 430
    height: 380

    property bool wifiEnabled: false
    property string activeName: ""
    property string activeType: ""
    property var savedNetworks: []
    property var scanNetworks: []
    property int activeNetworkIndex: -1
    property string debugFocus: ""
    property bool isEnteringPassword: false
    property string connectionError: ""
    
    Timer {
        id: errorTimer
        interval: 5000
        repeat: false
        onTriggered: root.connectionError = ""
    }

    signal close()
    
    // Popup pour le mot de passe
    WifiPasswordPopup {
        id: passwordPopup
        
        onConnectRequested: function(password) {
            console.log("Connecting to:", passwordPopup.ssid, "with password length:", password.length);
            var escapedSsid = passwordPopup.ssid.replace(/'/g, "'\\''");
            var escapedPass = password.replace(/'/g, "'\\''");
            var cmd = "nmcli device wifi connect '" + escapedSsid + "' password '" + escapedPass + "'";
            console.log("Command:", cmd);
            connectSecured.command = ["sh", "-c", cmd];
            connectSecured.running = true;
            
            // Fermer les actions
            for (var i = 0; i < root.scanNetworks.length; i++) {
                var child = contentCol.children[i + root.savedNetworks.length + 6]
                if (child && child.showingActions !== undefined) {
                    child.showingActions = false
                    child.enteringPassword = false
                }
            }
            root.activeNetworkIndex = -1
            root.isEnteringPassword = false
        }
        
        onCancelled: {
            passwordPopup.visible = false
            root.isEnteringPassword = false
        }
    }

    // Composant pour icône Ethernet
    Component {
        id: ethernetIcon
        Item {
            width: 40
            height: 40

            property int signal: 0  // 0-100
            property string connectionType: "ethernet"

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "white"
                    ctx.strokeStyle = "white"

                    var centerX = width / 2
                    var centerY = height / 2

                    // Dessin style Windows - ordinateur avec câble
                    // Rectangle pour l'ordinateur/moniteur
                    var monitorWidth = width * 0.55
                    var monitorHeight = height * 0.4
                    var monitorX = centerX - monitorWidth / 2
                    var monitorY = centerY - monitorHeight / 2 - height * 0.1
                    
                    ctx.lineWidth = width * 0.08
                    ctx.strokeRect(monitorX, monitorY, monitorWidth, monitorHeight)
                    
                    // Support/pied du moniteur
                    var standWidth = width * 0.25
                    var standHeight = height * 0.15
                    ctx.fillRect(centerX - standWidth / 2, monitorY + monitorHeight, standWidth, standHeight)
                    
                    // Câble Ethernet en bas
                    ctx.lineWidth = width * 0.1
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(centerX, monitorY + monitorHeight + standHeight)
                    ctx.lineTo(centerX, height * 0.85)
                    ctx.stroke()
                    
                    // Connecteur RJ45 (petit rectangle en bas)
                    var connectorWidth = width * 0.25
                    var connectorHeight = height * 0.15
                    ctx.fillRect(centerX - connectorWidth / 2, height * 0.82, connectorWidth, connectorHeight)
                }
            }
        }
    }

    // Composant pour icône Hotspot/Partage de connexion
    Component {
        id: hotspotIcon
        Item {
            width: 40
            height: 40

            property int signal: 0
            property string connectionType: "hotspot"

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "white"
                    ctx.strokeStyle = "white"

                    var centerX = width / 2
                    var centerY = height / 2

                    // Personne/utilisateur en bas (tête + corps)
                    var headRadius = width * 0.12
                    ctx.beginPath()
                    ctx.arc(centerX, centerY + height * 0.15, headRadius, 0, Math.PI * 2)
                    ctx.fill()
                    
                    // Corps (trapèze simplifié)
                    ctx.beginPath()
                    ctx.moveTo(centerX - width * 0.15, centerY + height * 0.27)
                    ctx.lineTo(centerX + width * 0.15, centerY + height * 0.27)
                    ctx.lineTo(centerX + width * 0.2, height * 0.85)
                    ctx.lineTo(centerX - width * 0.2, height * 0.85)
                    ctx.closePath()
                    ctx.fill()

                    // Ondes Wi-Fi au-dessus (3 arcs)
                    ctx.lineWidth = width * 0.08
                    ctx.lineCap = "round"
                    
                    var arcs = [
                        {radius: 0.2, angle: 100},
                        {radius: 0.32, angle: 110},
                        {radius: 0.44, angle: 120}
                    ]
                    
                    for (var i = 0; i < arcs.length; i++) {
                        var arc = arcs[i]
                        var startAngle = (270 - arc.angle / 2) * Math.PI / 180
                        var endAngle = (270 + arc.angle / 2) * Math.PI / 180
                        
                        ctx.beginPath()
                        ctx.arc(centerX, centerY + height * 0.15, width * arc.radius, startAngle, endAngle)
                        ctx.stroke()
                    }
                }
            }
        }
    }

    // Alias pour wifiIcon
    Component {
        id: wifiIcon
        Item {
            width: 40
            height: 40

            property int signal: 0  // 0-100
            property string connectionType: "wifi"

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "white"

                    var centerX = width / 2
                    var centerY = height * 0.85

                    if (connectionType === "hotspot") {
                        ctx.fillRect(centerX - width * 0.05, height * 0.5, width * 0.1, height * 0.35)
                        ctx.beginPath()
                        ctx.arc(centerX, height * 0.5, width * 0.15, Math.PI, 0, true)
                        ctx.lineWidth = width * 0.08
                        ctx.strokeStyle = "white"
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(centerX, height * 0.5, width * 0.3, Math.PI, 0, true)
                        ctx.stroke()
                    } else if (connectionType === "wifi-off") {
                        drawWifiArcs(ctx, centerX, centerY, 100, width, height)
                        ctx.lineWidth = width * 0.12
                        ctx.strokeStyle = "white"
                        ctx.beginPath()
                        ctx.moveTo(width * 0.1, height * 0.1)
                        ctx.lineTo(width * 0.9, height * 0.9)
                        ctx.stroke()
                    } else {
                        drawWifiArcs(ctx, centerX, centerY, signal, width, height)
                    }
                }

                function drawWifiArcs(ctx, cx, cy, signalStrength, w, h) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, w * 0.08, 0, Math.PI * 2)
                    ctx.fill()

                    var bars = [
                        {radius: 0.25, angle: 60, strength: 25},
                        {radius: 0.4, angle: 70, strength: 50},
                        {radius: 0.55, angle: 80, strength: 75}
                    ]

                    ctx.lineWidth = w * 0.1
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
                        ctx.arc(cx, cy, w * bar.radius, startAngle, endAngle)
                        ctx.stroke()
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            scanNetworks = []
            scanProc.running = true
        } else {
            scanProc.running = false
        }
    }

    Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 15
        anchors.leftMargin: 10
        anchors.rightMargin: 15
        spacing: 8
        z: 1

        Row {
            width: 360
            height: 32
            spacing: 8

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
                    onClicked: root.close()
                }
            }

            Text {
                text: "Wi‑Fi"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 120; height: 1 }

            Rectangle {
                width: 48
                height: 28
                radius: 14
                color: root.wifiEnabled ? "#0A84FF" : "#4CFFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: "white"
                    x: root.wifiEnabled ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: toggleWifi.running = true
                }
            }
        }

        Item { width: 1; height: 3 }
        Rectangle { width: 430; height: 1; color: "#18FFFFFF" }
    }

    Flickable {
        id: listFlick
        anchors.top: headerColumn.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 8
        anchors.bottomMargin: 60
        clip: true
        contentHeight: contentCol.height
        interactive: !blockInput
        
        property bool blockInput: false
        
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        // Block all interactions when entering password
        MouseArea {
            anchors.fill: parent
            enabled: listFlick.blockInput
            z: 999
            propagateComposedEvents: true
            preventStealing: false
        }

        Column {
            id: contentCol
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width
                height: 48
                radius: 8
                color: "#15FFFFFF"
                visible: root.wifiEnabled
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: "#35FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Loader {
                            width: 18
                            height: 18
                            anchors.centerIn: parent
                            property string currentType: root.activeType
                            
                            sourceComponent: (currentType.indexOf("ethernet") !== -1) ? ethernetIcon : wifiIcon
                            
                            onCurrentTypeChanged: {
                                if (item && currentType.indexOf("ethernet") === -1) {
                                    item.signal = 100
                                    item.connectionType = "wifi"
                                }
                            }
                            onLoaded: {
                                if (item && currentType.indexOf("ethernet") === -1) {
                                    item.signal = 100
                                    item.connectionType = "wifi"
                                }
                            }
                        }
                    }
                    
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        width: parent.width - 90
                        Text {
                            text: root.activeName || "Not Connected"
                            color: "white"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: (root.activeType === "wifi" && root.activeName) ? "Connected" : ""
                            color: "#88FFFFFF"
                            font.pixelSize: 10
                        }
                    }
                    Rectangle {
                        width: 74
                        height: 26
                        radius: 6
                        color: "#20FFFFFF"
                        visible: root.activeType === "wifi" && root.activeName
                        Text {
                            anchors.centerIn: parent
                            text: "Disconnect"
                            color: "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: disconnectActive.running = true
                        }
                    }
                }
            }

            Text {
                text: "Known Networks"
                color: "#88FFFFFF"
                font.pixelSize: 11
                visible: filteredSavedNetworks.count > 0
            }

            Repeater {
                id: filteredSavedNetworks
                model: {
                    var available = []
                    for (var i = 0; i < root.savedNetworks.length; i++) {
                        var saved = root.savedNetworks[i]
                        // Vérifier si le réseau est détecté dans le scan
                        for (var j = 0; j < root.scanNetworks.length; j++) {
                            if (root.scanNetworks[j].ssid === saved.name) {
                                available.push(saved)
                                break
                            }
                        }
                    }
                    return available
                }
                Column {
                    width: parent.width
                    spacing: 4
                    property bool showingActions: false
                    property int networkIndex: index
                    
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: {
                            if (root.activeNetworkIndex === networkIndex) return "#25FFFFFF"
                            if (root.activeNetworkIndex === -1 && mouse.containsMouse) return "#15FFFFFF"
                            return "transparent"
                        }
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            z: 0
                            
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: "#35FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Loader {
                                    sourceComponent: wifiIcon
                                    width: 18
                                    height: 18
                                    anchors.centerIn: parent
                                    onLoaded: {
                                        // Trouver la puissance du signal dans le scan
                                        var signalStrength = 75
                                        for (var i = 0; i < root.scanNetworks.length; i++) {
                                            if (root.scanNetworks[i].ssid === modelData.name) {
                                                signalStrength = parseInt(root.scanNetworks[i].signal || "75")
                                                break
                                            }
                                        }
                                        item.signal = signalStrength
                                        item.connectionType = "wifi"
                                    }
                                }
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - 80
                                
                                Text {
                                    text: modelData.name
                                    color: "white"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                
                                Row {
                                    spacing: 4
                                    
                                    property bool isAvailable: {
                                        for (var i = 0; i < root.scanNetworks.length; i++) {
                                            if (root.scanNetworks[i].ssid === modelData.name) {
                                                return true
                                            }
                                        }
                                        return false
                                    }
                                    
                                    visible: isAvailable || modelData.autoconnect || (root.activeName === modelData.name && root.activeType === "wifi")
                                    
                                    Text {
                                        text: (root.activeName === modelData.name && root.activeType === "wifi") ? "Connected" : ""
                                        color: "#99FFFFFF"
                                        font.pixelSize: 9
                                    }
                                    Text {
                                        text: modelData.autoconnect ? "Auto-Join" : ""
                                        color: "#99FFFFFF"
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: root.activeNetworkIndex === -1
                            enabled: !root.isEnteringPassword
                            z: 1
                            onClicked: {
                                var wasShowing = parent.parent.showingActions
                                var currentIndex = networkIndex
                                
                                // Fermer tous les panneaux Known Networks
                                for (var i = 0; i < root.savedNetworks.length; i++) {
                                    var child = contentCol.children[i + 2]
                                    if (child && child.showingActions !== undefined) {
                                        child.showingActions = false
                                    }
                                }
                                
                                // Fermer tous les panneaux Other Networks
                                for (var j = 0; j < root.scanNetworks.length; j++) {
                                    var scanChild = contentCol.children[j + root.savedNetworks.length + 6]
                                    if (scanChild && scanChild.showingActions !== undefined) {
                                        scanChild.showingActions = false
                                        scanChild.enteringPassword = false
                                    }
                                }
                                
                                root.activeNetworkIndex = -1
                                root.isEnteringPassword = false
                                
                                if (!wasShowing) {
                                    parent.parent.showingActions = true
                                    root.activeNetworkIndex = currentIndex
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        id: actionPanel
                        width: parent.width
                        height: showingActions ? 80 : 0
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
                            
                            Text {
                                text: (root.activeName === modelData.name && root.activeType === "wifi") ? "Connected" : "Not Connected"
                                color: "white"
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }
                            
                            Row {
                                spacing: 8
                                width: parent.width
                                
                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 28
                                    radius: 6
                                    color: connectMouse.containsMouse ? "#40FFFFFF" : "#20FFFFFF"
                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.activeName === modelData.name && root.activeType === "wifi") ? "Disconnect" : "Connect"
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: connectMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.activeName === modelData.name && root.activeType === "wifi") {
                                                disconnectActive.running = true
                                            } else {
                                                connectSaved.command = ["sh", "-c", "nmcli connection up '" + modelData.name + "' "]
                                                connectSaved.running = true
                                            }
                                            parent.parent.parent.parent.parent.showingActions = false
                                            root.activeNetworkIndex = -1
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 28
                                    radius: 6
                                    color: forgetMouse.containsMouse ? "#FF3B30" : "#80222222"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: forgetMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            forgetNetwork.command = ["sh", "-c", "nmcli connection delete id '" + modelData.name + "' "]
                                            forgetNetwork.running = true
                                            parent.parent.parent.parent.parent.showingActions = false
                                            root.activeNetworkIndex = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 3 }
            Rectangle { width: 430; height: 1; color: "#18FFFFFF" }
            Item { width: 1; height: 3 }

            Text {
                text: "Other Networks"
                color: "#88FFFFFF"
                font.pixelSize: 11
            }

            Repeater {
                model: root.scanNetworks
                Column {
                    id: scanItem
                    width: parent.width
                    spacing: 4
                    property bool showingActions: false
                    property bool enteringPassword: false
                    property int scanIndex: index + 1000

                    // When entering password, ensure the field gets focus and disable flicking
                        onEnteringPasswordChanged: {
                            console.log("[Wifi] enteringPasswordChanged", enteringPassword, "scanIndex", scanIndex)
                            listFlick.interactive = !enteringPassword
                            listFlick.blockInput = enteringPassword
                            root.isEnteringPassword = enteringPassword
                            if (enteringPassword) {
                                Qt.callLater(function() {
                                    console.log("[Wifi] trying to focus passFocusScope and inlinePassInput for scanIndex", scanIndex)
                                    try { if (passFocusScope) passFocusScope.forceActiveFocus(); } catch(e) {}
                                    try { if (inlinePassInput) inlinePassInput.forceActiveFocus(); } catch(e) {}
                                    try { Qt.inputMethod.show(); } catch(e) {}
                                })
                            } else {
                                Qt.callLater(function() { try { Qt.inputMethod.hide(); } catch(e) {} })
                            }
                        }

                    // track whether the password input ever got focus
                    property bool hadPasswordFocus: false
                    
                    Rectangle {
                        width: parent.width
                        height: 42
                        radius: 8
                        color: {
                            if (root.activeNetworkIndex === scanIndex) return "#25FFFFFF"
                            if (root.activeNetworkIndex === -1 && mouse2.containsMouse) return "#15FFFFFF"
                            return "transparent"
                        }
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: "#35FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Loader {
                                    sourceComponent: wifiIcon
                                    width: 18
                                    height: 18
                                    anchors.centerIn: parent
                                    onLoaded: {
                                        var signalValue = parseInt(modelData.signal || "50")
                                        item.signal = signalValue
                                        item.connectionType = "wifi"
                                    }
                                }
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - 100
                                
                                Text {
                                    text: modelData.ssid || ""
                                    color: "white"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                
                                Text {
                                    text: (modelData.security || "")
                                    color: "#66FFFFFF"
                                    font.pixelSize: 9
                                }
                            }
                        }
                        
                        MouseArea {
                            id: mouse2
                            anchors.fill: parent
                            hoverEnabled: root.activeNetworkIndex === -1
                            enabled: !scanItem.enteringPassword
                            propagateComposedEvents: false
                            onClicked: {
                                console.log("[Wifi] mouse2 clicked, enabled:", mouse2.enabled, "scanIndex:", scanIndex)
                                var wasShowing = parent.parent.showingActions
                                var currentIndex = scanIndex
                                
                                for (var i = 0; i < root.scanNetworks.length; i++) {
                                    var child = contentCol.children[i + root.savedNetworks.length + 6]
                                    if (child && child.showingActions !== undefined) {
                                        child.showingActions = false
                                        child.enteringPassword = false
                                    }
                                }
                                for (var j = 0; j < root.savedNetworks.length; j++) {
                                    var child2 = contentCol.children[j + 2]
                                    if (child2 && child2.showingActions !== undefined) {
                                        child2.showingActions = false
                                    }
                                }
                                root.activeNetworkIndex = -1
                                root.isEnteringPassword = false
                                
                                if (!wasShowing) {
                                    parent.parent.showingActions = true
                                    parent.parent.enteringPassword = false
                                    root.activeNetworkIndex = currentIndex
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        width: parent.width
                        height: showingActions ? (enteringPassword ? 110 : 80) : 0
                        visible: height > 0
                        color: "#B0000000"
                        radius: 8
                        clip: true
                        z: 1000
                        
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        border.color: "#30FFFFFF"
                        border.width: 1
                        
                        // Forward all key events to the password field when it's shown
                        Keys.forwardTo: enteringPassword ? [ inlinePassInput ] : []

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            width: parent.width - 40
                            
                            Text {
                                visible: !enteringPassword
                                text: (root.activeType === "wifi" && root.activeName === (modelData.ssid || "")) ? "Connected" : "Not Connected"
                                color: "white"
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }

                            FocusScope {
                                visible: enteringPassword
                                width: parent.width
                                height: 32
                                focus: enteringPassword
                                z: 10001

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#20FFFFFF"
                                    radius: 6
                                    border.color: inlinePassInput.activeFocus ? "#0A84FF" : (root.connectionError !== "" ? "#FF3B30" : "transparent")
                                    border.width: 1

                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: {
                                            inlinePassInput.forceActiveFocus()
                                            mouse.accepted = false
                                        }
                                    }

                                    TextField {
                                        id: inlinePassInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 35
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "white"
                                        echoMode: showPass.checked ? TextInput.Normal : TextInput.Password
                                        font.pixelSize: 12
                                        selectionColor: "#0A84FF"
                                        selectByMouse: true
                                        activeFocusOnPress: true
                                        focus: true
                                        
                                        background: Rectangle {
                                            color: "transparent"
                                        }
                                    
                                    Component.onCompleted: {
                                        if (visible && parent.visible) {
                                            Qt.callLater(function() {
                                                forceActiveFocus()
                                            })
                                        }
                                    }
                                    
                                    onVisibleChanged: {
                                        if (visible) {
                                            Qt.callLater(function() {
                                                console.log("[Wifi] inlinePassInput visible for scanIndex", scanIndex)
                                                forceActiveFocus()
                                            })
                                        }
                                    }

                                        onActiveFocusChanged: function(active) {
                                        console.log("[Wifi] inlinePassInput activeFocusChanged", active, "scanIndex", scanIndex)
                                        // Clear error when user focuses password field
                                        if (active) {
                                            root.connectionError = ""
                                            errorTimer.stop()
                                        }
                                        // update global debug string for visibility
                                        try { root.debugFocus = "scanIndex:" + scanIndex + " active:" + active + " entering:" + scanItem.enteringPassword + " block:" + listFlick.blockInput } catch(e) {}
                                        if (active) {
                                            scanItem.hadPasswordFocus = true
                                        } else {
                                            // Only exit password mode if the input had focus previously
                                            if (scanItem.hadPasswordFocus) {
                                                try { scanItem.enteringPassword = false } catch(e) {}
                                                try { listFlick.blockInput = false; listFlick.interactive = true } catch(e) {}
                                                try { Qt.inputMethod.hide(); } catch(e) {}
                                                scanItem.hadPasswordFocus = false
                                            }
                                        }
                                        // clear debug after a short delay
                                        Qt.callLater(function() { try { root.debugFocus = "" } catch(e) {} })
                                    }

                                    Keys.onReturnPressed: {
                                        var ssid = modelData.ssid || ""
                                        connectSecured.command = ["sh", "-c", "nmcli device wifi connect '" + ssid + "' password '" + inlinePassInput.text + "' "]
                                        connectSecured.running = true
                                        
                                        var grandParent = parent.parent.parent.parent
                                        if (grandParent) {
                                            grandParent.showingActions = false
                                            grandParent.enteringPassword = false
                                        }
                                        inlinePassInput.text = ""
                                        root.activeNetworkIndex = -1
                                    }
                                    
                                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                                    }

                                    Image {
                                        id: showPass
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        source: checked ? "image://icon/view-reveal-symbolic" : "image://icon/view-hidden-symbolic"
                                        opacity: 0.7
                                        property bool checked: false
                                        z: 10
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: showPass.checked = !showPass.checked
                                        }
                                    }
                                }
                            }
                            
                            Rectangle {
                                visible: root.connectionError !== "" && enteringPassword
                                width: parent.width
                                height: 40
                                color: "#40FF3B30"
                                radius: 6
                                border.color: "#FF3B30"
                                border.width: 1
                                
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    spacing: 4
                                    
                                    Text {
                                        text: root.connectionError
                                        color: "#FFFFFF"
                                        font.pixelSize: 10
                                        font.bold: true
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                    }
                                    
                                    Text {
                                        text: "Modifiez le mot de passe et réessayez"
                                        color: "#CCFFFFFF"
                                        font.pixelSize: 9
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                            
                            Row {
                                spacing: 8
                                width: parent.width
                                
                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 28
                                    radius: 6
                                    color: connectMouse2.containsMouse ? "#40FFFFFF" : "#20FFFFFF"
                                    
                                    property bool isConnected: (root.activeType === "wifi" && root.activeName === (modelData.ssid || ""))
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: enteringPassword ? "Connect" : (parent.isConnected ? "Disconnect" : "Join")
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: connectMouse2
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        onPressed: function(mouse) {
                                            // claim the press so parent MouseAreas don't react
                                            mouse.accepted = true
                                            console.log("[Wifi] connectMouse2 pressed, claiming event")
                                        }
                                        onEntered: {
                                            console.log("[Wifi] connectMouse2 hovered")
                                        }
                                        onClicked: {
                                            console.log("[Wifi] connectMouse2 clicked, enteringPassword:", enteringPassword, "security:", modelData.security)
                                            var ssid = modelData.ssid || ""
                                            // Reset error when user attempts connection
                                            root.connectionError = ""
                                            errorTimer.stop()
                                            // If not yet in password mode and network requires a password, enter password mode and focus input
                                            if (!enteringPassword && ((modelData.security || "").indexOf("WPA") !== -1 || (modelData.security || "").indexOf("WEP") !== -1)) {
                                                console.log("[Wifi] Entering password mode for:", ssid)
                                                parent.parent.parent.parent.parent.enteringPassword = true
                                                Qt.callLater(function() { try { inlinePassInput.forceActiveFocus(); } catch(e) {} })
                                                return
                                            }
                                            if (enteringPassword) {
                                                console.log("[Wifi] Connecting with password to:", ssid)
                                                var password = inlinePassInput.text
                                                // Create a full WPA2 connection profile
                                                var connName = ssid.replace(/'/g, "'\\''")
                                                var escapedSsid = ssid.replace(/'/g, "'\\''")
                                                var escapedPass = password.replace(/'/g, "'\\''")
                                                connectSecured.command = ["sh", "-c", 
                                                    "nmcli con add type wifi con-name '" + connName + "' ifname '*' ssid '" + escapedSsid + 
                                                    "' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '" + escapedPass + "' 2>/dev/null || " +
                                                    "nmcli con mod '" + connName + "' wifi-sec.psk '" + escapedPass + "' && " +
                                                    "nmcli con up '" + connName + "'"]
                                                connectSecured.running = true
                                                parent.parent.parent.parent.parent.showingActions = false
                                                parent.parent.parent.parent.parent.enteringPassword = false
                                                inlinePassInput.text = ""
                                                root.activeNetworkIndex = -1
                                            } else {
                                                if (parent.isConnected) {
                                                    disconnectActive.running = true
                                                    parent.parent.parent.parent.parent.showingActions = false
                                                    root.activeNetworkIndex = -1
                                                } else {
                                                    if ((modelData.security || "").indexOf("WPA") !== -1 || (modelData.security || "").indexOf("WEP") !== -1) {
                                                        parent.parent.parent.parent.parent.enteringPassword = true
                                                        inlinePassInput.forceActiveFocus()
                                                    } else {
                                                        connectOpen.command = ["sh", "-c", "nmcli dev wifi connect '" + ssid + "'"]
                                                        connectOpen.running = true
                                                        parent.parent.parent.parent.parent.showingActions = false
                                                        root.activeNetworkIndex = -1
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 28
                                    radius: 6
                                    color: forgetMouse2.containsMouse ? "#FF3B30" : "#80222222"
                                    Text {
                                        anchors.centerIn: parent
                                        text: enteringPassword ? "Cancel" : "Forget"
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: forgetMouse2
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (enteringPassword) {
                                                parent.parent.parent.parent.parent.enteringPassword = false
                                                inlinePassInput.text = ""
                                            } else {
                                                var ssid = modelData.ssid || ""
                                                forgetNetwork.command = ["sh", "-c", "nmcli connection delete id '" + ssid + "' "]
                                                forgetNetwork.running = true
                                                parent.parent.parent.parent.parent.showingActions = false
                                                root.activeNetworkIndex = -1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: 8
                color: settingsMouse.containsMouse ? "#25FFFFFF" : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    text: "Wi‑Fi Settings..."
                    color: "#88FFFFFF"
                    font.pixelSize: 11
                    anchors.centerIn: parent
                }
                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: openSettings.running = true
                }
            }
        }
    }

    Process {
        id: checkWifi
        running: false
        command: ["sh", "-c", "nmcli -t -f WIFI radio | grep -qi enabled && echo ON || echo OFF"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = (this.text || "").trim() === "ON"
            }
        }
    }

    Process {
        id: toggleWifi
        running: false
        command: ["sh", "-c", "nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")]
        onExited: checkWifiTimer.restart()
    }

    Timer {
        id: checkWifiTimer
        interval: 600
        repeat: false
        onTriggered: {
            checkWifi.running = true
            listSaved.running = true
            activeConn.running = true
        }
    }

    Process {
        id: listSaved
        running: false
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,AUTOCONNECT connection show | awk -F: '{if($2==\"802-11-wireless\") print $1\"|\"$3}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text ? this.text.trim() : ""
                var arr = []
                if (out !== "") {
                    var lines = out.split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split("|")
                        arr.push({name: parts[0], autoconnect: parts[1] === "yes"})
                    }
                }
                root.savedNetworks = arr
            }
        }
    }

    Process {
        id: activeConn
        running: false
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active | awk -F: 'NR==1{print $1\"|\"$2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = (this.text || "").trim()
                if (out === "") {
                    root.activeName = ""
                    root.activeType = ""
                    return
                }
                var parts = out.split("|")
                root.activeName = parts[0]
                root.activeType = parts[1]
            }
        }
    }

    Process {
        id: scanProc
        running: false
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | sed 's/:/|/g'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text ? this.text.trim() : ""
                var arr = []
                if (out !== "") {
                    var lines = out.split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split("|")
                        arr.push({ssid: parts[0], signal: parts[1], security: parts[2]})
                    }
                    arr.sort(function(a, b) {
                        return parseInt(b.signal || "0") - parseInt(a.signal || "0")
                    })
                }
                root.scanNetworks = arr
            }
        }
    }

    Process {
        id: connectSaved
        running: false
        stdout: StdioCollector {
            onStreamFinished: checkWifiTimer.restart()
        }
    }

    Process {
        id: connectOpen
        running: false
        stdout: StdioCollector {
            onStreamFinished: checkWifiTimer.restart()
        }
    }

    Process {
        id: connectSecured
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("WiFi connect stdout:", this.text);
                checkWifiTimer.restart();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim() !== "") {
                    console.log("WiFi connect error:", this.text);
                    root.connectionError = "Mot de passe incorrect ou erreur de connexion";
                }
            }
        }
        onExited: {
            console.log("WiFi connect exited with code:", exitCode);
            if (exitCode !== 0) {
                root.connectionError = "Échec de la connexion. Vérifiez le mot de passe.";
                errorTimer.restart();
            } else {
                root.connectionError = "";
                errorTimer.stop();
            }
        }
    }

    Process {
        id: forgetNetwork
        running: false
        stdout: StdioCollector {
            onStreamFinished: listSaved.running = true
        }
    }

    Process {
        id: disconnectActive
        running: false
        command: ["sh", "-c", "nmcli connection down '" + root.activeName + "' "]
        stdout: StdioCollector {
            onStreamFinished: checkWifiTimer.restart()
        }
    }

    Process {
        id: openSettings
        running: false
        command: ["sh", "-c", "nm-connection-editor || gnome-control-center wifi || true"]
    }

    Timer {
        id: refreshTimer
        interval: 3000
        repeat: true
        running: root.visible && !root.isEnteringPassword && root.activeNetworkIndex === -1
        triggeredOnStart: false
        onTriggered: {
            if (root.visible && !root.isEnteringPassword && root.activeNetworkIndex === -1) {
                checkWifi.running = true
                listSaved.running = true
                activeConn.running = true
                scanProc.running = true
            }
        }
    }

    Component.onCompleted: {
        checkWifi.running = true
        listSaved.running = true
        activeConn.running = true
    }

    // Temporary debug indicator (non-intrusive)
    Text {
        id: debugText
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        color: "#FFFFFFFF"
        font.pixelSize: 10
        text: root.debugFocus
        visible: root.debugFocus !== ""
        z: 9999
        opacity: 0.9
        Rectangle { anchors.fill: parent; color: "transparent" }
    }

    // Global overlay to block all mouse events when entering password
    MouseArea {
        id: globalOverlay
        anchors.fill: parent
        enabled: false  // Désactivé car il bloque les boutons Connect
        z: 10000
        propagateComposedEvents: false
        preventStealing: true
        hoverEnabled: false
        visible: false
        
        onPressed: function(mouse) {
            mouse.accepted = true
        }
        onReleased: function(mouse) {
            mouse.accepted = true
        }
        onClicked: function(mouse) {
            mouse.accepted = true
        }
    }
}

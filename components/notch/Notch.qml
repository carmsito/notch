import QtQuick 2.15
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../controlcenter/modules"
import "../bar/modules"
import "../performance"
import "../notification"
import "modules"

Item {
    id: root

    width: hovered ? expandedWidth : collapsedWidth

    property int collapsedHeight: 30
    property int expandedHeight: 395

    property int collapsedRadius: 20
    property int expandedRadius: 15

    property int collapsedWidth: 700 
    property int expandedWidth: 475  // Largeur pour contenir les modules

    property int hoverTriggerWidth: 150 

    property bool hovered: false
    property bool isLocked: false  // Verrouiller l'état expanded
    property bool isInteractingWithModules: false
    property bool showingBluetoothDevices: false  // Affichage de la liste Bluetooth
    property bool showingWifiNetworks: false      // Affichage de la liste Wi‑Fi
    property bool showingSoundCenter: false       // Rubrique son avancée
    property bool needsKeyboardFocus: false       // Pour demander le focus clavier
    property var monitorStates: ({})
    property string hostMonitorName: ""
    property bool runtimeActive: true
    property string videoIslandStatePath: Quickshell.statePath("video_island_state.json")
    property bool videoIslandEnabled: false
    property bool videoIslandPromptDismissed: false
    property bool videoIslandPromptVisible: false
    property bool videoPreviewActive: false
    property int compactScrollAccumulator: 0
    property string effectiveVideoUrl: videoBridge.hasData ? videoBridge.url : mprisWatcher.url
    property double effectiveVideoTime: videoBridge.hasData ? videoBridge.time : mprisWatcher.position
    property bool videoEmbedEnabled: true
    // Empêche le hover initial de s'activer au démarrage (barre démarre compacte)
    property bool startupLock: true

    signal monitorToggled(string monitorName, bool enabled)

    onVideoIslandEnabledChanged: updateVideoPrompt()
    onVideoIslandPromptDismissedChanged: updateVideoPrompt()

    function isPrimaryMonitor(monitorName) {
        return monitorName === "eDP-1" || monitorName === "eDP-2"
    }

    function isExcludedFromPrimaryRule(monitorName) {
        return (monitorName || "").toLowerCase() === "dp-1"
    }

    function hasEligibleExternalMonitor() {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            var name = screens[i] && screens[i].name ? screens[i].name : ""
            if (!isPrimaryMonitor(name) && !isExcludedFromPrimaryRule(name)) {
                return true
            }
        }
        return false
    }

    function isPrimaryMonitorLocked(monitorName) {
        return isPrimaryMonitor(monitorName) && !hasEligibleExternalMonitor()
    }

    function isMonitorEnabled(monitorName) {
        if (isPrimaryMonitorLocked(monitorName)) {
            return true
        }

        if (!monitorStates) {
            return true
        }

        var state = monitorStates[monitorName]
        return state === undefined ? true : state
    }

    function loadVideoIslandState() {
        try {
            var raw = videoIslandFile.text()
            if (!raw || raw.trim() === "") {
                videoIslandEnabled = false
                videoIslandPromptDismissed = false
                return
            }
            var parsed = JSON.parse(raw)
            videoIslandEnabled = !!parsed.enabled
            videoIslandPromptDismissed = !!parsed.promptDismissed
        } catch (error) {
            console.warn("Failed to load video island state:", error)
            videoIslandEnabled = false
            videoIslandPromptDismissed = false
        }
    }

    function saveVideoIslandState() {
        try {
            var payload = JSON.stringify({
                enabled: videoIslandEnabled,
                promptDismissed: videoIslandPromptDismissed
            })
            videoIslandFile.setText(payload)
        } catch (error) {
            console.warn("Failed to save video island state:", error)
        }
    }

    function updateVideoPrompt() {
        var shouldPrompt = !videoIslandEnabled && !videoIslandPromptDismissed &&
                           mprisWatcher.isBrowserPlayer &&
                           mprisWatcher.playbackStatus !== "Stopped"
        if (shouldPrompt) {
            videoIslandPromptVisible = true
        } else if (!mprisWatcher.isPlaying) {
            videoIslandPromptVisible = false
        }
    }

    function runMprisCommand(args) {
        if (!args || args.length === 0) {
            return
        }
        mprisCommandProc.command = args
        mprisCommandProc.running = true
    }

    function toggleMprisPlayPause() {
        if (!mprisWatcher.playerName) {
            return
        }
        runMprisCommand([
            "python3",
            "/home/emmanuel/dotfiles/quickshell/components/notch/modules/mpris_ctl.py",
            "--player",
            mprisWatcher.playerName,
            "--action",
            "playpause"
        ])
    }

    // Navigation entre conteneurs
    property var containers: ["Control Center", "Performance", "Notifications", "Video"]
    property int currentContainerIndex: 0
    property string currentContainerTitle: containers[currentContainerIndex]
    property int videoContainerIndex: containers.indexOf("Video")
    property bool compactContainersEnabled: true
    property bool compactVideoActive: !hovered && currentContainerIndex === videoContainerIndex
    property bool controlCenterActive: runtimeActive && hovered && currentContainerIndex === 0 &&
                                       !showingBluetoothDevices && !showingWifiNetworks && !showingSoundCenter
    property bool performanceActive: runtimeActive && hovered && currentContainerIndex === 1
    property bool bluetoothPageActive: runtimeActive && hovered && currentContainerIndex === 0 && showingBluetoothDevices
    property bool wifiPageActive: runtimeActive && hovered && currentContainerIndex === 0 && showingWifiNetworks
    property bool soundPageActive: runtimeActive && hovered && currentContainerIndex === 0 && showingSoundCenter

    onCurrentContainerIndexChanged: {
        if (currentContainerIndex !== 0) {
            showingSoundCenter = false
        }
    }

    implicitHeight: notchRect.height

    // --- LOGIQUE ---
    Battery {
        id: batteryData
        pollingEnabled: root.runtimeActive
    }
    
    Time {
        id: timeSource
        pollingEnabled: root.runtimeActive
    }

    FileView {
        id: videoIslandFile
        path: root.videoIslandStatePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadVideoIslandState()
        onFileChanged: root.loadVideoIslandState()
    }

    MprisWatcher {
        id: mprisWatcher
        active: root.runtimeActive
        onUpdated: root.updateVideoPrompt()
    }

    VideoBridge {
        id: videoBridge
    }

    Process {
        id: mprisCommandProc
        running: false
    }

    // Timer pour éviter le clignotement du hover
    Timer {
        id: hoverTimer
        interval: 150  // Petit délai pour éviter fermeture trop brusque
        repeat: false
        onTriggered: {
            // Ne pas fermer si verrouillé
            if (!root.isLocked) {
                root.hovered = false
                // Reset le showingBluetoothDevices quand on quitte complètement
                root.showingBluetoothDevices = false
                // Reset le showingWifiNetworks quand on quitte complètement
                root.showingWifiNetworks = false
                // Reset le panneau son avancé
                root.showingSoundCenter = false
                
                // Reset container to default (skip if compact containers are enabled)
                if (!root.compactContainersEnabled) {
                    root.currentContainerIndex = 0
                }
            }
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

    // (La zone de détection hover est déclarée comme dernier enfant de notchRect,
    // plus bas, pour être au-dessus des autres MouseArea dans l'ordre d'empilement.)

    // 2. Le rectangle principal
    Item {
        id: notchRect
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: root.width
        height: hovered ? expandedHeight : collapsedHeight
        // "radius" garde son nom pour ne rien casser ailleurs dans le fichier,
        // mais sert maintenant de taille de chanfrein (coupe à 45°, style octogone).
        property real radius: hovered ? expandedRadius : collapsedRadius
        // En mode compact : diagonale sur toute la hauteur (façon ruban/chevron).
        // En mode expanded : chanfrein léger seulement (panneau large, pas de ruban).
        property real chamfer: root.hovered ? expandedRadius : height

        property color fillColor: hovered ? '#f0000000' : '#fa000000'
        property color strokeColor: hovered ? "#30FFFFFF" : "#33FFFFFF"
        property color color: fillColor

        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutExpo } }
        Behavior on chamfer { NumberAnimation { duration: 100; easing.type: Easing.OutExpo } }
        Behavior on fillColor { ColorAnimation { duration: 100 } }
        Behavior on strokeColor { ColorAnimation { duration: 100 } }

        // Forme sharp : haut carré (collé pixel-perfect à l'écran), coins bas coupés
        // en diagonale à 45° (chanfrein façon coin d'octogone) — aucun arrondi.
        // (QtQuick.Shapes n'est pas disponible dans cet environnement Quickshell,
        // donc la forme est construite avec des Rectangle simples + 2 carrés tournés
        // à 45° pour les diagonales — fiable, pas de rendu foireux.)
        Item {
            id: notchShapeRoot
            anchors.fill: parent
            clip: true

            // Corps du haut (plein largeur, jusqu'au début du chanfrein)
            Rectangle {
                x: 0; y: 0
                width: notchRect.width
                height: Math.max(notchRect.height - notchRect.chamfer, 0)
                color: notchRect.fillColor
            }

            // Bande du bas (plus étroite, entre les deux chanfreins)
            Rectangle {
                x: notchRect.chamfer
                y: Math.max(notchRect.height - notchRect.chamfer, 0)
                width: Math.max(notchRect.width - 2 * notchRect.chamfer, 0)
                height: notchRect.chamfer
                color: notchRect.fillColor
            }

            // Remplissage diagonal du coin bas-gauche (carré tourné à 45°, centré au
            // point interne où le corps du haut rencontre la bande du bas)
            Rectangle {
                width: notchRect.chamfer * Math.SQRT2
                height: width
                rotation: 45
                color: notchRect.fillColor
                x: notchRect.chamfer - width / 2
                y: (notchRect.height - notchRect.chamfer) - height / 2
            }

            // Remplissage diagonal du coin bas-droit (symétrique)
            Rectangle {
                width: notchRect.chamfer * Math.SQRT2
                height: width
                rotation: 45
                color: notchRect.fillColor
                x: (notchRect.width - notchRect.chamfer) - width / 2
                y: (notchRect.height - notchRect.chamfer) - height / 2
            }

            // --- Bordure : côtés + bas chanfreiné uniquement (pas le haut, collé à l'écran) ---

            Rectangle { // côté gauche
                x: 0; y: 0
                width: 1
                height: Math.max(notchRect.height - notchRect.chamfer, 0)
                color: notchRect.strokeColor
            }

            Rectangle { // côté droit
                x: notchRect.width - 1; y: 0
                width: 1
                height: Math.max(notchRect.height - notchRect.chamfer, 0)
                color: notchRect.strokeColor
            }

            Rectangle { // bas plat
                x: notchRect.chamfer
                y: notchRect.height - 1
                width: Math.max(notchRect.width - 2 * notchRect.chamfer, 0)
                height: 1
                color: notchRect.strokeColor
            }

            Rectangle { // diagonale bas-gauche
                width: notchRect.chamfer * Math.SQRT2
                height: 1
                rotation: 45
                color: notchRect.strokeColor
                x: notchRect.chamfer / 2 - width / 2
                y: (notchRect.height - notchRect.chamfer / 2) - height / 2
            }

            Rectangle { // diagonale bas-droite
                width: notchRect.chamfer * Math.SQRT2
                height: 1
                rotation: -45
                color: notchRect.strokeColor
                x: (notchRect.width - notchRect.chamfer / 2) - width / 2
                y: (notchRect.height - notchRect.chamfer / 2) - height / 2
            }
        }

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
            anchors.leftMargin: wsWidget.isInteracting ? 0 : 34
            
            anchors.horizontalCenter: wsWidget.isInteracting ? parent.horizontalCenter : undefined
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            
            width: wsWidget.isInteracting ? parent.width : undefined

            spacing: 10
            
            // Gestion visibilité globale (disparait si la notch s'ouvre en mode expanded)
            opacity: (root.hovered || root.compactVideoActive) ? 0 : 1
            visible: opacity > 0 
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // --- WORKSPACES ---
            Workspaces {
                id: wsWidget
                anchors.verticalCenter: parent.verticalCenter
                // On passe la largeur totale disponible à Workspaces pour qu'il sache s'étendre
                fullWidth: notchRect.width
                pollingEnabled: root.runtimeActive
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
            anchors.verticalCenterOffset: -4
            time: timeSource.time
            color: "white"
            
            // Disparait si on joue avec les Workspaces ou si hover
            visible: !wsWidget.isInteracting && !root.hovered && !root.compactVideoActive
        }

        // 3. CONNEXION ICONS (DROITE) - Wi-Fi/Ethernet/Bluetooth
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 38
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            spacing: 8

            opacity: (root.hovered || root.compactVideoActive) ? 0 : 1
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

        // 3b. COMPACT VIDEO CONTAINER (OVERLAY)
        Item {
            id: compactVideoOverlay
            anchors.fill: parent
            visible: root.compactVideoActive
            z: 50

            VideoContainer {
                anchors.fill: parent
                compact: true
                featureEnabled: root.videoIslandEnabled
                embedEnabled: root.videoEmbedEnabled
                previewActive: root.videoPreviewActive

                title: mprisWatcher.title
                artist: mprisWatcher.artist
                playbackStatus: mprisWatcher.playbackStatus
                position: mprisWatcher.position
                length: mprisWatcher.length
                playerName: mprisWatcher.playerName
                trackId: mprisWatcher.trackId

                url: root.effectiveVideoUrl
                urlTime: root.effectiveVideoTime

                onPlayPauseRequested: root.toggleMprisPlayPause()
                onPreviewRequested: root.videoPreviewActive = true
                onPreviewClosed: root.videoPreviewActive = false
                onActivateRequested: {
                    root.videoIslandEnabled = true
                    root.videoIslandPromptVisible = false
                    root.saveVideoIslandState()
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
            height: 70
            color: "transparent"
            
            opacity: root.hovered && !root.showingBluetoothDevices && !root.showingWifiNetworks && !root.showingSoundCenter ? 1 : 0
            visible: opacity > 0
            
            Behavior on opacity { 
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
            }

            // Titre du conteneur (Centré)
            Item {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15

                property int scrollAccumulator: 0

                MouseArea {
                    anchors.fill: parent
                    onWheel: {
                        // Reset accumulator if direction changes
                        if ((parent.scrollAccumulator > 0 && wheel.angleDelta.y < 0) || 
                            (parent.scrollAccumulator < 0 && wheel.angleDelta.y > 0)) {
                            parent.scrollAccumulator = 0
                        }

                        parent.scrollAccumulator += wheel.angleDelta.y
                        
                        // Seuil augmenté pour réduire la sensibilité du trackpad
                        if (parent.scrollAccumulator >= 800) {
                            if (root.currentContainerIndex > 0) {
                                root.currentContainerIndex--
                            } else {
                                root.currentContainerIndex = root.containers.length - 1
                            }
                            parent.scrollAccumulator = 0
                        } else if (parent.scrollAccumulator <= -800) {
                            if (root.currentContainerIndex < root.containers.length - 1) {
                                root.currentContainerIndex++
                            } else {
                                root.currentContainerIndex = 0
                            }
                            parent.scrollAccumulator = 0
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
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

                    // Indicateur de page
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: indicatorRow.width + 16
                        height: 16
                        radius: 8
                        color: "#502a2a2a"
                        border.color: "#30FFFFFF"
                        border.width: 1
                        
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        Row {
                            id: indicatorRow
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Repeater {
                                model: root.containers.length
                                
                                Rectangle {
                                    width: index === root.currentContainerIndex ? 16 : 6
                                    height: 6
                                    radius: 3
                                    color: index === root.currentContainerIndex ? "#FFFFFF" : "#50FFFFFF"
                                    
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                        }
                    }
                }
            }
            
            // Bouton cadenas (Lock/Unlock)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.top: parent.top
                anchors.topMargin: 15
                width: 32
                height: 32
                radius: 16
                color: root.isLocked ? "#50FFFFFF" : "#302a2a2a"
                border.color: "#30FFFFFF"
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Canvas {
                    id: lockIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 18
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = root.isLocked ? "#000000" : "#FFFFFF"
                        ctx.fillStyle = root.isLocked ? "#000000" : "#FFFFFF"
                        ctx.lineWidth = 1.5
                        ctx.lineCap = "round"
                        
                        // Corps du cadenas (rectangle arrondi)
                        var bodyX = width * 0.2
                        var bodyY = height * 0.45
                        var bodyWidth = width * 0.6
                        var bodyHeight = height * 0.5
                        var bodyRadius = 2
                        
                        ctx.beginPath()
                        ctx.moveTo(bodyX + bodyRadius, bodyY)
                        ctx.lineTo(bodyX + bodyWidth - bodyRadius, bodyY)
                        ctx.arcTo(bodyX + bodyWidth, bodyY, bodyX + bodyWidth, bodyY + bodyRadius, bodyRadius)
                        ctx.lineTo(bodyX + bodyWidth, bodyY + bodyHeight - bodyRadius)
                        ctx.arcTo(bodyX + bodyWidth, bodyY + bodyHeight, bodyX + bodyWidth - bodyRadius, bodyY + bodyHeight, bodyRadius)
                        ctx.lineTo(bodyX + bodyRadius, bodyY + bodyHeight)
                        ctx.arcTo(bodyX, bodyY + bodyHeight, bodyX, bodyY + bodyHeight - bodyRadius, bodyRadius)
                        ctx.lineTo(bodyX, bodyY + bodyRadius)
                        ctx.arcTo(bodyX, bodyY, bodyX + bodyRadius, bodyY, bodyRadius)
                        ctx.closePath()
                        ctx.fill()
                        
                        if (root.isLocked) {
                            // Anse fermée
                            var arcCenterX = width / 2
                            var arcCenterY = bodyY
                            var arcRadius = width * 0.25
                            
                            ctx.beginPath()
                            ctx.arc(arcCenterX, arcCenterY, arcRadius, Math.PI, 0, false)
                            ctx.stroke()
                            
                            // Ligne verticale gauche
                            ctx.beginPath()
                            ctx.moveTo(arcCenterX - arcRadius, arcCenterY)
                            ctx.lineTo(arcCenterX - arcRadius, bodyY)
                            ctx.stroke()
                            
                            // Ligne verticale droite
                            ctx.beginPath()
                            ctx.moveTo(arcCenterX + arcRadius, arcCenterY)
                            ctx.lineTo(arcCenterX + arcRadius, bodyY)
                            ctx.stroke()
                        } else {
                            // Anse ouverte (décalée vers la droite)
                            var openArcCenterX = width / 2 + width * 0.15
                            var openArcCenterY = bodyY - height * 0.1
                            var openArcRadius = width * 0.25
                            
                            ctx.beginPath()
                            ctx.arc(openArcCenterX, openArcCenterY, openArcRadius, Math.PI * 0.75, Math.PI * 0.1, false)
                            ctx.stroke()
                            
                            // Ligne verticale gauche seulement
                            ctx.beginPath()
                            ctx.moveTo(width * 0.32, bodyY - height * 0.03)
                            ctx.lineTo(width * 0.32, bodyY)
                            ctx.stroke()
                        }
                        
                        // Trou de serrure
                        var keyholeCenterX = width / 2
                        var keyholeCenterY = bodyY + bodyHeight * 0.4
                        var keyholeRadius = width * 0.08
                        
                        ctx.fillStyle = root.isLocked ? "#FFFFFF" : "#000000"
                        ctx.beginPath()
                        ctx.arc(keyholeCenterX, keyholeCenterY, keyholeRadius, 0, Math.PI * 2)
                        ctx.fill()
                        
                        // Fente de la serrure
                        var slitWidth = width * 0.05
                        var slitHeight = bodyHeight * 0.3
                        ctx.fillRect(keyholeCenterX - slitWidth / 2, keyholeCenterY + keyholeRadius / 2, slitWidth, slitHeight)
                    }
                    
                    Connections {
                        target: root
                        function onIsLockedChanged() {
                            lockIcon.requestPaint()
                        }
                    }
                    
                    Component.onCompleted: requestPaint()
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        root.isLocked = !root.isLocked
                        if (root.isLocked) {
                            // Si on verrouille, forcer l'état expanded
                            root.hovered = true
                            hoverTimer.stop()
                        }
                    }
                    
                    onEntered: {
                        parent.scale = 1.1
                    }
                    
                    onExited: {
                        parent.scale = 1.0
                    }
                }
                
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }

        // ==================================================
        // 5. SLIDING CONTENT (REMPLACE LES COLONNES SÉPARÉES)
        // ==================================================
        Item {
            id: contentViewport
            anchors.top: parent.top
            anchors.topMargin: 70
            anchors.horizontalCenter: parent.horizontalCenter
            width: 460
            height: parent.height - 70
            clip: true
            
            opacity: root.hovered && !root.showingBluetoothDevices && !root.showingWifiNetworks && !root.showingSoundCenter ? 1 : 0
            visible: opacity > 0
            
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Row {
                id: slidingRow
                // Move the row based on index
                x: -root.currentContainerIndex * 460
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                
                // Container 1: Control Center
                Item {
                    width: 460
                    height: contentViewport.height
                    
                    Column {
                        id: controlCenterModules
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 460
                        spacing: 10
                        
                        // Rangée WiFi + Bluetooth
                        Row {
                            spacing: 10

                            WifiModule {
                                id: wifiMod
                                width: 225
                                height: 70
                                pollingEnabled: root.controlCenterActive
                                onClicked: {
                                    root.showingSoundCenter = false
                                    root.showingWifiNetworks = true
                                }
                            }

                            BluetoothModule {
                                id: bluetoothMod
                                width: 225
                                height: 70
                                pollingEnabled: root.controlCenterActive
                                
                                onClicked: {
                                    root.showingSoundCenter = false
                                    root.showingBluetoothDevices = true
                                }
                            }
                        }

                        // Module Luminosité Laptop
                        BrightnessModule {
                            id: brightnessLaptop
                            width: 450
                            anchors.horizontalCenter: parent.horizontalCenter
                            displayName: "Display"
                            deviceName: ""
                            pollingEnabled: root.controlCenterActive
                            onInteractionStarted: hoverTimer.stop()
                        }
                        
                        // Module Luminosité ScreenPad
                        BrightnessModule {
                            id: brightnessScreenpad
                            width: 450
                            anchors.horizontalCenter: parent.horizontalCenter
                            displayName: "ScreenPad"
                            deviceName: "asus_screenpad"
                            pollingEnabled: root.controlCenterActive
                            onInteractionStarted: hoverTimer.stop()
                        }

                        // Module Volume direct (ouvre le panneau avancé hors slider)
                        VolumeModule {
                            id: volumeMod
                            width: 450
                            anchors.horizontalCenter: parent.horizontalCenter
                            pollingEnabled: root.controlCenterActive
                            onInteractionStarted: hoverTimer.stop()
                            onAdvancedRequested: {
                                root.showingBluetoothDevices = false
                                root.showingWifiNetworks = false
                                root.showingSoundCenter = true
                                hoverTimer.stop()
                            }
                        }
                    }
                }
                
                // Container 2: Performance
                Item {
                    width: 460
                    height: contentViewport.height
                    
                    PerformanceContainer {
                        id: performanceContainer
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        pollingEnabled: root.performanceActive
                    }

                    Rectangle {
                        id: performanceMonitorSwitchBar
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: performanceContainer.bottom
                        anchors.topMargin: 10
                        width: 440
                        height: 36
                        radius: 18
                        color: "#2f151515"
                        border.color: "#35FFFFFF"
                        border.width: 1

                        Flickable {
                            id: performanceMonitorFlick
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentWidth: performanceMonitorChipRow.width
                            contentHeight: Math.max(height, performanceMonitorChipRow.height)
                            flickableDirection: Flickable.HorizontalFlick
                            interactive: contentWidth > width

                            Row {
                                id: performanceMonitorChipRow
                                spacing: 8
                                y: Math.round((parent.height - height) / 2)

                                Repeater {
                                    model: Quickshell.screens

                                    Rectangle {
                                        required property var modelData

                                        property string monitorName: modelData && modelData.name ? modelData.name : "unknown"
                                        property bool primaryLocked: root.isPrimaryMonitorLocked(monitorName)
                                        property bool monitorEnabled: root.isMonitorEnabled(monitorName)
                                        property bool currentMonitor: monitorName === root.hostMonitorName

                                        height: 24
                                        width: chipContent.width + 16
                                        radius: 12
                                        color: primaryLocked ? "#3a4a4a4a" : (monitorEnabled ? "#65FFFFFF" : "#25202020")
                                        border.color: currentMonitor ? "#90A8D0FF" : (monitorEnabled ? "#82FFFFFF" : "#45FFFFFF")
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        Item {
                                            id: chipContent
                                            anchors.centerIn: parent
                                            width: chipIndicator.width + 6 + chipLabel.implicitWidth
                                            height: Math.max(chipIndicator.height, chipLabel.implicitHeight)

                                            Item {
                                                id: chipIndicator
                                                width: primaryLocked ? 10 : 8
                                                height: primaryLocked ? 12 : 8
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter

                                                Rectangle {
                                                    visible: primaryLocked
                                                    x: Math.round((parent.width - width) / 2)
                                                    y: 0
                                                    width: 6
                                                    height: 5
                                                    radius: 2
                                                    color: "transparent"
                                                    border.color: "#D9D9D9"
                                                    border.width: 1
                                                }

                                                Rectangle {
                                                    visible: primaryLocked
                                                    x: Math.round((parent.width - width) / 2)
                                                    y: 4
                                                    width: 8
                                                    height: 7
                                                    radius: 2
                                                    color: "#D9D9D9"
                                                }

                                                Rectangle {
                                                    visible: !primaryLocked
                                                    anchors.centerIn: parent
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    color: monitorEnabled ? "#81E08D" : "#6A6A6A"
                                                }
                                            }

                                            Text {
                                                id: chipLabel
                                                x: chipIndicator.width + 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: monitorName
                                                color: primaryLocked ? "#E2E2E2" : (monitorEnabled ? "#111111" : "#D9D9D9")
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: "SF Pro Display"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !primaryLocked
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                            onClicked: {
                                                root.monitorToggled(monitorName, !monitorEnabled)
                                            }

                                            onEntered: {
                                                if (enabled) {
                                                    parent.scale = 1.04
                                                }
                                            }

                                            onExited: {
                                                parent.scale = 1.0
                                            }
                                        }

                                        Behavior on scale {
                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: livepaperPauseChip

                                    property bool paperPaused: false

                                    height: 24
                                    width: pauseChipContent.width + 16
                                    radius: 12
                                    color: paperPaused ? "#65FFFFFF" : "#25202020"
                                    border.color: paperPaused ? "#82FFFFFF" : "#45FFFFFF"
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Process {
                                        id: livepaperPauseToggleProc

                                        property bool nextPaused: false

                                        command: ["sh", "-c", nextPaused ? "mkdir -p \"$HOME/.cache/skwd-mpvpaper\"; : > \"$HOME/.cache/skwd-mpvpaper/eDP-1.manual-pause\"; printf '{\"command\":[\"set_property\",\"pause\",true]}\\n' | socat - UNIX-CONNECT:/tmp/mpvpaper-eDP-1.sock" : "rm -f \"$HOME/.cache/skwd-mpvpaper/eDP-1.manual-pause\"; WS=$(hyprctl -j monitors | jq -r '.[] | select(.name==\"eDP-1\") | .activeWorkspace.id'); SP=$(hyprctl -j clients | jq -r --argjson w \"${WS:-null}\" 'any(.[]; .workspace.id==$w and ((.fullscreen // 0) > 0))'); printf '{\"command\":[\"set_property\",\"pause\",%s]}\\n' \"$SP\" | socat - UNIX-CONNECT:/tmp/mpvpaper-eDP-1.sock"]
                                        onExited: livepaperPauseChip.paperPaused = nextPaused
                                    }

                                    Item {
                                        id: pauseChipContent
                                        anchors.centerIn: parent
                                        width: pauseChipIndicator.width + 6 + pauseChipLabel.implicitWidth
                                        height: Math.max(pauseChipIndicator.height, pauseChipLabel.implicitHeight)

                                        Rectangle {
                                            id: pauseChipIndicator
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: livepaperPauseChip.paperPaused ? "#E0A481" : "#81E08D"
                                        }

                                        Text {
                                            id: pauseChipLabel
                                            x: pauseChipIndicator.width + 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: livepaperPauseChip.paperPaused ? "Paused" : "Playing"
                                            color: livepaperPauseChip.paperPaused ? "#111111" : "#D9D9D9"
                                            font.pixelSize: 12
                                            font.bold: true
                                            font.family: "SF Pro Display"
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            livepaperPauseToggleProc.nextPaused = !livepaperPauseChip.paperPaused
                                            livepaperPauseToggleProc.running = true
                                        }

                                        onEntered: parent.scale = 1.04
                                        onExited: parent.scale = 1.0
                                    }

                                    Behavior on scale {
                                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }

                // Container 3: Notifications
                Item {
                    width: 460
                    height: contentViewport.height
                    
                    NotificationPanel {
                        anchors.fill: parent
                        anchors.margins: 5
                    }
                }

                // Container 4: Video
                Item {
                    width: 460
                    height: contentViewport.height

                    VideoContainer {
                        anchors.fill: parent
                        compact: false
                        featureEnabled: root.videoIslandEnabled
                        embedEnabled: root.videoEmbedEnabled
                        previewActive: root.videoPreviewActive

                        title: mprisWatcher.title
                        artist: mprisWatcher.artist
                        playbackStatus: mprisWatcher.playbackStatus
                        position: mprisWatcher.position
                        length: mprisWatcher.length
                        playerName: mprisWatcher.playerName
                        trackId: mprisWatcher.trackId

                        url: root.effectiveVideoUrl
                        urlTime: root.effectiveVideoTime

                        onPlayPauseRequested: root.toggleMprisPlayPause()
                        onPreviewRequested: root.videoPreviewActive = true
                        onPreviewClosed: root.videoPreviewActive = false
                        onActivateRequested: {
                            root.videoIslandEnabled = true
                            root.videoIslandPromptVisible = false
                            root.saveVideoIslandState()
                        }
                    }
                }
            }
        }

        // Compact scroll navigation (mode compact uniquement)
        MouseArea {
            id: compactScrollArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: root.compactContainersEnabled && !root.hovered

            onWheel: {
                if (wsWidget.isInteracting) {
                    return
                }

                if ((root.compactScrollAccumulator > 0 && wheel.angleDelta.y < 0) ||
                    (root.compactScrollAccumulator < 0 && wheel.angleDelta.y > 0)) {
                    root.compactScrollAccumulator = 0
                }

                root.compactScrollAccumulator += wheel.angleDelta.y

                if (root.compactScrollAccumulator >= 800) {
                    if (root.currentContainerIndex > 0) {
                        root.currentContainerIndex--
                    } else {
                        root.currentContainerIndex = root.containers.length - 1
                    }
                    root.compactScrollAccumulator = 0
                } else if (root.compactScrollAccumulator <= -800) {
                    if (root.currentContainerIndex < root.containers.length - 1) {
                        root.currentContainerIndex++
                    } else {
                        root.currentContainerIndex = 0
                    }
                    root.compactScrollAccumulator = 0
                }
            }
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
                if (!root.isLocked) {
                    hoverTimer.restart()
                }
            }
        }

        // Zone de déclenchement du hover : petite bande centrée, tout en haut de la barre
        // (pas toute la largeur/hauteur — juste ce point d'entrée précis)
        // Elle ne fait qu'OUVRIR : la fermeture est entièrement gérée par globalHoverArea.
        // (si on gérait aussi la fermeture ici, désactiver ce MouseArea au moment où
        // hovered passe à true déclenche un faux "exited" qui relance le timer de fermeture
        // alors que la souris est toujours dans le bloc -> flicker/spam)
        MouseArea {
            id: hoverTriggerArea
            width: root.hoverTriggerWidth
            height: 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: !root.hovered
            z: 1001  // Au-dessus de globalHoverArea et de tout le reste

            onEntered: {
                if (!root.startupLock) {
                    root.hovered = true
                    hoverTimer.stop()
                }
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
            pollingEnabled: root.bluetoothPageActive
            
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

        SoundCenterPanel {
            id: soundCenterPanel
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            pollingEnabled: root.soundPageActive

            opacity: root.hovered && root.showingSoundCenter ? 1 : 0
            visible: root.currentContainerIndex === 0 && opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            onInteractionStarted: {
                hoverTimer.stop()
            }

            onClose: {
                root.showingSoundCenter = false
            }
        }
    }

    VideoActivationPrompt {
        id: videoPrompt
        anchors.horizontalCenter: notchRect.horizontalCenter
        anchors.bottom: notchRect.top
        anchors.bottomMargin: 8
        visible: root.videoIslandPromptVisible

        onAccepted: {
            root.videoIslandEnabled = true
            root.videoIslandPromptVisible = false
            root.saveVideoIslandState()
        }

        onDismissed: {
            root.videoIslandPromptDismissed = true
            root.videoIslandPromptVisible = false
            root.saveVideoIslandState()
        }
    }
}

import QtQuick 2.15
import Quickshell
import Quickshell.Hyprland
import "."

Item {
    id: root
    
    property bool isInteracting: false
    property bool pollingEnabled: true
    property real fullWidth: 400 
    property int hoveredWorkspaceId: -1 
    property int refreshTrigger: 0
    property var iconSourceCache: ({})

    // Mots-clés pour détecter les apps depuis leur titre
    property var appKeywords: {
        "firefox": ["firefox"],
        "discord": ["discord"],
        "chrome": ["chrome", "google"],
        "code": ["code", "visual studio"],
        "kitty": ["kitty"],
        "alacritty": ["alacritty"],
        "thunar": ["thunar"],
        "dbeaver": ["dbeaver"],
        "insomnia": ["insomnia"]
    }
    
    // Variations de noms spécifiques pour certaines apps
    property var appNameVariations: {
        "code": ["visual-studio-code", "com.visualstudio.code", "vscode"],
        "chrome": ["google-chrome", "google-chrome-stable"],
        "discord": ["discord", "Discord"],
        "firefox": ["firefox", "firefox-esr"],
        "thunar": ["thunar", "Thunar"],
        "kitty": ["kitty", "kitty-icon"],
        "alacritty": ["alacritty", "Alacritty"],
        "dbeaver": ["dbeaver", "dbeaver-ce"],
        "insomnia": ["insomnia", "Insomnia"]
    }
    
    // Fonction pour générer automatiquement tous les chemins possibles
    function generateIconCandidates(appName) {
        if (!appName) return [];
        appName = normalizeAppName(appName);
        if (appName === "") return [];
        
        var candidates = [];
        var appNameLower = appName.toLowerCase();
        var seen = {};
        
        function pushName(name) {
            var cleaned = normalizeAppName(name);
            if (cleaned === "" || seen[cleaned]) {
                return;
            }
            seen[cleaned] = true;
            candidates.push(cleaned);
        }

        // Variations spécifiques d'abord (souvent les bons noms d'icône)
        if (appNameVariations[appNameLower]) {
            for (var i = 0; i < appNameVariations[appNameLower].length; i++) {
                pushName(appNameVariations[appNameLower][i]);
            }
        }

        pushName(appNameLower);
        pushName(appName);
        pushName(appNameLower.replace(/\s+/g, "-"));
        pushName(appNameLower.replace(/\s+/g, "_"));
        pushName(appNameLower.replace(/\s+/g, ""));

        return candidates;
    }

    // Fonction helper pour détecter l'app depuis le titre
    function normalizeAppName(value) {
        var cleaned = (value || "").trim().toLowerCase();
        if (cleaned === "" || cleaned === "~") {
            return "";
        }
        cleaned = cleaned.replace(/^[`'"]+|[`'"]+$/g, "");
        cleaned = cleaned.split(/\s+/)[0];
        cleaned = cleaned.replace(/[^a-z0-9._-]/g, "");
        if (cleaned === "" || cleaned === "~" || cleaned === "-" || cleaned === "_") {
            return "";
        }
        return cleaned;
    }

    function getCachedIconSource(key) {
        if (!key || !iconSourceCache) {
            return undefined;
        }
        return iconSourceCache[key];
    }

    function setCachedIconSource(key, value) {
        if (!key) {
            return;
        }
        var next = {};
        for (var cacheKey in iconSourceCache) {
            next[cacheKey] = iconSourceCache[cacheKey];
        }
        next[key] = value;
        iconSourceCache = next;
    }

    // Fonction helper pour détecter l'app depuis le titre
    function detectAppFromTitle(title) {
        if (!title) return "";
        var lowerTitle = title.toLowerCase();
        
        for (var appName in appKeywords) {
            var keywords = appKeywords[appName];
            for (var i = 0; i < keywords.length; i++) {
                if (lowerTitle.includes(keywords[i])) {
                    return appName;
                }
            }
        }
        
        // Fallback: premier mot du titre
        var token = title.split(/[\s\-–—:]/)[0];
        return normalizeAppName(token);
    }

    // Fonction helper pour obtenir les icônes candidates
    function getIconCandidates(appName) {
        return generateIconCandidates(appName);
    }

    // Fonction helper pour preview popup
    function getPreviewIcon(className) {
        if (!className) return "";
        if (className === "~") return "";
        var lowerClass = className.toLowerCase();
        
        // Obtenir tous les candidats et retourner le premier du thème
        var candidates = generateIconCandidates(lowerClass);
        
        // Chercher un candidat image://icon/ en priorité
        for (var i = 0; i < candidates.length; i++) {
            if (candidates[i].indexOf("image://icon/") === 0) {
                return candidates[i];
            }
        }
        
        // Fallback: utiliser le nom directement
        return "image://icon/" + lowerClass;
    }

    // Largeur animée
    width: isInteracting ? fullWidth : Math.max(activeContent.width, 30)
    height: 24

    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
    
    // Timer global qui force la vérification périodique de tous les toplevels
    Timer {
        id: globalRefreshTimer
        interval: 4000
        repeat: true
        running: root.pollingEnabled && root.isInteracting
        onTriggered: {
            root.refreshTrigger++;
        }
    }

    // --- TIMER DE SÉCURITÉ ---
    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (hoverArea.containsMouse || isMouseOverChild()) {
                return;
            }
            root.isInteracting = false
        }
    }

    function isMouseOverChild() {
        return hoverArea.containsMouse;
    }

    // --- MOUSE AREA PRINCIPALE ---
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true 
        propagateComposedEvents: true

        onEntered: {
            closeTimer.stop()
            root.isInteracting = true
        }
        
        onPositionChanged: {
            closeTimer.stop()
            root.isInteracting = true
        }

        onExited: {
            closeTimer.restart()
        }
    }

    // Conteneur Gris
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 24
        radius: 12
        color: root.isInteracting ? "#00ffffff" : "transparent"
        clip: true

        Row {
            id: activeContent
            anchors.centerIn: parent
            spacing: root.isInteracting ? 20 : 10

            // --- INDICATEUR DU WORKSPACE ACTUEL (mode compact) ---
            Rectangle {
                id: currentWorkspaceIndicator
                width: currentWorkspaceRow.width + 12
                height: 24
                radius: 12
                color: "#33FFFFFF"
                visible: !root.isInteracting
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                
                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                
                Row {
                    id: currentWorkspaceRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    property int currentWsId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : -1
                    property int previousWsId: currentWsId
                    property real xOffset: 0
                    
                    x: xOffset
                    
                    onCurrentWsIdChanged: {
                        if (previousWsId > 0 && currentWsId > 0 && previousWsId !== currentWsId) {
                            // Direction du slide
                            var slideDistance = 30
                            if (currentWsId > previousWsId) {
                                // Workspace supérieur -> vient de la droite
                                slideAnim.from = slideDistance
                            } else {
                                // Workspace inférieur -> vient de la gauche
                                slideAnim.from = -slideDistance
                            }
                            slideAnim.to = 0
                            slideAnim.restart()
                        }
                        previousWsId = currentWsId
                    }
                    
                    NumberAnimation {
                        id: slideAnim
                        target: currentWorkspaceRow
                        property: "xOffset"
                        duration: 300
                        easing.type: Easing.OutExpo
                    }
                    
                    // Numéro du workspace
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : ""
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                    }
                    
                    // Séparateur (uniquement si des apps sont présentes)
                    Rectangle {
                        width: 1
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#80FFFFFF"
                        visible: appsRow.visibleAppsCount > 0
                    }
                    
                    // Icônes des apps ouvertes sur le workspace actuel
                    Row {
                        id: appsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        
                        property int visibleAppsCount: {
                            var count = 0;
                            var currentWsId = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : -1;
                            for (var i = 0; i < Hyprland.toplevels.length; i++) {
                                if (Hyprland.toplevels[i].workspace.id === currentWsId) {
                                    count++;
                                }
                            }
                            return count;
                        }
                        
                        Repeater {
                            model: Hyprland.toplevels
                            delegate: Item {
                                id: compactAppDelegate
                                property var tl: modelData
                                property int currentWsId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : -1
                                property bool belongsToCurrentWs: tl.workspace.id === currentWsId
                                
                                visible: belongsToCurrentWs
                                width: belongsToCurrentWs ? 16 : 0
                                height: 16
                                
                                property string detectedClass: ""
                                
                                Component.onCompleted: {
                                    updateClass();
                                }
                                
                                // Force recheck when root.refreshTrigger changes
                                property int localTrigger: root.refreshTrigger
                                onLocalTriggerChanged: {
                                    updateClass();
                                }
                                
                                function updateClass() {
                                    if (!tl) return "";
                                    
                                    var ipc = tl.lastIpcObject || {};
                                    var classHint = root.normalizeAppName((ipc.class || tl.appId || ""));
                                    var title = tl.title || "";
                                    var c = classHint !== "" ? classHint : root.detectAppFromTitle(title);
                                    
                                    if (c !== "" && c !== detectedClass) {
                                        detectedClass = c;
                                        compactIconImage.loadIcon(c);
                                    }
                                }
                                
                                Item {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    
                                    Image {
                                        id: compactIconImage
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        cache: true
                                        sourceSize.width: 18
                                        sourceSize.height: 18
                                        
                                        property var candidates: []
                                        property int candidateIndex: 0
                                        property string appClass: ""
                                        property bool isLoading: false

                                        function loadIcon(c) {
                                            appClass = c;
                                            var cached = root.getCachedIconSource(c);
                                            if (cached !== undefined) {
                                                source = cached;
                                                isLoading = false;
                                                return;
                                            }
                                            var list = root.getIconCandidates(c);
                                            candidates = list;
                                            candidateIndex = 0;
                                            if (list.length > 0) {
                                                tryNextCandidate();
                                            } else {
                                                root.setCachedIconSource(c, "");
                                                source = "";
                                            }
                                        }
                                        
                                        function tryNextCandidate() {
                                            if (candidateIndex >= candidates.length) {
                                                isLoading = false;
                                                if (appClass) root.setCachedIconSource(appClass, "");
                                                source = "";
                                                return;
                                            }
                                            isLoading = true;
                                            var name = candidates[candidateIndex];
                                            if (!name) {
                                                candidateIndex++;
                                                tryNextCandidate();
                                                return;
                                            }
                                            source = name.indexOf("image://") === 0 ? name : ("image://icon/" + name);
                                        }

                                        Component.onCompleted: {
                                            // Le timer se chargera de tout
                                        }
                                        
                                        onStatusChanged: {
                                            if (!isLoading) return;
                                            if (status === Image.Ready) {
                                                if (appClass) root.setCachedIconSource(appClass, source);
                                                isLoading = false;
                                            } else if (status === Image.Error || status === Image.Null) {
                                                candidateIndex++;
                                                tryNextCandidate();
                                            }
                                        }
                                    }
                                    
                                    // Fallback: lettre si pas d'icône
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#33FFFFFF"
                                        radius: 3
                                        visible: compactIconImage.status !== Image.Ready
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: compactIconImage.appClass ? compactIconImage.appClass.charAt(0).toUpperCase() : "?"
                                            color: "white"
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Hyprland.workspaces
                delegate: Item {
                    id: wsDelegate
                    property int wsId: modelData.id
                    property bool isActive: !!(Hyprland.activeWorkspace && Hyprland.activeWorkspace.id === wsId)
                    
                    property bool isHovered: delegateMouseArea.containsMouse
                    property bool isVisible: root.isInteracting || isActive

                    width: isVisible ? contentRow.width : 0
                    height: 24
                    visible: width > 0
                    
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    MouseArea {
                        id: delegateMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onEntered: { 
                            closeTimer.stop()
                            root.isInteracting = true 
                            root.hoveredWorkspaceId = wsDelegate.wsId
                        }
                        onPositionChanged: {
                            closeTimer.stop()
                            root.isInteracting = true
                            root.hoveredWorkspaceId = wsDelegate.wsId
                        }
                        onExited: {
                            closeTimer.restart()
                            root.hoveredWorkspaceId = -1
                        }
                        onClicked: Hyprland.dispatch("workspace " + wsDelegate.wsId)
                    }

                    Row {
                        id: contentRow
                        spacing: 4
                        
                        // 1. Le Bouton du Workspace
                        Rectangle {
                            width: (wsDelegate.isActive || wsDelegate.isHovered) ? 40 : 24
                            height: 24
                            radius: 12
                            color: (wsDelegate.isActive || wsDelegate.isHovered) && root.isInteracting ? "#33FFFFFF" : "transparent"
                            
                            Behavior on width { NumberAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: wsDelegate.wsId
                                color: wsDelegate.isActive ? "white" : "#80FFFFFF"
                                font.bold: true
                            }
                            
                            // Preview popup en mode compact
                            Rectangle {
                                id: previewPopup
                                visible: wsDelegate.isHovered && !root.isInteracting && previewAppCount > 0
                                
                                property int previewAppCount: {
                                    var count = 0;
                                    for (var i = 0; i < Hyprland.toplevels.length; i++) {
                                        if (Hyprland.toplevels[i].workspace.id === wsDelegate.wsId) {
                                            count++;
                                        }
                                    }
                                    return count;
                                }
                                
                                anchors.top: parent.bottom
                                anchors.topMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: previewRow.width + 16
                                height: 32
                                radius: 8
                                color: "#DD000000"
                                border.color: "#33FFFFFF"
                                border.width: 1
                                z: 100
                                
                                Row {
                                    id: previewRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    
                                    // Numéro du workspace
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wsDelegate.wsId
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                    
                                    Rectangle {
                                        width: 1
                                        height: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#33FFFFFF"
                                    }
                                    
                                    // Icônes des apps
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        
                                        Repeater {
                                            model: Hyprland.toplevels
                                            delegate: Item {
                                                property var tl: modelData
                                                property bool belongsToWs: tl.workspace.id === wsDelegate.wsId
                                                
                                                visible: belongsToWs
                                                width: belongsToWs ? 20 : 0
                                                height: 20
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                    cache: true
                                                    sourceSize.width: 20
                                                    sourceSize.height: 20
                                                    Component.onCompleted: {
                                                        var ipc = tl.lastIpcObject || {};
                                                        var c = (ipc.class || "").toLowerCase();
                                                        if (c) {
                                                            source = root.getPreviewIcon(c);
                                                        }
                                                    }
                                                    onStatusChanged: {}
                                                    
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: "#33FFFFFF"
                                                        radius: 3
                                                        visible: parent.status !== Image.Ready
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: {
                                                                var ipc = tl.lastIpcObject || {};
                                                                var c = ipc.class || "";
                                                                return c ? c.charAt(0).toUpperCase() : "?";
                                                            }
                                                            color: "white"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Icônes des applis
                        Row {
                            visible: wsDelegate.isHovered
                            spacing: 2
                            
                            Repeater {
                                model: Hyprland.toplevels
                                delegate: Item {
                                    id: appDelegate
                                    property var tl: modelData
                                    property bool belongsToWs: tl.workspace.id === wsDelegate.wsId
                                    
                                    visible: belongsToWs
                                    width: belongsToWs ? 24 : 0
                                    height: 24
                                    
                                    property string detectedClass: ""
                                    
                                    Component.onCompleted: {
                                        // console.log("🆕 NEW TOPLEVEL CREATED - workspace:", wsDelegate.wsId);
                                        updateClass();
                                    }
                                    
                                    // Force recheck when root.refreshTrigger changes
                                    property int localTrigger: root.refreshTrigger
                                    onLocalTriggerChanged: {
                                        updateClass();
                                    }
                                    
                                    function updateClass() {
                                        if (!tl) return "";
                                        
                                        var ipc = tl.lastIpcObject || {};
                                        var classHint = root.normalizeAppName((ipc.class || tl.appId || ""));
                                        var title = tl.title || "";
                                        var c = classHint !== "" ? classHint : root.detectAppFromTitle(title);
                                        
                                        if (c !== "" && c !== detectedClass) {
                                            detectedClass = c;
                                            iconImage.loadIcon(c);
                                        }
                                    }

                                    // 🔥 Icône d'application
                                    Item {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        
                                        Image {
                                            id: iconImage
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                            cache: true
                                            sourceSize.width: 24
                                            sourceSize.height: 24
                                            
                                            property var candidates: []
                                            property int candidateIndex: 0
                                            property string appClass: ""
                                            property bool isLoading: false

                                            function loadIcon(c) {
                                                appClass = c;
                                                var cached = root.getCachedIconSource(c);
                                                if (cached !== undefined) {
                                                    source = cached;
                                                    isLoading = false;
                                                    return;
                                                }
                                                var list = root.getIconCandidates(c);
                                                candidates = list;
                                                candidateIndex = 0;
                                                if (list.length > 0) {
                                                    tryNextCandidate();
                                                } else {
                                                    root.setCachedIconSource(c, "");
                                                    source = "";
                                                }
                                            }
                                            
                                            function tryNextCandidate() {
                                                if (candidateIndex >= candidates.length) {
                                                    isLoading = false;
                                                    if (appClass) root.setCachedIconSource(appClass, "");
                                                    source = "";
                                                    return;
                                                }
                                                isLoading = true;
                                                var name = candidates[candidateIndex];
                                                if (!name) {
                                                    candidateIndex++;
                                                    tryNextCandidate();
                                                    return;
                                                }
                                                source = name.indexOf("image://") === 0 ? name : ("image://icon/" + name);
                                            }

                                            Component.onCompleted: {
                                                // Le timer se chargera de tout
                                            }
                                            
                                            onStatusChanged: {
                                                if (!isLoading) return;
                                                if (status === Image.Ready) {
                                                    if (appClass) root.setCachedIconSource(appClass, source);
                                                    isLoading = false;
                                                } else if (status === Image.Error || status === Image.Null) {
                                                    candidateIndex++;
                                                    tryNextCandidate();
                                                }
                                            }
                                        }
                                        
                                        // Fallback: lettre si pas d'icône
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#33FFFFFF"
                                            radius: 4
                                            visible: iconImage.status !== Image.Ready && iconImage.appClass.toLowerCase() !== "kitty"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: iconImage.appClass ? iconImage.appClass.charAt(0).toUpperCase() : "?"
                                                color: "white"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                        }
                                        
                                        // Fallback pour kitty: afficher le chemin
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#33FFFFFF"
                                            radius: 4
                                            visible: iconImage.status !== Image.Ready && iconImage.appClass.toLowerCase() === "kitty"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: appDelegate.tl.title || "~"
                                                color: "white"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

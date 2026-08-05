import QtQuick 2.15
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    height: 70
    radius: 12

    property bool isActive: false
    property int volumeLevel: 50
    property bool isMuted: false
    property int lastKnownVolume: 50  // Pour calculer la différence
    property int previousVolumeLevel: 50
    property bool pollingEnabled: true
    signal interactionStarted()
    signal interactionEnded()
    signal advancedRequested()

    function sinkResolvePrefix() {
        return "target=$(pactl list short sinks 2>/dev/null | awk '$2==\"global-audio\" {print $2; exit}'); " +
               "if [ -z \"$target\" ]; then " +
               "target=$(pactl list short sinks 2>/dev/null | awk '$2==\"global_audio\" {print $2; exit}'); " +
               "fi; " +
               "if [ -z \"$target\" ]; then " +
               "target=$(pactl list sinks 2>/dev/null | awk -v RS='' -F'\\n' '{name=\"\"; desc=\"\"; for(i=1;i<=NF;i++){line=$i; sub(/^[[:space:]]+/,\"\",line); if(line ~ /^Name: /){name=substr(line,7)} else if(line ~ /^Description: /){desc=substr(line,14)}} if(name!=\"\" && (tolower(name) ~ /global[-_ ]audio/ || tolower(desc) ~ /global[-_ ]audio/)){print name; exit}}'); " +
               "fi; "
    }

    color: isActive ? "#60404040" : "#50404040"
    border.color: "#30FFFFFF"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    function setVolumeLevel(level) {
        var newVolume = Math.max(0, Math.min(100, Math.round(level)));
        volumeLevel = newVolume;
        lastKnownVolume = newVolume;
        sliderMouse.value = newVolume / 100;
        if (newVolume > 0) {
            previousVolumeLevel = newVolume;
        }

        setVolume.command = ["sh", "-c", root.sinkResolvePrefix() + "if [ -n \"$target\" ]; then pactl set-sink-volume \"$target\" " + newVolume + "%; fi"];
        setVolume.running = true;

        if (root.isMuted && newVolume > 0) {
            unmuteVolume.command = ["sh", "-c", root.sinkResolvePrefix() + "if [ -n \"$target\" ]; then pactl set-sink-mute \"$target\" 0; fi"];
            unmuteVolume.running = true;
        } else if (newVolume === 0) {
            root.isMuted = false;
        }
    }

    function toggleVolumeMinimum() {
        if (volumeLevel <= 0) {
            setVolumeLevel(previousVolumeLevel > 0 ? previousVolumeLevel : 50);
        } else {
            previousVolumeLevel = volumeLevel;
            setVolumeLevel(0);
        }
    }

    // Lecture du volume actuel (global-audio en priorité)
    Process {
        id: getVolume
        running: false
        command: ["sh", "-c", root.sinkResolvePrefix() + "if [ -n \"$target\" ]; then pactl get-sink-volume \"$target\" | head -n1 | awk -F'/' '{gsub(/[^0-9]/,\"\",$2); print $2}'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (this.text || "").trim();
                if (trimmed !== "") {
                    var vol = parseInt(trimmed);
                    root.volumeLevel = vol;
                    root.lastKnownVolume = vol;
                    sliderMouse.value = vol / 100;
                    if (vol > 0) {
                        root.previousVolumeLevel = vol;
                    }
                }
            }
        }
        onExited: {
            running = false;
        }
    }

    // Lecture mute (global-audio en priorité)
    Process {
        id: getMuteStatus
        running: false
        command: ["sh", "-c", root.sinkResolvePrefix() + "if [ -n \"$target\" ]; then pactl get-sink-mute \"$target\" | awk '{print ($2==\"yes\"?1:0)}'; else echo 0; fi "]
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (this.text || "").trim();
                root.isMuted = (trimmed === "1");
            }
        }
        onExited: {
            running = false;
        }
    }

    // Poll volume
    Timer {
        interval: 1500
        repeat: true
        running: root.pollingEnabled
        onTriggered: {
            if (!sliderMouse.pressed) {
                if (!getVolume.running) getVolume.running = true;
                if (!getMuteStatus.running) getMuteStatus.running = true;
            }
        }
    }

    Component.onCompleted: {
        // Lire le volume immédiatement au démarrage
        if (pollingEnabled) {
            getVolume.running = true;
            getMuteStatus.running = true;
        }
    }

    onPollingEnabledChanged: {
        if (pollingEnabled && !sliderMouse.pressed) {
            if (!getVolume.running) getVolume.running = true;
            if (!getMuteStatus.running) getMuteStatus.running = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        
        onEntered: {
            root.isActive = true
        }
        onExited: {
            root.isActive = false
        }
        onClicked: {
            var localToSlider = mapToItem(sliderMouse, mouse.x, mouse.y)
            var inSliderBounds = localToSlider.x >= 0 && localToSlider.x <= sliderMouse.width &&
                                 localToSlider.y >= 0 && localToSlider.y <= sliderMouse.height
            if (!inSliderBounds) {
                root.advancedRequested()
            }
        }
    }
    
    // Disposition: Icône volume bas - Slider - Icône volume haut
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -5
        spacing: 8
        width: parent.width - 24
        
        // Label en haut
        Text {
            text: "Sound"
            color: "white"
            font.pixelSize: 13
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Affichage du volume en %
        Text {
            text: root.volumeLevel + "%"
            color: root.isMuted ? "#FF6B6B" : "white"
            font.pixelSize: 11
            opacity: 0.7
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Row avec icône - slider - icône
        Row {
            width: parent.width
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Icône volume faible (gauche)
            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.isMuted ? 0.3 : 0.7

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleVolumeMinimum()
                }
                
                // Rectangle du haut-parleur (base)
                Rectangle {
                    width: 4
                    height: 6
                    color: "white"
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1
                }
                
                // Pavillon (trapèze créé avec un polygon Canvas)
                Canvas {
                    width: 7
                    height: 12
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.fillStyle = "white";
                        ctx.beginPath();
                        ctx.moveTo(0, 3);      // Haut gauche
                        ctx.lineTo(6, 0);      // Haut droit
                        ctx.lineTo(6, 12);     // Bas droit
                        ctx.lineTo(0, 9);      // Bas gauche
                        ctx.closePath();
                        ctx.fill();
                    }
                }
                
                // Une seule onde sonore faible
                Canvas {
                    width: 6
                    height: 10
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 0.8
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.strokeStyle = "white";
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.arc(-2, 5, 5, -0.5, 0.5, false);
                        ctx.stroke();
                    }
                }

                Rectangle {
                    visible: root.volumeLevel <= 0
                    width: 2
                    height: parent.height + 2
                    radius: 1
                    color: "white"
                    rotation: -45
                    anchors.centerIn: parent
                }
            }
            
            // Slider au centre
            Item {
                width: parent.width - 36 - 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    id: sliderTrack
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#40FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle {
                        id: sliderFill
                        width: parent.width * sliderMouse.value
                        height: parent.height
                        radius: 3
                        color: "white"
                    }
                }
                
                Rectangle {
                    id: sliderHandle
                    width: 20
                    height: 20
                    radius: 10
                    color: "white"
                    x: (sliderTrack.width - width) * sliderMouse.value
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Behavior on x { 
                        NumberAnimation { 
                            duration: sliderMouse.pressed ? 0 : 150 
                        } 
                    }
                }
                
                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true // Empêche le PathView de voler le drag
                    
                    property real value: 0.5
                    // Ajout du contrôle par scroll
                    onWheel: {
                        var step = 5;
                        if (wheel.angleDelta.y > 0) {
                            value = Math.min(1, value + step / 100);
                        } else if (wheel.angleDelta.y < 0) {
                            value = Math.max(0, value - step / 100);
                        }
                        root.setVolumeLevel(Math.round(value * 100));
                    }
                    
                    onEntered: {
                        root.interactionStarted()
                    }
                    
                    onExited: {
                        // Ne signaler la fin d'interaction que si on ne presse plus
                        if (!pressed) {
                            root.interactionEnded()
                        }
                    }
                    
                    onPressed: {
                        root.interactionStarted()
                        updateValue(mouse.x)
                    }
                    
                    onReleased: {
                        root.interactionEnded()
                        // Relire le volume immédiatement après le relâchement pour resynchroniser
                        getVolume.running = true;
                        getMuteStatus.running = true;
                    }
                    
                    function updateValue(mouseX) {
                        value = Math.max(0, Math.min(1, mouseX / width));
                        root.setVolumeLevel(Math.round(value * 100));
                    }
                    
                    onPositionChanged: {
                        if (pressed) {
                            updateValue(mouse.x);
                        }
                    }
                }
            }
            
            // Icône volume fort (droite)
            Item {
                width: 22
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.isMuted ? 0.3 : 1.0
                
                // Rectangle du haut-parleur (base)
                Rectangle {
                    width: 4
                    height: 6
                    color: "white"
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1
                }
                
                // Pavillon (trapèze créé avec un polygon Canvas)
                Canvas {
                    width: 7
                    height: 12
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.fillStyle = "white";
                        ctx.beginPath();
                        ctx.moveTo(0, 3);      // Haut gauche
                        ctx.lineTo(6, 0);      // Haut droit
                        ctx.lineTo(6, 12);     // Bas droit
                        ctx.lineTo(0, 9);      // Bas gauche
                        ctx.closePath();
                        ctx.fill();
                    }
                }
                
                // Trois ondes sonores fortes
                Repeater {
                    model: 3
                    Canvas {
                        width: 8
                        height: 14
                        x: 11 + index * 3
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 0.9 - (index * 0.15)
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.strokeStyle = "white";
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            var radius = 4 + index * 2;
                            ctx.arc(-2, 7, radius, -0.6 + index * 0.1, 0.6 - index * 0.1, false);
                            ctx.stroke();
                        }
                    }
                }
            }
        }
    }
    
    // Process pour définir le volume
    Process {
        id: setVolume
        running: false
    }

    Process {
        id: muteVolume
        running: false
        onExited: {
            root.isMuted = true;
        }
    }

    Process {
        id: unmuteVolume
        running: false
        onExited: {
            root.isMuted = false;
        }
    }
}

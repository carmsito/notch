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
    // Optionnel: node/stream id à contrôler (laisser vide pour fallback pactl)
    property string targetNode: ""
    // Compteur de tentatives de détection
    property int detectionAttempts: 0

    signal interactionStarted()
    signal interactionEnded()

    color: isActive ? "#60404040" : "#502a2a2a"
    border.color: "#30FFFFFF"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    // Lecture du volume actuel (global / node)
    Process {
        id: getVolume
        running: false
        command: ["sh", "-c", (root.targetNode !== "" ? ("wpctl get-volume " + root.targetNode + " | awk '{print int($2 * 100)}'") : "pactl get-sink-volume @DEFAULT_SINK@ | head -n1 | awk -F'/' '{gsub(/[^0-9]/,\"\",$2); print $2}'")]
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (this.text || "").trim();
                if (trimmed !== "") {
                    var vol = parseInt(trimmed);
                    root.volumeLevel = vol;
                    root.lastKnownVolume = vol;
                    sliderMouse.value = vol / 100;
                } else if (root.targetNode !== "") {
                    console.log("VolumeModule: empty volume read, clearing targetNode and retrying detection");
                    root.targetNode = "";
                    detectRetryTimer.running = true;
                    detectAudioProc.running = true;
                }
            }
        }
        onExited: {
            if (exitCode !== 0 && root.targetNode !== "") {
                console.log("VolumeModule: getVolume error (" + exitCode + "), resetting targetNode and scheduling detection");
                root.targetNode = "";
                detectRetryTimer.running = true;
                detectAudioProc.running = true;
            }
            running = false;
        }
    }

    // Lecture mute
    Process {
        id: getMuteStatus
        running: false
        command: ["sh", "-c", (root.targetNode !== "" ? ("wpctl get-volume " + root.targetNode + " | grep -q MUTED && echo 1 || echo 0") : "pactl get-sink-mute @DEFAULT_SINK@ | awk '{print ($2==\"yes\"?1:0)}' ")]
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (this.text || "").trim();
                root.isMuted = (trimmed === "1");
            }
        }
        onExited: {
            if (exitCode !== 0 && root.targetNode !== "") {
                console.log("VolumeModule: getMuteStatus error (" + exitCode + "), resetting targetNode and retrying detection");
                root.targetNode = "";
                detectRetryTimer.running = true;
                detectAudioProc.running = true;
            }
            running = false;
        }
    }

    // Poll volume
    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (!sliderMouse.pressed) {
                getVolume.running = true;
                getMuteStatus.running = true;
            }
        }
    }

    Component.onCompleted: {
        // Lire le volume immédiatement au démarrage
        getVolume.running = true;
        getMuteStatus.running = true;
        // Lancer la détection du node en parallèle
        detectAudioProc.running = true;
    }

    // Retry detection tant que pas d'ID
    Timer {
        id: detectRetryTimer
        interval: 2500
        repeat: true
        running: true
        onTriggered: {
            if (root.targetNode === "") {
                console.log("VolumeModule: retrying audio node detection (#" + (root.detectionAttempts + 1) + ")");
                detectAudioProc.running = true;
            } else {
                running = false;
            }
        }
    }

    Process {
        id: detectAudioProc
        running: false
        command: ["sh", "-c",
                  "sink=$(pactl info 2>/dev/null | awk -F': ' '/Default Sink/ {print $2}'); " +
                  "if [ -n \"$sink\" ]; then " +
                  "wpctl status 2>/dev/null | awk -v s=\"$sink\" '$0 ~ s && $1 ~ /^[[:space:]]*[0-9]+\./ {gsub(/\..*/, \"\", $1); gsub(/^[[:space:]]*/, \"\", $1); print $1; exit}' | head -n1; " +
                  "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text ? this.text.trim() : "";
                if (out && out !== "") {
                    console.log("VolumeModule: detected audio node id:", out);
                    root.targetNode = out;
                    detectRetryTimer.running = false;
                } else {
                    console.log("VolumeModule: no audio node detected, using pactl fallback");
                    root.targetNode = "";
                    detectRetryTimer.running = true;
                }
                root.detectionAttempts += 1;
                getVolume.running = true;
                getMuteStatus.running = true;
            }
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
        onPressed: mouse.accepted = false
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
                        var newVolume = Math.round(value * 100);
                        
                        console.log("VolumeModule: Setting volume to", newVolume);
                        
                        // Mettre à jour directement avec la valeur absolue (même à 0)
                        root.volumeLevel = newVolume;
                        root.lastKnownVolume = newVolume;
                        
                        // Appliquer sur le node cible (ou ID 38 par défaut) avec valeur absolue (0.00 à 1.00)
                        var nodeId = root.targetNode !== "" ? root.targetNode : "";
                        if (nodeId !== "") {
                            var volumeValue = (newVolume / 100).toFixed(2);
                            setVolume.command = ["wpctl", "set-volume", nodeId, volumeValue];
                            console.log("VolumeModule: Command = wpctl set-volume", nodeId, volumeValue);
                            setVolume.running = true;
                        } else {
                            // Use pactl on default sink
                            setVolume.command = ["sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + newVolume + "%"];
                            console.log("VolumeModule: Command = pactl set-sink-volume @DEFAULT_SINK@", newVolume + "%");
                            setVolume.running = true;
                        }

                        // Unmute si on change le volume au-dessus de 0
                        if (root.isMuted && newVolume > 0) {
                            if (nodeId !== "") {
                                unmuteVolume.command = ["sh", "-c", "wpctl set-mute " + nodeId + " 0"];
                            } else {
                                unmuteVolume.command = ["sh", "-c", "pactl set-sink-mute @DEFAULT_SINK@ 0"];
                            }
                            unmuteVolume.running = true;
                        }
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
        onExited: {
            console.log("VolumeModule: setVolume exited with code", exitCode);
            if (exitCode !== 0 && stderr) {
                console.error("VolumeModule: Error:", stderr.trim());
            }
        }
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

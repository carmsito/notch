import QtQuick 2.15
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    height: 70
    radius: 12
    
    property bool isActive: false
    property int brightnessLevel: 100
    property string displayName: "Display"  // Nom affiché
    property string deviceName: ""  // Nom du device pour brightnessctl (vide = default)
    
    signal interactionStarted()
    signal interactionEnded()
    
    color: isActive ? "#60404040" : "#502a2a2a"
    border.color: "#30FFFFFF"
    border.width: 1
    
    Behavior on color { ColorAnimation { duration: 150 } }
    
    // Lecture de la luminosité actuelle
    Process {
        id: getBrightness
        running: false
        // If no deviceName is set, try to pick a suitable backlight device (prefer ones without 'screen'/'screenpad')
        command: ["sh", "-c",
                  "dev=\"\"; " +
                  "if [ \"" + root.deviceName + "\" != \"\" ]; then dev=\"" + root.deviceName + "\"; else " +
                  "dev=$(ls /sys/class/backlight 2>/dev/null | grep -Ev 'screen|screenpad' | head -n1); if [ -z \"$dev\" ]; then dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); fi; fi; " +
                  "if [ -n \"$dev\" ]; then brightnessctl -d \"$dev\" g 2>/dev/null && brightnessctl -d \"$dev\" m 2>/dev/null; else brightnessctl g 2>/dev/null && brightnessctl m 2>/dev/null; fi || echo '100\n100'
                  "]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (this.text || "").trim();
                var lines = trimmed.split("\n");
                if (lines.length >= 2) {
                    var current = parseFloat(lines[0]);
                    var max = parseFloat(lines[1]);
                    if (!isNaN(current) && !isNaN(max) && max > 0) {
                        var percent = Math.round((current / max) * 100);
                        root.brightnessLevel = percent;
                        sliderMouse.value = percent / 100;
                    }
                }
            }
        }
        
        onExited: {
            running = false;
        }
    }
    
    Component.onCompleted: {
        // Lire la luminosité immédiatement au démarrage
        getBrightness.running = true;
    }
    
    // Timer pour rafraîchir la luminosité
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!sliderMouse.pressed) {
                getBrightness.running = true;
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
    
    // Disposition: Icône basse luminosité - Slider - Icône haute luminosité
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -5
        spacing: 8
        width: parent.width - 24
        
        // Label en haut
        Text {
            text: root.displayName
            color: "white"
            font.pixelSize: 13
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Row avec icône - slider - icône
        Row {
            width: parent.width
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Icône soleil faible (gauche)
            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.6
                
                // Cercle central
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "white"
                    anchors.centerIn: parent
                }
                
                // Rayons (8 petits cercles autour)
                Repeater {
                    model: 8
                    Rectangle {
                        width: 2
                        height: 2
                        radius: 1
                        color: "white"
                        x: parent.width / 2 - width / 2 + Math.cos((index * 45) * Math.PI / 180) * 7
                        y: parent.height / 2 - height / 2 + Math.sin((index * 45) * Math.PI / 180) * 7
                    }
                }
            }
            
            // Slider au centre
            Item {
                width: parent.width - 36 - 20  // Total - 2 icônes - spacing
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
                    
                    property real value: 1.0
                    
                    onEntered: {
                        root.interactionStarted()
                    }
                    
                    onExited: {
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
                    }
                    
                    function updateValue(mouseX) {
                        value = Math.max(0, Math.min(1, mouseX / width));
                        var newBrightness = Math.round(value * 100);
                        root.brightnessLevel = newBrightness;
                        
                        // Appliquer la luminosité avec brightnessctl
                        // prefer a backlight device excluding screen/screenpad when deviceName not provided
                        var cmd = "dev=\"\"; ";
                        cmd += "if [ \"" + root.deviceName + "\" != \"\" ]; then dev=\"" + root.deviceName + "\"; else ";
                        cmd += "dev=$(ls /sys/class/backlight 2>/dev/null | grep -Ev 'screen|screenpad' | head -n1); if [ -z \"$dev\" ]; then dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); fi; fi; ";
                        cmd += "if [ -n \"$dev\" ]; then brightnessctl -d \"$dev\" s " + newBrightness + "% 2>/dev/null; else brightnessctl s " + newBrightness + "% 2>/dev/null || light -S " + newBrightness + " 2>/dev/null; fi";
                        setBrightness.command = ["sh", "-c", cmd];
                        setBrightness.running = true;
                    }
                    
                    onPositionChanged: {
                        if (pressed) {
                            updateValue(mouse.x);
                        }
                    }
                }
            }
            
            // Icône soleil fort (droite)
            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.9
                
                // Cercle central plus grand
                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: "white"
                    anchors.centerIn: parent
                }
                
                // Rayons (8 barres verticales)
                Repeater {
                    model: 8
                    Rectangle {
                        width: 1.5
                        height: 3.5
                        radius: 0.75
                        color: "white"
                        x: parent.width / 2 - width / 2 + Math.cos((index * 45) * Math.PI / 180) * 7.5
                        y: parent.height / 2 - height / 2 + Math.sin((index * 45) * Math.PI / 180) * 7.5
                    }
                }
            }
        }
    }
    
    // Process pour définir la luminosité
    Process {
        id: setBrightness
        running: false
    }
}

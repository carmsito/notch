import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io

Rectangle {
    id: fansControl
    width: 160
    height: 235
    radius: 12
    color: "#50404040"
    border.color: "#30FFFFFF"
    border.width: 1
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        // Fan Icon
        Item {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            Layout.alignment: Qt.AlignHCenter

            Canvas {
                id: fanCanvas
                anchors.fill: parent
                
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    
                    var centerX = width / 2;
                    var centerY = height / 2;
                    var radius = Math.min(width, height) / 2;
                    var hubRadius = radius * 0.22;
                    
                    // Draw blades
                    ctx.fillStyle = "#DDDDDD";
                    
                    for (var i = 0; i < 4; i++) {
                        ctx.save();
                        ctx.translate(centerX, centerY);
                        ctx.rotate(i * Math.PI / 2);
                        
                        ctx.beginPath();
                        // Start from hub edge
                        ctx.moveTo(hubRadius * 0.9, hubRadius * 0.4);
                        
                        // Right edge - gentle convex curve
                        ctx.bezierCurveTo(
                            radius * 0.45, hubRadius * 0.3,
                            radius * 0.75, -radius * 0.1,
                            radius * 0.85, -radius * 0.55
                        );
                        
                        // Rounded tip
                        ctx.bezierCurveTo(
                            radius * 0.88, -radius * 0.7,
                            radius * 0.8, -radius * 0.85,
                            radius * 0.6, -radius * 0.9
                        );
                        
                        // Left edge - deep concave curve
                        ctx.bezierCurveTo(
                            radius * 0.3, -radius * 0.8,
                            radius * 0.15, -radius * 0.5,
                            hubRadius * 0.4, -hubRadius * 0.9
                        );
                        
                        ctx.closePath();
                        ctx.fill();
                        ctx.restore();
                    }
                    
                    // Draw center hub (covers the blade roots)
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, hubRadius, 0, 2 * Math.PI);
                    ctx.fillStyle = "#502a2a2a";
                    ctx.fill();
                    
                    // Draw hub ring
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, hubRadius, 0, 2 * Math.PI);
                    ctx.strokeStyle = "#DDDDDD";
                    ctx.lineWidth = 5;
                    ctx.stroke();
                    
                    // Draw center filled circle
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, hubRadius * 0.5, 0, 2 * Math.PI);
                    ctx.fillStyle = "#DDDDDD";
                    ctx.fill();
                }
            }
        }
        
        // FANS Label
        Text {
            text: "FANS"
            font.pixelSize: 18
            font.bold: true
            color: "#FFFFFF"
            Layout.alignment: Qt.AlignHCenter
        }
        
        Item {
            Layout.fillHeight: true
        }
        
        // Fan Mode Button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignHCenter
            radius: 20
            color: "#502a2a2a"
            border.color: "#30FFFFFF"
            border.width: 1
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cycleProfile()
            }
            
            Text {
                anchors.centerIn: parent
                text: fanProfile
                font.pixelSize: 12
                font.bold: true
                color: fanProfile === "Performance" ? "#FF5555" : (fanProfile === "Quiet" ? "#55FF55" : "#5DADE2")
            }
        }
    }
    
    property string fanProfile: "Checking..."

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!fanProfileProcess.running) fanProfileProcess.running = true
        }
    }

    Component.onCompleted: {
        if (!fanProfileProcess.running) fanProfileProcess.running = true
    }

    // ========= PROCESS FAN PROFILE =========
    Process {
        id: fanProfileProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/get_fan_profile.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = (text || "").trim()
                if (output.length > 0) fanProfile = output
            }
        }
    }

    Process {
        id: setFanProfileProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/set_fan_profile.sh", "Balanced"]
        
        stdout: StdioCollector {
            onStreamFinished: console.log("Set Profile Output: " + text)
        }
    }

    function cycleProfile() {
        var next = "Balanced"
        if (fanProfile === "Balanced") next = "Performance"
        else if (fanProfile === "Performance") next = "Quiet"
        else if (fanProfile === "Quiet") next = "Balanced"
        
        fanProfile = next // Optimistic update
        setFanProfileProcess.command = ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/set_fan_profile.sh", next]
        setFanProfileProcess.running = true
    }
}

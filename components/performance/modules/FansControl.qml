import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: fansControl
    width: 160
    height: 235
    radius: 12
    color: "#502a2a2a"
    border.color: "#30FFFFFF"
    border.width: 1
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        // Fan Icon Circle
        Rectangle {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            Layout.alignment: Qt.AlignHCenter
            radius: 40
            color: "transparent"
            border.color: "#4A4A4A"
            border.width: 3
            
            // Fan Icon (simple circle representation)
            Rectangle {
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: 20
                color: "transparent"
                border.color: "#6A6A6A"
                border.width: 2
                
                // Center dot
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: "#8A8A8A"
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
        
        // Fan Mode Selector
        Rectangle {
            Layout.preferredWidth: parent.width - 40
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignHCenter
            radius: 12
            color: "#2A2A2A"
            border.color: "#4A4A4A"
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                
                // Left Arrow
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 6
                    color: leftArrowMouse.containsMouse ? "#3A3A3A" : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "◄"
                        font.pixelSize: 16
                        color: "#AAAAAA"
                    }
                    
                    MouseArea {
                        id: leftArrowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: changeFanMode(-1)
                    }
                }
                
                // Mode Text
                Text {
                    text: getCurrentMode()
                    font.pixelSize: 14
                    font.bold: true
                    color: "#FFFFFF"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                
                // Right Arrow
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 6
                    color: rightArrowMouse.containsMouse ? "#3A3A3A" : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "►"
                        font.pixelSize: 16
                        color: "#AAAAAA"
                    }
                    
                    MouseArea {
                        id: rightArrowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: changeFanMode(1)
                    }
                }
            }
        }
    }
    
    property int currentModeIndex: 1
    property var modes: ["Silent", "Balanced", "Performance"]
    
    function getCurrentMode() {
        return modes[currentModeIndex]
    }
    
    function changeFanMode(direction) {
        currentModeIndex = (currentModeIndex + direction + modes.length) % modes.length
        console.log("Fan mode changed to:", getCurrentMode())
    }
}

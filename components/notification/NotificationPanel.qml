import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "modules"

Rectangle {
    id: root
    color: "transparent" // Transparent background as it is inside another container
    radius: 12
    // border.color: "#30FFFFFF"
    // border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        anchors.topMargin: 0 // Start slightly higher
        spacing: 15

        // Header / Tabs
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 0
            
            // Segmented Control style
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#30FFFFFF"
                radius: 8
                
                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    
                    Repeater {
                        model: ["Today", "Notifications"]
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 2
                            radius: 6
                            color: stackLayout.currentIndex === index ? "#606060" : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onEntered: cursorShape = Qt.PointingHandCursor
                                onExited: cursorShape = Qt.ArrowCursor
                                onClicked: stackLayout.currentIndex = index
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
        }

        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 1 // Default to Notifications

            TodayView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            NotificationList {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}

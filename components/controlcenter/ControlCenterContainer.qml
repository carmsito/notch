import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../notification"
import "modules"

Item {
    id: root
    
    property int currentPage: 0
    property var pages: ["Wi-Fi", "Test", "Notifications"]
    
    signal closeRequested()
    
    // Header avec indicateurs de page
    Rectangle {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 50
        color: "#1C1C1E"
        
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            
            Repeater {
                model: root.pages
                
                Rectangle {
                    width: root.currentPage === index ? 24 : 8
                    height: 8
                    radius: 4
                    color: root.currentPage === index ? "#0A84FF" : "#30FFFFFF"
                    
                    Behavior on width {
                        NumberAnimation { duration: 200 }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: swipeView.currentIndex = index
                    }
                }
            }
        }
    }
    
    // Conteneur avec SwipeView
    SwipeView {
        id: swipeView
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        
        currentIndex: root.currentPage
        
        onCurrentIndexChanged: {
            root.currentPage = currentIndex
        }
        
        // Page 1: Wi-Fi
        Item {
            WifiNetworksList {
                id: wifiNetworks
                anchors.fill: parent
                
                onClose: {
                    root.closeRequested()
                }
            }
        }
        
        // Page 2: Test
        Item {
            Rectangle {
                anchors.fill: parent
                color: "#1C1C1E"
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20
                    
                    Text {
                        text: "Page de Test"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#FFFFFF"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Rectangle {
                        width: 200
                        height: 100
                        color: "#2C2C2E"
                        radius: 12
                        Layout.alignment: Qt.AlignHCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Module de test\nPour démonstration"
                            font.pixelSize: 14
                            color: "#8E8E93"
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    Text {
                        text: "Swipe pour changer de page →"
                        font.pixelSize: 12
                        color: "#8E8E93"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }
                }
            }
        }

        // Page 3: Notifications
        Item {
            NotificationPanel {
                anchors.fill: parent
            }
        }
    }
    
    // Indicateurs de swipe sur les côtés
    Rectangle {
        anchors {
            left: parent.left
            top: header.bottom
            bottom: parent.bottom
        }
        width: 2
        color: "#30FFFFFF"
        visible: root.currentPage > 0
        
        Rectangle {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 20
            height: 40
            radius: 10
            color: "#400A84FF"
        }
    }
    
    Rectangle {
        anchors {
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
        }
        width: 2
        color: "#30FFFFFF"
        visible: root.currentPage < root.pages.length - 1
        
        Rectangle {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 20
            height: 40
            radius: 10
            color: "#400A84FF"
        }
    }
}

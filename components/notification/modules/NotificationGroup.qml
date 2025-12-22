import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    height: count > 1 ? 145 : 90 // Adjust based on content + stack offset
    
    property string appName
    property int count
    property string time
    property string preview
    
    // Stack Card 2 (Bottom)
    Rectangle {
        id: stack2
        visible: root.count > 2
        width: parent.width - 30
        height: 80
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 24
        color: "#E6404040"
        radius: 12
        z: 0
    }

    DropShadow {
        anchors.fill: stack2
        source: stack2
        verticalOffset: 4
        radius: 12
        samples: 16
        color: "#80000000"
        visible: stack2.visible
        z: -1
    }
    
    // Stack Card 1 (Middle)
    Rectangle {
        id: stack1
        visible: root.count > 1
        width: parent.width - 15
        height: 80
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        color: "#E6404040"
        radius: 12
        z: 1
    }

    DropShadow {
        anchors.fill: stack1
        source: stack1
        verticalOffset: 4
        radius: 12
        samples: 16
        color: "#80000000"
        visible: stack1.visible
        z: 0
    }

    // Main Card
    Rectangle {
        id: mainCard
        width: parent.width
        height: 80
        anchors.top: parent.top
        color: "#E6404040"
        radius: 12
        z: 2
    }

    DropShadow {
        anchors.fill: mainCard
        source: mainCard
        verticalOffset: 4
        radius: 12
        samples: 16
        color: "#80000000"
        z: 1
    }
        
    ColumnLayout {
        parent: mainCard
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 8
        spacing: 4
            
            // Header: Icon + App Name + Time
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // Icon placeholder
                Rectangle {
                    width: 20
                    height: 20
                    color: "#FF3B30" // Example color
                    radius: 5
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.appName.charAt(0)
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                
                Text {
                    text: root.appName.toUpperCase()
                    color: "#80FFFFFF"
                    font.pixelSize: 11
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: root.time
                    color: "#80FFFFFF"
                    font.pixelSize: 11
                }
            }
            
            // Content
            Text {
                text: root.appName // Title (often same as app name or specific title)
                color: "white"
                font.bold: true
                font.pixelSize: 13
                Layout.topMargin: 4
            }
            
            Text {
                text: root.count > 1 ? root.count + " Notifications" : root.preview
                color: "white"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    
    // "X more notifications" pill
    Rectangle {
        visible: root.count > 1
        anchors.top: mainCard.bottom
        anchors.topMargin: 34 // Space below the stack
        anchors.horizontalCenter: parent.horizontalCenter
        
        width: 140
        height: 24
        radius: 12
        color: "#40FFFFFF" // Lighter
        z: 3
        
        Text {
            anchors.centerIn: parent
            text: (root.count - 1) + " more notifications"
            color: "black"
            font.pixelSize: 11
        }
    }
}

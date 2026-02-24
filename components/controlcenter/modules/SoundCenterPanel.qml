import QtQuick 2.15
import "."

Item {
    id: root
    width: 430
    property bool pollingEnabled: true

    signal close()
    signal interactionStarted()

    Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 15
        spacing: 8

        Row {
            width: parent.width
            height: 32
            spacing: 8

            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: backButtonMouse.containsMouse ? "#30FFFFFF" : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    text: "‹"
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                }

                MouseArea {
                    id: backButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.close()
                    }
                }
            }

            Text {
                text: "Sound"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#18FFFFFF"
        }
    }

    SoundCenterModule {
        id: soundModule
        anchors.top: headerColumn.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: 430
        height: parent.height - headerColumn.height - 16
        pollingEnabled: root.pollingEnabled
        onInteractionStarted: {
            root.interactionStarted()
        }
    }
}

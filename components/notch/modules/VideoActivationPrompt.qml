import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: 360
    height: 56
    radius: 14
    color: "#E62A2A2A"
    border.color: "#40FFFFFF"
    border.width: 1

    property string title: "Activer Video Island ?"
    property string subtitle: "Affiche la video en cours dans la barre"

    signal accepted()
    signal dismissed()

    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Column {
            width: 200
            spacing: 4

            Text {
                text: root.title
                color: "white"
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                text: root.subtitle
                color: "#CFFFFFFF"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Item { width: 10 }

        Button {
            text: "Activer"
            onClicked: root.accepted()
        }

        Button {
            text: "Plus tard"
            onClicked: root.dismissed()
        }
    }
}

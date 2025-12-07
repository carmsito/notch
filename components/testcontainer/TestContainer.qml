import QtQuick 2.15
import QtQuick.Layouts 1.15

// Conteneur de test simple
Item {
    id: testContainer
    width: 450
    height: 200
    
    Column {
        anchors.fill: parent
        spacing: 15
        
        Text {
            text: "🧪 Test Container"
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
        
        Rectangle {
            width: parent.width
            height: 120
            radius: 12
            color: "#20FFFFFF"
            border.color: "#30FFFFFF"
            border.width: 1
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "Conteneur de Test"
                    font.pixelSize: 16
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "Ce conteneur est utilisé pour les tests"
                    font.pixelSize: 12
                    color: "#aaaaaa"
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 30
                    radius: 6
                    color: testButtonMouseArea.containsMouse ? "#40FFFFFF" : "#30FFFFFF"
                    Layout.alignment: Qt.AlignHCenter
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Bouton de Test"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: testButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("Test button clicked!")
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 10
    
    Text {
        text: new Date().toLocaleDateString(Qt.locale(), "dddd, d MMMM")
        color: "white"
        font.pixelSize: 24
        font.bold: true
        Layout.alignment: Qt.AlignLeft
    }
    
    // Placeholder for widgets
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        color: "#50404040"
        radius: 10
        
        Text {
            anchors.centerIn: parent
            text: "No Events Today"
            color: "#80FFFFFF"
        }
    }
    
    Item { Layout.fillHeight: true } // Spacer
}

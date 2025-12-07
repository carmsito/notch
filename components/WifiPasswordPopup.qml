import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import Quickshell
import Quickshell.Io

Window {
    id: popup
    width: 350
    height: 200
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    color: "transparent"
    visible: false
    
    property string ssid: ""
    property string security: ""
    
    signal connectRequested(string password)
    signal cancelled()
    
    onVisibleChanged: {
        if (visible) {
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }
    
    Rectangle {
        anchors.fill: parent
        anchors.margins: 20
        color: "#E0000000"
        radius: 12
        border.color: "#30FFFFFF"
        border.width: 1
        
        Column {
            anchors.centerIn: parent
            spacing: 15
            width: parent.width - 40
            
            Text {
                text: "Connect to Wi-Fi"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
            
            Text {
                text: ssid
                color: "#CCFFFFFF"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                elide: Text.ElideMiddle
            }
            
            Rectangle {
                width: parent.width
                height: 38
                color: "#30FFFFFF"
                radius: 6
                border.color: passwordField.activeFocus ? "#0A84FF" : "transparent"
                border.width: 2
                
                TextField {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "white"
                    placeholderText: "Password"
                    echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                    font.pixelSize: 13
                    selectByMouse: true
                    focus: true
                    
                    background: Rectangle {
                        color: "transparent"
                    }
                    
                    Keys.onReturnPressed: connectButton.clicked()
                    Keys.onEnterPressed: connectButton.clicked()
                    Keys.onEscapePressed: popup.cancelled()
                }
            }
            
            Row {
                spacing: 6
                
                CheckBox {
                    id: showPasswordCheckbox
                    text: "Show password"
                    
                    contentItem: Text {
                        text: showPasswordCheckbox.text
                        color: "white"
                        font.pixelSize: 11
                        leftPadding: showPasswordCheckbox.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    indicator: Rectangle {
                        width: 16
                        height: 16
                        radius: 3
                        color: showPasswordCheckbox.checked ? "#0A84FF" : "#30FFFFFF"
                        border.color: "#60FFFFFF"
                        border.width: 1
                        
                        Text {
                            visible: showPasswordCheckbox.checked
                            text: "✓"
                            color: "white"
                            font.pixelSize: 12
                            anchors.centerIn: parent
                        }
                    }
                }
            }
            
            Row {
                spacing: 10
                width: parent.width
                
                Button {
                    width: (parent.width - 10) / 2
                    height: 32
                    
                    background: Rectangle {
                        color: parent.hovered ? "#60606060" : "#40606060"
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: "Cancel"
                        color: "white"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: popup.cancelled()
                }
                
                Button {
                    id: connectButton
                    width: (parent.width - 10) / 2
                    height: 32
                    
                    background: Rectangle {
                        color: parent.hovered ? "#1A8FFF" : "#0A84FF"
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: "Connect"
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        popup.connectRequested(passwordField.text)
                        popup.visible = false
                    }
                }
            }
        }
    }
    
    // Fermer en cliquant à l'extérieur
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: popup.cancelled()
    }
}

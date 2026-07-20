import QtQuick 2.15
import QtWebEngine 1.10

Item {
    id: root
    property string url: ""

    WebEngineView {
        anchors.fill: parent
        url: root.url
        settings.playbackRequiresUserGesture: false
        settings.javascriptEnabled: true
    }
}

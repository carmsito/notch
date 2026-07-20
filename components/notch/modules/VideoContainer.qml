import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property bool compact: false
    property bool featureEnabled: false
    property bool previewActive: false
    property bool embedEnabled: false
    property bool embedWarningVisible: false

    property string title: ""
    property string artist: ""
    property string playbackStatus: "Stopped"
    property double position: 0
    property double length: 0
    property string playerName: ""
    property string trackId: ""

    property string url: ""
    property double urlTime: 0
    property bool hasUrl: url !== ""

    signal playPauseRequested()
    signal previewRequested()
    signal previewClosed()
    signal activateRequested()

    property string embedUrl: buildEmbedUrl(url, urlTime)

    function buildEmbedUrl(rawUrl, timeSec) {
        if (!rawUrl || rawUrl === "") {
            return ""
        }
        var id = youtubeIdFromUrl(rawUrl)
        if (!id) {
            return ""
        }
        var start = Math.max(0, Math.floor(timeSec || 0))
        return "https://www.youtube.com/embed/" + id +
               "?start=" + start +
               "&autoplay=1&mute=1&playsinline=1"
    }

    function youtubeIdFromUrl(rawUrl) {
        var match = /[?&]v=([^&]+)/.exec(rawUrl)
        if (match && match[1]) {
            return match[1]
        }
        match = /youtu\.be\/([^?&]+)/.exec(rawUrl)
        if (match && match[1]) {
            return match[1]
        }
        match = /youtube\.com\/embed\/([^?&]+)/.exec(rawUrl)
        if (match && match[1]) {
            return match[1]
        }
        return ""
    }

    Rectangle {
        anchors.fill: parent
        radius: compact ? 12 : 14
        color: "#1F1F1F"
        border.color: "#30FFFFFF"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: compact ? 6 : 12
        spacing: compact ? 6 : 10
        visible: !previewActive

        Row {
            spacing: 8
            visible: !previewActive

            Rectangle {
                width: compact ? 48 : 72
                height: compact ? 27 : 40
                radius: 6
                color: "#303030"
                border.color: "#40FFFFFF"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "VIDEO"
                    color: "#CFFFFFFF"
                    font.pixelSize: compact ? 8 : 10
                }
            }

            Column {
                spacing: 4

                Text {
                    text: title !== "" ? title : "Lecture video"
                    color: "white"
                    font.pixelSize: compact ? 11 : 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: compact ? 180 : 300
                }

                Text {
                    text: playbackStatus
                    color: "#CFFFFFFF"
                    font.pixelSize: compact ? 9 : 11
                }
            }
        }

        Rectangle {
            height: compact ? 4 : 6
            radius: height / 2
            color: "#2B2B2B"
            visible: !previewActive && !compact
            width: parent.width

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: length > 0 ? parent.width * Math.min(1, position / length) : 0
                color: "#FFFFFF"
            }
        }

        Row {
            spacing: 8
            visible: !previewActive && !compact

            Button {
                text: playbackStatus === "Playing" ? "Pause" : "Play"
                onClicked: root.playPauseRequested()
                enabled: root.featureEnabled
            }

            Button {
                text: "Play in Island"
                onClicked: {
                    if (!root.embedEnabled) {
                        root.embedWarningVisible = true
                        return
                    }
                    root.previewRequested()
                }
                enabled: root.featureEnabled && hasUrl
            }
        }

        Row {
            spacing: 8
            visible: !root.featureEnabled && !compact

            Button {
                text: "Activer"
                onClicked: root.activateRequested()
            }

            Text {
                text: "Active Video Island pour afficher la video ici."
                color: "#AFFFFFFF"
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            text: root.featureEnabled && !hasUrl ? "URL manquante (extension non connectee)." : ""
            color: "#AFFFFFFF"
            font.pixelSize: 11
            visible: root.featureEnabled && !hasUrl && !compact
        }

        Text {
            text: "Embed desactive (QtWebEngine instable sur ta config)."
            color: "#AFFFFFFF"
            font.pixelSize: 11
            visible: root.embedWarningVisible && !compact
        }
    }

    Loader {
        id: previewLoader
        anchors.fill: parent
        active: previewActive && embedUrl !== "" && embedEnabled
        source: "VideoWebView.qml"

        onLoaded: {
            item.url = embedUrl
        }
    }

    Button {
        text: "Fermer"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        visible: previewActive
        onClicked: root.previewClosed()
    }

    Text {
        text: previewActive && embedUrl === "" ? "Embed indisponible pour cette URL." : ""
        color: "#AFFFFFFF"
        font.pixelSize: compact ? 9 : 11
        anchors.centerIn: parent
        visible: previewActive && embedUrl === ""
    }

    Timer {
        interval: 3000
        repeat: false
        running: root.embedWarningVisible
        onTriggered: root.embedWarningVisible = false
    }
}

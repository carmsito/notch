import QtQuick 2.15
import Quickshell.Io

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property bool active: true
    property var players: []
    property var activePlayer: ({})

    property string playerName: activePlayer && activePlayer.name ? activePlayer.name : ""
    property string title: activePlayer && activePlayer.title ? activePlayer.title : ""
    property string artist: activePlayer && activePlayer.artist ? activePlayer.artist : ""
    property string playbackStatus: activePlayer && activePlayer.status ? activePlayer.status : "Stopped"
    property double position: activePlayer && activePlayer.position ? activePlayer.position : 0
    property double length: activePlayer && activePlayer.length ? activePlayer.length : 0
    property string trackId: activePlayer && activePlayer.trackId ? activePlayer.trackId : ""
    property string url: activePlayer && activePlayer.url ? activePlayer.url : ""

    property bool hasPlayer: players && players.length > 0
    property bool isPlaying: playbackStatus === "Playing"
    property bool isPaused: playbackStatus === "Paused"

    property bool isBrowserPlayer: {
        var name = (playerName || "").toLowerCase()
        return name.indexOf("brave") >= 0 ||
               name.indexOf("firefox") >= 0 ||
               name.indexOf("chrome") >= 0 ||
               name.indexOf("chromium") >= 0
    }

    signal updated()

    function handleLine(line) {
        if (!line || line.trim() === "") {
            return
        }
        try {
            var data = JSON.parse(line)
            players = data.players || []
            activePlayer = data.active || ({})
            updated()
        } catch (error) {
            // Ignore malformed lines
        }
    }

    Process {
        id: mprisProc
        running: root.active
        command: ["python3", "/home/emmanuel/dotfiles/quickshell/components/notch/modules/mpris_watch.py"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                root.handleLine(data)
            }
        }
    }
}

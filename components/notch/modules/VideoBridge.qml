import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property string statePath: "/home/emmanuel/.local/state/quickshell/video_island_payload.json"
    property string fallbackPath: Quickshell.statePath("video_island_payload.json")
    property string url: ""
    property double time: 0
    property string title: ""
    property double ts: 0
    property int staleAfterMs: 600000

    property bool isStale: ts > 0 && (Date.now() - ts) > staleAfterMs
    property bool hasData: url !== "" && !isStale

    function normalizeTs(value) {
        var t = value || 0
        if (t > 0 && t < 1000000000000) {
            t = t * 1000
        }
        return t
    }

    function parsePayload(raw) {
        if (!raw || raw.trim() === "") {
            return null
        }
        try {
            var data = JSON.parse(raw)
            return {
                url: data.url || "",
                time: data.time || 0,
                title: data.title || "",
                ts: normalizeTs(data.ts || Date.now())
            }
        } catch (error) {
            return null
        }
    }

    function applyPayload(data) {
        if (!data || !data.url) {
            return
        }
        var shouldApply = ts === 0 || (data.ts && data.ts >= ts)
        if (shouldApply) {
            url = data.url
            time = data.time
            title = data.title
            ts = data.ts
        }
    }

    function load() {
        var primary = parsePayload(stateFile.text())
        var fallback = parsePayload(fallbackFile.text())

        if (!primary && !fallback) {
            url = ""
            time = 0
            title = ""
            ts = 0
            return
        }

        if (primary && fallback) {
            if (fallback.ts > primary.ts) {
                applyPayload(fallback)
            } else {
                applyPayload(primary)
            }
        } else if (primary) {
            applyPayload(primary)
        } else if (fallback) {
            applyPayload(fallback)
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.load()
        onFileChanged: root.load()
    }

    FileView {
        id: fallbackFile
        path: root.fallbackPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.load()
        onFileChanged: root.load()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.load()
    }

    Component.onCompleted: root.load()
}

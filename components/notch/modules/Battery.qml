// components/Battery.qml
import QtQml
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int batteryLevel: 0
    property bool isCharging: false
    property bool pollingEnabled: true
    property int pollIntervalMs: 15000

    function refreshLevel() {
        var raw = batteryLevelFile.text()
        var next = parseInt((raw || "").trim())
        if (!isNaN(next)) {
            batteryLevel = Math.max(0, Math.min(next, 100))
        }
    }

    function refreshStatus() {
        var raw = batteryStatusFile.text()
        isCharging = (raw || "").trim() === "Charging"
    }

    function applyUpowerOutput(text) {
        var raw = text || ""
        var pctMatch = raw.match(/percentage:\s*([0-9]+(?:\.[0-9]+)?)%/i)
        var stateMatch = raw.match(/state:\s*([A-Za-z-]+)/i)
        var updated = false

        if (pctMatch && pctMatch[1] !== undefined) {
            var next = Math.round(parseFloat(pctMatch[1]))
            if (!isNaN(next)) {
                batteryLevel = Math.max(0, Math.min(next, 100))
                updated = true
            }
        }

        if (stateMatch && stateMatch[1] !== undefined) {
            var state = (stateMatch[1] || "").toLowerCase()
            isCharging = state === "charging" || state === "fully-charged"
            updated = true
        }

        return updated
    }

    function refreshFromSysfs() {
        refreshLevel()
        refreshStatus()
    }

    function refreshAll() {
        if (!pollingEnabled) {
            return
        }

        if (!upowerQuery.running) {
            upowerQuery.running = true
        }
    }

    FileView {
        id: batteryLevelFile
        path: "/sys/class/power_supply/BAT0/capacity"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.refreshLevel()
        onFileChanged: root.refreshLevel()
    }

    FileView {
        id: batteryStatusFile
        path: "/sys/class/power_supply/BAT0/status"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.refreshFromSysfs()
        onFileChanged: root.refreshFromSysfs()
    }

    Process {
        id: upowerQuery
        running: false
        command: ["sh", "-c",
                  "dev=$(upower -e 2>/dev/null | grep -m1 battery); " +
                  "if [ -n \"$dev\" ]; then upower -i \"$dev\" 2>/dev/null; fi"
                  ]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.applyUpowerOutput(this.text || "")) {
                    root.refreshFromSysfs()
                }
            }
        }

        onExited: {
            running = false
        }
    }

    // /sys pseudo-files are not always notifying changes reliably.
    // Polling keeps the displayed battery value in sync over time.
    Timer {
        interval: root.pollIntervalMs
        repeat: true
        running: root.pollingEnabled
        onTriggered: root.refreshAll()
    }

    onPollingEnabledChanged: {
        if (pollingEnabled) {
            refreshAll()
        }
    }

    Component.onCompleted: {
        refreshFromSysfs()
        refreshAll()
    }
}

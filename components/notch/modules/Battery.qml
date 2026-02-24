// components/Battery.qml
import QtQml
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int batteryLevel: 0
    property bool isCharging: false
    property bool pollingEnabled: true

    function refreshLevel() {
        var raw = batteryLevelFile.text()
        var next = parseInt((raw || "").trim())
        if (!isNaN(next)) {
            batteryLevel = next
        }
    }

    function refreshStatus() {
        var raw = batteryStatusFile.text()
        isCharging = (raw || "").trim() === "Charging"
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
        onLoaded: root.refreshStatus()
        onFileChanged: root.refreshStatus()
    }

    Component.onCompleted: {
        refreshLevel()
        refreshStatus()
    }
}

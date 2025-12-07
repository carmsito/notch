// components/Battery.qml
import QtQuick 2.15    // <--- AJOUTE CETTE LIGNE OBLIGATOIRE POUR LE TIMER
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int batteryLevel: 0
    property bool isCharging: false

    // 1. Processus pour lire le niveau
    Process {
        id: batteryLevelProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: SplitParser {
            onRead: data => root.batteryLevel = parseInt(data.trim())
        }
    }

    // 2. Processus pour lire le statut (Charging/Discharging)
    Process {
        id: batteryStatusProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: SplitParser {
            onRead: data => root.isCharging = (data.trim() === "Charging")
        }
    }

    // 3. Le Timer qui déclenche les mises à jour
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batteryLevelProc.running = true
            batteryStatusProc.running = true
        }
    }
}
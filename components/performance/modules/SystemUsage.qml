import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io

Item {
    id: systemUsage
    width: 270
    height: 235

    // Initialisation
    property real ramUsed: 0.0
    property real ramTotal: 0.0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int cpuUsage: 0
    property int gpuUsage: 0

    // Timer de mise à jour
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateSystemStats()
    }

    Component.onCompleted: updateSystemStats()

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ========= TOP : TEMPERATURES =========
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // CPU Temperature
            Rectangle {
                Layout.preferredWidth: 135
                Layout.preferredHeight: 80
                radius: 10
                color: "#50404040"
                border.color: "#30FFFFFF"
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "CPU Temperature"
                        font.pixelSize: 10
                        color: "#AAAAAA"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Canvas {
                        id: cpuTempCanvas
                        Layout.preferredWidth: 55
                        Layout.preferredHeight: 55
                        Layout.alignment: Qt.AlignHCenter

                        property real percentage: Math.max(0, Math.min(cpuTemp, 100))

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var centerX = width / 2
                            var centerY = height / 2
                            var radius = Math.min(width, height) / 2 - 4

                            // Background Circle
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                            ctx.strokeStyle = "#30FFFFFF"
                            ctx.lineWidth = 5
                            ctx.stroke()

                            // Value Arc
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius,
                                    -Math.PI / 2,
                                    -Math.PI / 2 + (percentage / 100 * 2 * Math.PI))
                            ctx.strokeStyle = "#5DADE2"
                            ctx.lineWidth = 5
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cpuTemp > 0 ? cpuTemp + "°C" : "--"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        onPercentageChanged: requestPaint()
                    }
                }
            }

            // GPU Temperature
            Rectangle {
                Layout.preferredWidth: 135
                Layout.preferredHeight: 80
                radius: 10
                color: "#50404040"
                border.color: "#30FFFFFF"
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "GPU Temperature"
                        font.pixelSize: 10
                        color: "#AAAAAA"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Canvas {
                        id: gpuTempCanvas
                        Layout.preferredWidth: 55
                        Layout.preferredHeight: 55
                        Layout.alignment: Qt.AlignHCenter

                        property real percentage: Math.max(0, Math.min(gpuTemp, 100))

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var centerX = width / 2
                            var centerY = height / 2
                            var radius = Math.min(width, height) / 2 - 4

                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                            ctx.strokeStyle = "#30FFFFFF"
                            ctx.lineWidth = 5
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius,
                                    -Math.PI / 2,
                                    -Math.PI / 2 + (percentage / 100 * 2 * Math.PI))
                            ctx.strokeStyle = "#5DADE2"
                            ctx.lineWidth = 5
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: gpuTemp > 0 ? gpuTemp + "°C" : "--"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        onPercentageChanged: requestPaint()
                    }
                }
            }
        }

        // ========= MIDDLE : RAM =========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 65
            radius: 10
            color: "#50404040"
            border.color: "#30FFFFFF"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "RAM Usage"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#FFFFFF"
                    }

                    Text {
                        text: (ramTotal > 0
                               ? ramUsed.toFixed(1) + " GB / " + ramTotal.toFixed(1) + " GB"
                               : "Checking...")
                        font.pixelSize: 9
                        color: "#AAAAAA"
                    }
                }

                Canvas {
                    id: ramCanvas
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40

                    property real percentage: ramTotal > 0 ? (ramUsed / ramTotal) * 100 : 0

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var centerX = width / 2
                        var centerY = height / 2
                        var radius = Math.min(width, height) / 2 - 3

                        ctx.beginPath()
                        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                        ctx.strokeStyle = "#30FFFFFF"
                        ctx.lineWidth = 4
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.arc(centerX, centerY, radius,
                                -Math.PI / 2,
                                -Math.PI / 2 + (percentage / 100 * 2 * Math.PI))
                        ctx.strokeStyle = "#5DADE2"
                        ctx.lineWidth = 4
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ramTotal > 0
                              ? (ramUsed / ramTotal * 100).toFixed(0) + "%"
                              : "--"
                        font.pixelSize: 9
                        font.bold: true
                        color: "#FFFFFF"
                    }

                    onPercentageChanged: requestPaint()
                }
            }
        }

        // ========= BOTTOM : GLOBAL USAGE =========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: 10
            color: "#50404040"
            border.color: "#30FFFFFF"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: "Global Usage"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#FFFFFF"
                }

                // CPU Usage
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    
                    Text {
                        text: "CPU"
                        font.pixelSize: 10
                        color: "#AAAAAA"
                        Layout.preferredWidth: 25
                    }

                    Row {
                        spacing: 2
                        Layout.fillWidth: true
                        Repeater {
                            model: 20
                            Rectangle {
                                width: (parent.width / 20) - 2
                                height: 10
                                color: index < (cpuUsage / 5) ? "#5DADE2" : "#30FFFFFF"
                                radius: 2
                            }
                        }
                    }

                    Text {
                        text: cpuUsage + "%"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#FFFFFF"
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // GPU Usage
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "GPU"
                        font.pixelSize: 10
                        color: "#AAAAAA"
                        Layout.preferredWidth: 25
                    }

                    Row {
                        spacing: 2
                        Layout.fillWidth: true
                        Repeater {
                            model: 20
                            Rectangle {
                                width: (parent.width / 20) - 2
                                height: 10
                                color: index < (gpuUsage / 5) ? "#5DADE2" : "#30FFFFFF"
                                radius: 2
                            }
                        }
                    }

                    Text {
                        text: gpuUsage + "%"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#FFFFFF"
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // ========= PROCESS RAM =========
    Process {
        id: ramProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/get_ram_usage.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("RAM Stream Finished. Text: '" + text + "'")
                var output = (text || "").trim()
                var parts = output.split(" ")
                if (parts.length >= 2) {
                    ramUsed = parseFloat(parts[0])
                    ramTotal = parseFloat(parts[1])
                }
            }
        }
        onExited: console.log("RAM Process Exited with code: " + exitCode)
    }

    // ========= PROCESS CPU TEMP =========
    Process {
        id: cpuTempProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/get_cpu_temp.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("CPU Temp Stream Finished. Text: '" + text + "'")
                var output = (text || "").trim()
                var temp = parseFloat(output)
                if (!isNaN(temp) && temp > 0) cpuTemp = Math.round(temp)
            }
        }
    }

    // ========= PROCESS GPU TEMP =========
    Process {
        id: gpuTempProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/get_gpu_temp.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("GPU Temp Stream Finished. Text: '" + text + "'")
                var output = (text || "").trim()
                var temp = parseFloat(output)
                if (!isNaN(temp) && temp > 0) gpuTemp = Math.round(temp)
            }
        }
    }

    // ========= PROCESS CPU USAGE =========
    Process {
        id: cpuUsageProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/get_cpu_usage.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("CPU Usage Stream Finished. Text: '" + text + "'")
                var output = (text || "").trim()
                var usage = parseFloat(output)
                if (!isNaN(usage)) cpuUsage = Math.round(Math.max(0, Math.min(usage, 100)))
            }
        }
    }

    // ========= PROCESS GPU USAGE =========
    Process {
        id: gpuUsageProcess
        command: ["/usr/bin/bash", "/home/emmanuel/.config/quickshell/components/performance/scripts/get_gpu_usage.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("GPU Usage Stream Finished. Text: '" + text + "'")
                var output = (text || "").trim()
                var usage = parseFloat(output)
                if (!isNaN(usage)) gpuUsage = Math.round(Math.max(0, Math.min(usage, 100)))
            }
        }
    }

    // ========= FONCTION DE RAFRAICHISSEMENT =========
    function updateSystemStats() {
        if (!ramProcess.running) ramProcess.running = true
        if (!cpuTempProcess.running) cpuTempProcess.running = true
        if (!gpuTempProcess.running) gpuTempProcess.running = true
        if (!cpuUsageProcess.running) cpuUsageProcess.running = true
        if (!gpuUsageProcess.running) gpuUsageProcess.running = true
    }
}
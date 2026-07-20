import QtQuick 2.15
import QtQuick.Controls 2.15
import Quickshell.Io

Rectangle {
    id: root
    height: 230
    radius: 12

    property bool isActive: false
    property string defaultSinkName: ""
    property string selectedSinkName: ""
    property var outputDevices: []
    property var appStreams: []
    property int masterVolume: 0
    property bool masterMuted: false
    property int activeSliderInteractions: 0
    property bool outputSelectorOpen: false
    property bool pollingEnabled: true

    signal interactionStarted()
    signal interactionEnded()

    color: isActive ? "#60404040" : "#50404040"
    border.color: "#30FFFFFF"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    function escapeShell(value) {
        return (value || "").replace(/'/g, "'\\''")
    }

    // Le fader "Output Volume" doit piloter le même sink virtuel que le
    // slider "Sound" (global-audio), pas le sink matériel sélectionné,
    // sinon les deux contrôles appliquent des gains indépendants et se
    // désynchronisent.
    function masterSinkResolvePrefix() {
        return "target=$(pactl list short sinks 2>/dev/null | awk '$2==\"global-audio\" {print $2; exit}'); " +
               "if [ -z \"$target\" ]; then " +
               "target=$(pactl list short sinks 2>/dev/null | awk '$2==\"global_audio\" {print $2; exit}'); " +
               "fi; "
    }

    function prettyOutputLabel(name, description) {
        var label = (description && description !== "") ? description : name
        if (!label || label === "") {
            return "Unknown output"
        }

        label = label.replace(/\s*\(.*(duplex|analog|digital).*\)\s*$/i, "")
        label = label.replace(/\s+/g, " ").trim()
        return label.length > 34 ? label.slice(0, 34) + "..." : label
    }

    function shouldIgnoreSink(name, description) {
        var sinkName = (name || "").toLowerCase()
        var sinkDescription = (description || "").toLowerCase()

        if (/\.monitor$/.test(sinkName)) {
            return true
        }

        if (sinkName.indexOf("loopback") !== -1 || sinkDescription.indexOf("loopback") !== -1) {
            return true
        }

        if (sinkName.indexOf("global-audio") !== -1 || sinkDescription.indexOf("global-audio") !== -1) {
            return true
        }

        if (sinkName.indexOf("easyeffects") !== -1 || sinkDescription.indexOf("easyeffects") !== -1) {
            return true
        }

        if (sinkDescription.indexOf("monitor of") !== -1) {
            return true
        }

        return false
    }

    function isPreferredHardwareSink(name) {
        var sinkName = (name || "").toLowerCase()
        return sinkName.indexOf("alsa_output.") === 0 || sinkName.indexOf("bluez_output.") === 0
    }

    function shouldIgnoreStream(metaText) {
        var text = (metaText || "").toLowerCase()
        return text.indexOf("loopback") !== -1 || text.indexOf("global-audio") !== -1
    }

    function prettyAppName(stream) {
        if (!stream) {
            return "Application"
        }

        var candidates = [stream.name, stream.media, stream.app, stream.binary]
        var picked = ""

        for (var i = 0; i < candidates.length; i++) {
            var candidate = (candidates[i] || "").trim()
            if (candidate === "") {
                continue
            }

            var lowered = candidate.toLowerCase()
            if (lowered === "null" || lowered === "unknown" || lowered === "pipewire") {
                continue
            }

            if (lowered.indexOf("alsa plug") !== -1 && stream.binary) {
                continue
            }

            picked = candidate
            break
        }

        if (picked === "") {
            picked = (stream.binary || "").trim()
        }

        if (picked === "") {
            picked = stream.id ? ("Application " + stream.id) : "Application"
        }

        picked = picked.replace(/\s+/g, " ").trim()
        return picked.length > 34 ? picked.slice(0, 34) + "..." : picked
    }

    function hasSink(name) {
        for (var i = 0; i < outputDevices.length; i++) {
            if (outputDevices[i].name === name) {
                return true
            }
        }
        return false
    }

    function selectedOutputLabel() {
        for (var i = 0; i < outputDevices.length; i++) {
            if (outputDevices[i].name === selectedSinkName) {
                return outputDevices[i].label
            }
        }
        if (outputDevices.length > 0) {
            return outputDevices[0].label
        }
        return "Select output device"
    }

    function syncSelectedSink() {
        var nextSink = selectedSinkName

        if (!nextSink || !hasSink(nextSink)) {
            if (defaultSinkName && hasSink(defaultSinkName)) {
                nextSink = defaultSinkName
            } else if (outputDevices.length > 0) {
                nextSink = outputDevices[0].name
            } else {
                nextSink = ""
            }
        }

        if (nextSink !== selectedSinkName) {
            selectedSinkName = nextSink
        }

        refreshMaster()
    }

    function beginSliderInteraction() {
        activeSliderInteractions += 1
        if (activeSliderInteractions === 1) {
            interactionStarted()
        }
    }

    function endSliderInteraction() {
        if (activeSliderInteractions > 0) {
            activeSliderInteractions -= 1
        }
        if (activeSliderInteractions === 0) {
            interactionEnded()
        }
    }

    function refreshMaster() {
        var fallbackSink = selectedSinkName !== "" ? selectedSinkName : defaultSinkName
        var escapedFallback = escapeShell(fallbackSink)
        var fallbackClause = fallbackSink !== ""
            ? ("if [ -z \"$target\" ]; then target='" + escapedFallback + "'; fi; ")
            : ""

        getMasterVolume.command = ["sh", "-c", masterSinkResolvePrefix() + fallbackClause +
            "if [ -n \"$target\" ]; then pactl get-sink-volume \"$target\" 2>/dev/null | head -n1 | awk -F'/' '{gsub(/[^0-9]/,\"\",$2); print ($2==\"\"?0:$2)}'; fi"]
        getMasterMute.command = ["sh", "-c", masterSinkResolvePrefix() + fallbackClause +
            "if [ -n \"$target\" ]; then pactl get-sink-mute \"$target\" 2>/dev/null | awk '{print ($2==\"yes\"?1:0)}'; fi"]
        getMasterVolume.running = true
        getMasterMute.running = true
    }

    function refreshAll() {
        getDefaultSink.running = true
        getSinks.running = true
        getAppStreams.running = true
        refreshMaster()
    }

    function switchOutputDevice(sinkName) {
        if (!sinkName || sinkName === "") {
            return
        }

        selectedSinkName = sinkName
        outputSelectorOpen = false
        var escapedSink = escapeShell(sinkName)
        // Le sink matériel reste à 100%/démuté : c'est global-audio (piloté
        // par les deux faders) qui doit rester la seule source de gain.
        setDefaultSink.command = ["sh", "-c",
            "pactl set-default-sink '" + escapedSink + "' >/dev/null 2>&1; " +
            "pactl set-sink-volume '" + escapedSink + "' 100% >/dev/null 2>&1; " +
            "pactl set-sink-mute '" + escapedSink + "' 0 >/dev/null 2>&1;"]
        setDefaultSink.running = true
        refreshMaster()
    }

    function applyMasterVolume(value) {
        var fallbackSink = selectedSinkName !== "" ? selectedSinkName : defaultSinkName
        var escapedFallback = escapeShell(fallbackSink)
        var fallbackClause = fallbackSink !== ""
            ? ("if [ -z \"$target\" ]; then target='" + escapedFallback + "'; fi; ")
            : ""

        var volume = Math.max(0, Math.min(100, Math.round(value)))

        setMasterVolumeProc.command = ["sh", "-c", masterSinkResolvePrefix() + fallbackClause +
            "if [ -n \"$target\" ]; then pactl set-sink-volume \"$target\" " + volume + "% >/dev/null 2>&1; " +
            (volume > 0 ? ("pactl set-sink-mute \"$target\" 0 >/dev/null 2>&1; ") : "") + "fi"]
        setMasterVolumeProc.running = true
        masterVolume = volume
        if (volume > 0) {
            masterMuted = false
        }
    }

    function applyStreamVolume(streamId, value) {
        var volume = Math.max(0, Math.min(100, Math.round(value)))

        setStreamVolumeProc.command = ["sh", "-c",
                                       "pactl set-sink-input-volume " + streamId + " " + volume + "% >/dev/null 2>&1; " +
                                       "if [ " + volume + " -gt 0 ]; then pactl set-sink-input-mute " + streamId + " 0 >/dev/null 2>&1; fi"]
        setStreamVolumeProc.running = true
    }

    Component.onCompleted: {
        if (pollingEnabled) {
            refreshAll()
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.pollingEnabled
        onTriggered: {
            if (root.activeSliderInteractions === 0) {
                root.refreshAll()
            }
        }
    }

    onPollingEnabledChanged: {
        if (pollingEnabled && root.activeSliderInteractions === 0) {
            root.refreshAll()
        }
    }

    Process {
        id: getDefaultSink
        running: false
        command: ["sh", "-c", "pactl info 2>/dev/null | awk -F': ' '/Default Sink/ {print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.defaultSinkName = (this.text || "").trim()
                root.syncSelectedSink()
            }
        }
    }

    Process {
        id: getSinks
        running: false
        command: ["sh", "-c",
                  "pactl list sinks 2>/dev/null | awk -v RS='' -F'\\n' " +
                  "'{name=\"\"; desc=\"\"; " +
                  "for(i=1;i<=NF;i++){line=$i; sub(/^[[:space:]]+/,\"\",line); " +
                  "if(line ~ /^Name: /){name=substr(line,7)} " +
                  "else if(line ~ /^Description: /){desc=substr(line,14)}} " +
                  "if(name!=\"\"){if(desc==\"\") desc=name; gsub(/\\|/,\"/\",desc); print name \"|\" desc}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var allDevices = []
                var lines = (this.text || "").trim().split("\n")

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line === "") {
                        continue
                    }

                    var parts = line.split("|")
                    if (parts.length < 2) {
                        continue
                    }

                    var sinkName = parts[0]
                    var sinkDescription = parts[1]

                    allDevices.push({
                        name: sinkName,
                        label: root.prettyOutputLabel(sinkName, sinkDescription),
                        preferred: root.isPreferredHardwareSink(sinkName),
                        isDefault: sinkName === root.defaultSinkName
                    })
                }

                var devices = []
                for (var j = 0; j < allDevices.length; j++) {
                    var device = allDevices[j]
                    if (root.shouldIgnoreSink(device.name, device.label)) {
                        continue
                    }
                    if (device.preferred) {
                        devices.push(device)
                    }
                }

                // Fallback si aucun sink "hardware" strict n'est trouvé.
                if (devices.length === 0) {
                    for (var k = 0; k < allDevices.length; k++) {
                        var fallbackDevice = allDevices[k]
                        if (!root.shouldIgnoreSink(fallbackDevice.name, fallbackDevice.label)) {
                            devices.push(fallbackDevice)
                        }
                    }
                }

                root.outputDevices = devices
                if (devices.length === 0) {
                    root.outputSelectorOpen = false
                }
                root.syncSelectedSink()
            }
        }
    }

    Process {
        id: getMasterVolume
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var vol = parseInt((this.text || "").trim())
                if (!isNaN(vol)) {
                    root.masterVolume = Math.max(0, Math.min(100, vol))
                }
            }
        }
    }

    Process {
        id: getMasterMute
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.masterMuted = ((this.text || "").trim() === "1")
            }
        }
    }

    Process {
        id: getAppStreams
        running: false
        command: ["sh", "-c",
                  "pactl list sink-inputs 2>/dev/null | awk -v RS='' -F'\\n' " +
                  "'{id=\"\"; app=\"\"; media=\"\"; bin=\"\"; vol=0; mute=0; sinkId=\"\"; " +
                  "for(i=1;i<=NF;i++){line=$i; sub(/^[[:space:]]+/,\"\",line); " +
                  "if(line ~ /^Sink Input #/){id=line; sub(/^Sink Input #/,\"\",id)} " +
                  "else if(line ~ /^Sink: /){sinkId=substr(line,7)} " +
                  "else if(line ~ /^Volume: /){if(match(line,/[0-9]+%/)){vol=substr(line,RSTART,RLENGTH-1)}} " +
                  "else if(line ~ /^Mute: /){mute=(line ~ /yes$/)?1:0} " +
                  "else if(line ~ /^application.name = \\\"/){app=line; sub(/^application.name = \\\"/,\"\",app); sub(/\\\"$/,\"\",app)} " +
                  "else if(line ~ /^media.name = \\\"/){media=line; sub(/^media.name = \\\"/,\"\",media); sub(/\\\"$/,\"\",media)} " +
                  "else if(line ~ /^application.process.binary = \\\"/){bin=line; sub(/^application.process.binary = \\\"/,\"\",bin); sub(/\\\"$/,\"\",bin)}} " +
                  "if(id!=\"\"){name=app; if(name==\"\") name=media; if(name==\"\") name=bin; if(name==\"\") name=\"Application \" id; " +
                  "gsub(/\\|/,\"/\",name); gsub(/\\|/,\"/\",app); gsub(/\\|/,\"/\",media); gsub(/\\|/,\"/\",bin); " +
                  "print id \"|\" name \"|\" vol \"|\" mute \"|\" sinkId \"|\" app \"|\" media \"|\" bin}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var streams = []
                var lines = (this.text || "").trim().split("\n")

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line === "") {
                        continue
                    }

                    var parts = line.split("|")
                    if (parts.length < 8) {
                        continue
                    }

                    var metaText = [parts[1], parts[5], parts[6], parts[7]].join(" ")
                    if (root.shouldIgnoreStream(metaText)) {
                        continue
                    }

                    var streamObject = {
                        id: parts[0],
                        name: parts[1],
                        app: parts[5],
                        media: parts[6],
                        binary: parts[7],
                        volume: Math.max(0, Math.min(100, parseInt(parts[2]) || 0)),
                        muted: parts[3] === "1",
                        sinkId: parts[4]
                    }
                    streamObject.displayName = root.prettyAppName(streamObject)
                    streams.push(streamObject)
                }

                root.appStreams = streams
            }
        }
    }

    Process {
        id: setDefaultSink
        running: false
        onExited: root.refreshAll()
    }

    Process { id: setMasterVolumeProc; running: false }
    Process { id: setStreamVolumeProc; running: false }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onEntered: root.isActive = true
        onExited: root.isActive = false
        onPressed: mouse.accepted = false
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {
            id: outputPanel
            width: parent.width
            property int dropdownMaxHeight: 132
            property int dropdownContentHeight: outputDevicesColumn.height + 8
            property int dropdownHeight: Math.min(dropdownMaxHeight, dropdownContentHeight)
            height: 56 + ((root.outputSelectorOpen && root.outputDevices.length > 0) ? (dropdownHeight + 6) : 0)
            radius: 10
            color: "#40121212"
            border.color: "#28FFFFFF"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Text {
                    text: "Hardware Output"
                    color: "#EAEAEA"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "SF Pro Display"
                }

                Text {
                    text: "No hardware output found"
                    color: "#8B8B8B"
                    font.pixelSize: 10
                    font.family: "SF Pro Display"
                    visible: root.outputDevices.length === 0
                }
                Item {
                    width: parent.width
                    height: root.outputDevices.length > 0 ? (24 + (root.outputSelectorOpen ? outputPanel.dropdownHeight + 6 : 0)) : 0
                    visible: root.outputDevices.length > 0

                    Rectangle {
                        id: outputSelectButton
                        width: parent.width
                        height: 24
                        radius: 12
                        color: "#2f1f1f1f"
                        border.color: "#50FFFFFF"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                width: parent.width - 20
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.selectedOutputLabel()
                                color: "#E6E6E6"
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "SF Pro Display"
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.outputSelectorOpen ? "▴" : "▾"
                                color: "#CFCFCF"
                                font.pixelSize: 11
                                font.family: "SF Pro Display"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.outputSelectorOpen = !root.outputSelectorOpen
                            }
                        }
                    }

                    Rectangle {
                        id: outputSelectorDropdown
                        anchors.top: outputSelectButton.bottom
                        anchors.topMargin: 6
                        width: parent.width
                        height: outputPanel.dropdownHeight
                        radius: 10
                        color: "#2f1f1f1f"
                        border.color: "#50FFFFFF"
                        border.width: 1
                        clip: true
                        visible: root.outputSelectorOpen

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            contentHeight: outputDevicesColumn.height
                            interactive: contentHeight > height

                            Column {
                                id: outputDevicesColumn
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: root.outputDevices

                                    Rectangle {
                                        required property var modelData
                                        property bool selected: modelData.name === root.selectedSinkName

                                        width: outputDevicesColumn.width
                                        height: 24
                                        radius: 8
                                        color: selected ? "#8FD1FF" : "#23232323"
                                        border.color: selected ? "#B4E1FF" : "#30FFFFFF"
                                        border.width: 1

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            Rectangle {
                                                width: modelData.isDefault ? 6 : 0
                                                height: 6
                                                radius: 3
                                                color: "#81E08D"
                                                visible: modelData.isDefault
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                width: parent.width - 14
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.label
                                                color: parent.parent.selected ? "#0E1A22" : "#E6E6E6"
                                                font.pixelSize: 11
                                                font.bold: true
                                                font.family: "SF Pro Display"
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.switchOutputDevice(modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: masterPanel
            width: parent.width
            height: 58
            radius: 10
            color: "#40121212"
            border.color: "#28FFFFFF"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 7
                anchors.bottomMargin: 6
                spacing: 4

                Row {
                    width: parent.width

                    Text {
                        id: outputVolumeLabel
                        text: "Output Volume"
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "SF Pro Display"
                    }

                    Item {
                        width: Math.max(0, parent.width - outputVolumeLabel.implicitWidth - outputVolumeValue.implicitWidth)
                        height: 1
                    }

                    Text {
                        id: outputVolumeValue
                        text: root.masterVolume + "%"
                        color: root.masterMuted ? "#FF8A8A" : "#DCDCDC"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "SF Pro Display"
                    }
                }

                Item {
                    width: parent.width
                    height: 20

                    Rectangle {
                        id: masterSliderTrack
                        width: parent.width
                        height: 6
                        radius: 3
                        color: "#35FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: parent.width * masterSliderMouse.value
                            height: parent.height
                            radius: parent.radius
                            color: "white"
                        }
                    }

                    Rectangle {
                        id: masterSliderHandle
                        width: 20
                        height: 20
                        radius: 10
                        color: "white"
                        x: (masterSliderTrack.width - width) * masterSliderMouse.value
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on x {
                            NumberAnimation {
                                duration: masterSliderMouse.pressed ? 0 : 140
                            }
                        }
                    }

                    MouseArea {
                        id: masterSliderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        property real value: root.masterVolume / 100

                        onWheel: {
                            var step = 5
                            if (wheel.angleDelta.y > 0) {
                                value = Math.min(1, value + step / 100)
                            } else if (wheel.angleDelta.y < 0) {
                                value = Math.max(0, value - step / 100)
                            }
                            root.applyMasterVolume(Math.round(value * 100))
                        }

                        onPressed: {
                            root.beginSliderInteraction()
                            updateValue(mouse.x)
                        }

                        onReleased: {
                            root.endSliderInteraction()
                        }

                        onCanceled: {
                            root.endSliderInteraction()
                        }

                        onPositionChanged: {
                            if (pressed) {
                                updateValue(mouse.x)
                            }
                        }

                        function updateValue(mouseX) {
                            value = Math.max(0, Math.min(1, mouseX / width))
                            root.applyMasterVolume(Math.round(value * 100))
                        }
                    }

                    Connections {
                        target: root
                        function onMasterVolumeChanged() {
                            if (!masterSliderMouse.pressed) {
                                masterSliderMouse.value = Math.max(0, Math.min(1, root.masterVolume / 100))
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: appsPanel
            width: parent.width
            height: parent.height - outputPanel.height - masterPanel.height - (parent.spacing * 2)
            radius: 10
            color: "#40121212"
            border.color: "#28FFFFFF"
            border.width: 1

            Text {
                id: appsTitle
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.topMargin: 7
                text: "Apps With Sound"
                color: "#EAEAEA"
                font.pixelSize: 11
                font.bold: true
                font.family: "SF Pro Display"
            }

            Text {
                anchors.centerIn: parent
                text: "No active audio app"
                color: "#8B8B8B"
                font.pixelSize: 11
                font.family: "SF Pro Display"
                visible: root.appStreams.length === 0
            }

            Flickable {
                anchors.top: appsTitle.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                clip: true
                contentHeight: appsColumn.height
                interactive: contentHeight > height
                visible: root.appStreams.length > 0

                Column {
                    id: appsColumn
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.appStreams

                        Rectangle {
                            required property var modelData

                            width: appsColumn.width
                            height: 46
                            radius: 9
                            color: "#2AFFFFFF"
                            border.color: "#22FFFFFF"
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 6
                                anchors.bottomMargin: 6
                                spacing: 4

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        id: appNameText
                                        width: parent.width - appPercentText.width - 8
                                        text: modelData.displayName
                                        color: "#EDEDED"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "SF Pro Display"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: appPercentText
                                        width: 36
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(appSliderMouse.value * 100) + "%"
                                        color: appSliderMouse.value <= 0.001 ? "#FF8A8A" : "#CFCFCF"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "SF Pro Display"
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 20

                                    Rectangle {
                                        id: appSliderTrack
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: "#35FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: parent.width * appSliderMouse.value
                                            height: parent.height
                                            radius: parent.radius
                                            color: "white"
                                        }
                                    }

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "white"
                                        x: (appSliderTrack.width - width) * appSliderMouse.value
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: appSliderMouse.pressed ? 0 : 140
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: appSliderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        property real value: Math.max(0, Math.min(1, (modelData.volume || 0) / 100))

                                        onWheel: {
                                            var step = 5
                                            if (wheel.angleDelta.y > 0) {
                                                value = Math.min(1, value + step / 100)
                                            } else if (wheel.angleDelta.y < 0) {
                                                value = Math.max(0, value - step / 100)
                                            }
                                            root.applyStreamVolume(modelData.id, Math.round(value * 100))
                                        }

                                        onPressed: {
                                            root.beginSliderInteraction()
                                            updateValue(mouse.x)
                                        }

                                        onReleased: {
                                            root.endSliderInteraction()
                                        }

                                        onCanceled: {
                                            root.endSliderInteraction()
                                        }

                                        onPositionChanged: {
                                            if (pressed) {
                                                updateValue(mouse.x)
                                            }
                                        }

                                        function updateValue(mouseX) {
                                            value = Math.max(0, Math.min(1, mouseX / width))
                                            root.applyStreamVolume(modelData.id, Math.round(value * 100))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// components/bar/BarContainer.qml
import QtQuick 2.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../notch"

Scope {
    id: rootScope
    property bool forceHide: false
    property var monitorEnabledStates: ({})
    property string monitorStatePath: Quickshell.statePath("notch_monitor_states.json")

    FileView {
        id: monitorStateFile
        path: rootScope.monitorStatePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: rootScope.loadMonitorEnabledStates()
        onFileChanged: rootScope.loadMonitorEnabledStates()
    }

    function isPrimaryMonitor(monitorName) {
        return monitorName === "eDP-1" || monitorName === "eDP-2"
    }

    function isExcludedFromPrimaryRule(monitorName) {
        return (monitorName || "").toLowerCase() === "dp-1"
    }

    function hasEligibleExternalMonitor() {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            var name = screens[i] && screens[i].name ? screens[i].name : ""
            if (!isPrimaryMonitor(name) && !isExcludedFromPrimaryRule(name)) {
                return true
            }
        }
        return false
    }

    function isPrimaryMonitorLocked(monitorName) {
        return isPrimaryMonitor(monitorName) && !hasEligibleExternalMonitor()
    }

    function sanitizeMonitorState(value) {
        var cleaned = {}
        if (!value || typeof value !== "object") {
            return cleaned
        }

        for (var key in value) {
            if (typeof value[key] === "boolean") {
                cleaned[key] = value[key]
            }
        }
        return cleaned
    }

    function loadMonitorEnabledStates() {
        try {
            var raw = monitorStateFile.text()
            if (!raw || raw.trim() === "") {
                monitorEnabledStates = ({})
                return
            }

            var parsed = JSON.parse(raw)
            monitorEnabledStates = sanitizeMonitorState(parsed)
        } catch (error) {
            console.warn("Failed to load monitor states:", error)
            monitorEnabledStates = ({})
        }
    }

    function saveMonitorEnabledStates() {
        try {
            monitorStateFile.setText(JSON.stringify(monitorEnabledStates))
        } catch (error) {
            console.warn("Failed to save monitor states:", error)
        }
    }

    function isMonitorEnabled(monitorName) {
        if (isPrimaryMonitorLocked(monitorName)) {
            return true
        }

        var state = monitorEnabledStates[monitorName]
        return state === undefined ? true : state
    }

    function setMonitorEnabled(monitorName, enabled) {
        if (isPrimaryMonitorLocked(monitorName)) {
            return
        }

        var nextState = {}
        for (var key in monitorEnabledStates) {
            nextState[key] = monitorEnabledStates[key]
        }
        nextState[monitorName] = enabled
        monitorEnabledStates = nextState
        saveMonitorEnabledStates()
    }

    Component.onCompleted: {
        loadMonitorEnabledStates()
    }



    Variants {
        model: Quickshell.screens

        // Parent invisible Container that hosts the logic per screen
        Item {
            id: screenContainer
            required property var modelData
            
            property bool isFullscreen: false
            property string monitorName: screenContainer.modelData.name
            property bool notchEnabled: rootScope.isMonitorEnabled(screenContainer.monitorName)

            Process {
                id: fullscreenListener
                // Pass the monitor name to the script so it only listens for this specific monitor
                command: ["/usr/bin/bash", "/home/emmanuel/dotfiles/quickshell/components/bar/scripts/listen_fullscreen.sh", screenContainer.modelData.name]
                running: true
                
                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: function(data) {
                        var output = data.trim();
                        if (output === "true") {
                            screenContainer.isFullscreen = true;
                        } else if (output === "false") {
                            screenContainer.isFullscreen = false || rootScope.forceHide;
                        }
                    }
                }
            }

            // === 1. HITBOX INVISIBLE ===
            PanelWindow {
                id: hitboxPanel
                screen: screenContainer.modelData
                
                visible: screenContainer.notchEnabled

                anchors {
                    top: true
                    left: true
                    right: true
                }

                property int topGap: 25

                implicitHeight: topGap
                exclusiveZone: (screenContainer.notchEnabled && !screenContainer.isFullscreen) ? topGap : 0

                color: "transparent"
                mask: Region { }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: true
                }

                WlrLayershell.layer: WlrLayer.Top
            }

            // === 2. NOTCH NORMALE ===
            PanelWindow {
                id: barPanel
                screen: screenContainer.modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }

                color: "transparent"
                implicitHeight: 100
                
                property bool delayedVisible: false
                visible: screenContainer.notchEnabled && !screenContainer.isFullscreen && delayedVisible
                
                Connections {
                    target: overlayPanel
                    function onVisibleChanged() {
                        if (overlayPanel.visible) {
                            barPanel.delayedVisible = false
                            showDelayTimer.stop()
                        } else {
                            showDelayTimer.restart()
                        }
                    }
                }
                
                Timer {
                    id: showDelayTimer
                    interval: 350
                    onTriggered: {
                        barPanel.delayedVisible = true
                    }
                }
                
                Component.onCompleted: {
                    delayedVisible = true
                }

                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                mask: Region { item: mainNotch }

                Notch {
                    id: mainNotch
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    runtimeActive: barPanel.visible
                    monitorStates: rootScope.monitorEnabledStates
                    hostMonitorName: screenContainer.monitorName
                    onMonitorToggled: function(monitorName, enabled) {
                        rootScope.setMonitorEnabled(monitorName, enabled)
                    }
                }
            }

            // === 3. NOTCH OVERLAY ===
            PanelWindow {
                id: overlayPanel
                screen: screenContainer.modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }

                color: "transparent"
                implicitHeight: 450
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                visible: screenContainer.notchEnabled && !screenContainer.isFullscreen && (mainNotch.hovered || overlayNotch.hovered)

                mask: Region { item: overlayNotch }

                Notch {
                    id: overlayNotch
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    hovered: overlayPanel.visible
                    runtimeActive: overlayPanel.visible
                    monitorStates: rootScope.monitorEnabledStates
                    hostMonitorName: screenContainer.monitorName
                    onMonitorToggled: function(monitorName, enabled) {
                        rootScope.setMonitorEnabled(monitorName, enabled)
                    }
                    
                    onNeedsKeyboardFocusChanged: {
                        if (needsKeyboardFocus) {
                            overlayPanel.requestActivate()
                        }
                    }
                }
            }
        }
    }
}

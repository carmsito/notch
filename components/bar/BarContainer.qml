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

    function isPrimaryMonitor(monitorName) {
        return monitorName === "eDP-1" || monitorName === "eDP-2"
    }

    function isMonitorEnabled(monitorName) {
        if (isPrimaryMonitor(monitorName)) {
            return true
        }

        var state = monitorEnabledStates[monitorName]
        return state === undefined ? true : state
    }

    function setMonitorEnabled(monitorName, enabled) {
        if (isPrimaryMonitor(monitorName)) {
            return
        }

        var nextState = {}
        for (var key in monitorEnabledStates) {
            nextState[key] = monitorEnabledStates[key]
        }
        nextState[monitorName] = enabled
        monitorEnabledStates = nextState
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

                property int topGap: 48

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

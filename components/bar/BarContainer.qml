// components/bar/BarContainer.qml
import QtQuick 2.15
import Quickshell
import Quickshell.Wayland
import "../notch"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
        required property var modelData
        screen: modelData
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 45

        }
    }
    Variants {
        model: Quickshell.screens

        // === 1. HITBOX INVISIBLE (réserve l’espace + click-through) ===
        PanelWindow {
            id: hitboxPanel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            // Espace que tu veux réserver (comme une barre Waybar)
            property int topGap: 48

            // La fenêtre DOIT réellement faire la même hauteur que topGap
            implicitHeight: topGap
            exclusiveZone: topGap

            color: "transparent"

            // 100% click-through
            mask: Region { }

            // Surface réelle pour Wayland (obligatoire)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: true
            }

            // Hitbox doit être dans une des couches principales
            WlrLayershell.layer: WlrLayer.Top
        }

        // === 2. NOTCH NORMALE (visible, mais ne réserve pas d’espace) ===
        PanelWindow {
            id: barPanel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            color: "transparent"
            implicitHeight: 100  // Hauteur fixe pour éviter redimensionnement

            // Attendre la fin de l'animation avant de réapparaître
            property bool delayedVisible: false
            visible: delayedVisible
            
            Connections {
                target: overlayPanel
                function onVisibleChanged() {
                    if (overlayPanel.visible) {
                        // Overlay apparaît -> cacher immédiatement barPanel
                        barPanel.delayedVisible = false
                        showDelayTimer.stop()
                    } else {
                        // Overlay disparaît -> attendre la fin de l'animation
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

            // Ne modifie pas la geometry → c'est seulement une couche visuelle
            exclusionMode: ExclusionMode.Ignore

            // Layer fixe
            WlrLayershell.layer: WlrLayer.Top

            // Seule la notch est interactive
            mask: Region { item: mainNotch }

            Notch {
                id: mainNotch
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
            }
        }

        // === 3. NOTCH OVERLAY (dépasse au hover, totalement indépendante) ===
        PanelWindow {
            id: overlayPanel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            color: "transparent"
            // celui là qui gère la hauteur maximale de la notch
            implicitHeight: 450  // Hauteur fixe maximale pour éviter redimensionnement
            exclusionMode: ExclusionMode.Ignore

            // Toujours au-dessus de tout, y compris workspace & bar
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // Visible si hover sur la notch normale ou overlay elle-même
            visible: mainNotch.hovered || overlayNotch.hovered

            // Seule la notch overlay capte la souris
            mask: Region { item: overlayNotch }

            Notch {
                id: overlayNotch
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                hovered: overlayPanel.visible
                
                // Demander le focus clavier quand nécessaire
                onNeedsKeyboardFocusChanged: {
                    if (needsKeyboardFocus) {
                        overlayPanel.requestActivate()
                    }
                }
            }
        }
    }
}

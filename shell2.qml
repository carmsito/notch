// import QtQuick 6.4
// import Quickshell 2.0
// import Quickshell.Hyprland 0.1
// import "components"

// ShellRoot {
//   PanelWindow {
//     id: notchWindow

//     implicitWidth: Screen.width
//     implicitHeight: 36

//     anchors.top: true
//     anchors.left: true
//     anchors.right: true

//     color: "transparent"
//     aboveWindows: true
//     exclusiveZone: implicitHeight
//     visible: true

//     Component.onCompleted: {
//         console.log("notchWindow: created w=", width, "h=", height)
//     }

//     NotchBar {
//       anchors.top: parent.top
//       anchors.left: parent.left
//       anchors.right: parent.right
//       height: parent.height
//     }
//   }
// }
import Quickshell

Scope {
  Bar {}
}
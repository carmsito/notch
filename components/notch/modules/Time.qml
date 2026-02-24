// Time.qml
import Quickshell
import QtQuick

Scope {
  id: root
  property string time: ""
  property bool pollingEnabled: true

  function updateTime() {
    var now = new Date()
    // Format proche de `date` tout en évitant un process externe chaque seconde.
    root.time = Qt.formatDateTime(now, "ddd. dd MMM yyyy HH:mm:ss t")
  }

  Timer {
    interval: 1000
    running: root.pollingEnabled
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateTime()
  }

  Component.onCompleted: root.updateTime()
}

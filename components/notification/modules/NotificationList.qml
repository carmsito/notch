import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

ListView {
    id: listView
    clip: true
    spacing: 20 // Space for the stack effect
    
    property int maxItems: 30

    model: ListModel { id: notificationsModel }

    function formatTime(ts) {
        var d = new Date(ts)
        var h = d.getHours()
        var m = d.getMinutes()
        return (h < 10 ? "0" + h : "" + h) + ":" + (m < 10 ? "0" + m : "" + m)
    }

    function findById(id) {
        for (var i = 0; i < notificationsModel.count; i++) {
            if (notificationsModel.get(i).id === id) {
                return i
            }
        }
        return -1
    }

    function handleEvent(line) {
        if (!line || line.trim() === "") {
            return
        }
        try {
            var evt = JSON.parse(line)
            if (!evt || !evt.type) {
                return
            }

            if (evt.type === "notify") {
                var item = {
                    id: evt.id,
                    appName: evt.appName || "App",
                    title: evt.title || "",
                    preview: evt.body || evt.title || "",
                    time: formatTime(evt.timestamp || Date.now()),
                    count: 1
                }
                var idx = findById(evt.id)
                if (idx >= 0) {
                    notificationsModel.set(idx, item)
                } else {
                    notificationsModel.insert(0, item)
                    if (notificationsModel.count > maxItems) {
                        notificationsModel.remove(maxItems, notificationsModel.count - maxItems)
                    }
                }
            } else if (evt.type === "close") {
                var closeIdx = findById(evt.id)
                if (closeIdx >= 0) {
                    notificationsModel.remove(closeIdx)
                }
            }
        } catch (error) {
            // ignore parse errors
        }
    }

    Process {
        id: notifProc
        running: true
        command: ["python3", "/home/emmanuel/dotfiles/quickshell/components/notification/modules/notify_listener.py"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                listView.handleEvent(data)
            }
        }
    }

    delegate: NotificationGroup {
        width: listView.width
        appName: model.appName
        count: model.count
        time: model.time
        preview: model.preview
        title: model.title
    }
}

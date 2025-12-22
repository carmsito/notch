import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ListView {
    id: listView
    clip: true
    spacing: 20 // Space for the stack effect
    
    model: ListModel {
        ListElement {
            appName: "CNN"
            count: 47
            time: "Yesterday, 07:57 PM"
            preview: "Breaking News"
        }
        ListElement {
            appName: "OmniFocus"
            count: 2
            time: "08:00"
            preview: "Due 14/09/2019, 08:00"
        }
        ListElement {
            appName: "Messages"
            count: 5
            time: "10:30 AM"
            preview: "Hey, are we still on for lunch?"
        }
    }

    delegate: NotificationGroup {
        width: listView.width
        appName: model.appName
        count: model.count
        time: model.time
        preview: model.preview
    }
}

import QtQuick 2.15
import QtQuick.Layouts 1.15
import "modules"

Item {
    id: performanceContainer
    width: 440
    height: 250
    property bool pollingEnabled: true
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 3
        spacing: 10
        
        // Left: Fans Control
        FansControl {
            id: fansControl
            Layout.preferredWidth: 150
            Layout.preferredHeight: 235
            pollingEnabled: performanceContainer.pollingEnabled
        }
        
        // Right: System Usage
        SystemUsage {
            id: systemUsage
            Layout.preferredWidth: 280
            Layout.preferredHeight: 235
            pollingEnabled: performanceContainer.pollingEnabled
        }
    }
}

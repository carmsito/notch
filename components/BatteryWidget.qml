// BatteryWidget.qml
import QtQuick

Text {
  required property string batteryLevel

  text: batteryLevel
  color: "white"      // <-- Texte en blanc
  font.pixelSize: 14  // (optionnel) meilleure lisibilité
}

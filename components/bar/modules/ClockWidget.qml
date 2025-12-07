// ClockWidget.qml
import QtQuick

Text {
  required property string time

  text: time
  color: "white"      // <-- Texte en blanc
  font.pixelSize: 16  // (optionnel) meilleure lisibilité
}

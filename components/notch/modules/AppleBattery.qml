import QtQuick

Item {
    id: root
    
    // Propriétés à passer depuis l'extérieur
    property int level: 50      // 0 à 100
    property bool charging: false
    
    // Taille implicite par défaut (ratio ~ 2:1)
    width: 26
    height: 13

    // Couleurs style Apple
    readonly property color cWhite: "#FFFFFFFF"
    readonly property color cGreen: "#32D74B" // Le vert "Apple"
    readonly property color cRed:   "#FF453A"
    readonly property color cGrey:  "#48484A"

    // Calcul de la couleur dynamique
    property color dynamicColor: {
        if (charging) return cGreen
        if (level <= 20) return cRed
        return cWhite
    }

    // 1. Le corps de la batterie (Contour)
    Rectangle {
        id: body
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - 3 // On garde 3px pour la tétine à droite
        
        color: "transparent"
        border.color: "#4DFFFFFF" // Contour gris clair translucide (30%)
        border.width: 1.5 // Épaisseur du trait
        radius: 4
    }

    // 2. La tétine (Le petit truc à droite)
    Rectangle {
        anchors.left: body.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 1 // Petit espace
        
        width: 2
        height: parent.height / 2.5 // Plus petit que le corps
        
        radius: 2
        // La tétine est un peu plus opaque que le contour
        color: "#80FFFFFF" 
    }

    // 3. Le Remplissage (La jauge)
    Rectangle {
        id: fill
        
        // Positionnement à l'intérieur du contour (padding de 2px)
        anchors.left: body.left
        anchors.top: body.top
        anchors.bottom: body.bottom
        anchors.margins: 2 

        // La magie : largeur calculée en fonction du niveau
        // On limite (clip) pour ne pas dépasser 100%
        width: (body.width - 4) * (Math.min(root.level, 100) / 100)
        
        radius: 2
        color: root.dynamicColor

        // Animation fluide quand le niveau change
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    
    // (Optionnel) Petit éclair si en charge
    // Si tu veux l'ajouter, dis-le moi, mais souvent la couleur verte suffit.
}
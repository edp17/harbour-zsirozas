import QtQuick 2.6
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0

Item {
    id: root
    property bool pressed: false
    property bool faceUp: true
    width: Theme.itemSizeLarge * 1.4
    height: width * 1.4

    property string cardId
    
    scale: pressed ? 1.06 : 1.0
    y: pressed ? -Theme.paddingSmall : 0

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Behavior on y {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Image {
        id: cardBackImage
        anchors.fill: parent
        source: Qt.resolvedUrl("../images/cards/back.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: !root.faceUp
        z: 1
    }

    Image {
        id: cardFaceImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: root.faceUp
                ? Qt.resolvedUrl("../images/cards/card-" + cardId + ".png")
                : ""
        smooth: true
        visible: root.faceUp
        z: 1
    }

    DropShadow {
        anchors.fill: root
        source: root.faceUp ? cardFaceImage : cardBackImage
        horizontalOffset: 3
        verticalOffset: 3
        radius: 6
        samples: 12
        color: "#30000000"
        cached: true
    }
}

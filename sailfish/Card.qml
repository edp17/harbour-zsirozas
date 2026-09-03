/*
    Copyright (C) 2026 edp17 and chatGPT

    This file is part of harbour-zsirozas.

    The harbour-zsirozas is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The harbour-zsirozas is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the harbour-zsirozas. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0

Item {
    id: root
    property bool pressed: false
    property bool faceUp: true
    property string cardStyle: "Piatnik"
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
        source: Qt.resolvedUrl(root.cardStyle === "Betyar"
                               ? "../images/cards/betyar_back.png"
                               : "../images/cards/back.png")
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
                ? Qt.resolvedUrl("../images/cards/"
                                 + (root.cardStyle === "Betyar" ? "betyar_card_" : "card-")
                                 + cardId + ".png")
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

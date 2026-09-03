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

Item {
    id: root
    property string playerName: ""
    property var cards: []
    property string cardStyle: "Piatnik"
    property var hiddenCardIds: ({})
    property bool vertical: false
    property bool activeTurn: false
    property real cardWidth: vertical ? Theme.itemSizeMedium : Theme.itemSizeLarge
    property real cardHeight: cardWidth * 1.4
    property real cardSpacing: vertical ? cardHeight * 0.18 : cardWidth * 0.5

    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingMedium
        color: Theme.highlightColor
        opacity: root.activeTurn ? 0.14 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.vertical ? undefined : parent.top
        anchors.bottomMargin: Theme.paddingSmall
        anchors.top: root.vertical ? parent.bottom : undefined
        anchors.topMargin: Theme.paddingSmall
        text: root.playerName
        font.pixelSize: Theme.fontSizeExtraSmall
        color: root.activeTurn ? Theme.highlightColor : Theme.secondaryColor
        truncationMode: TruncationMode.Fade
        width: root.vertical ? root.height : root.width
        horizontalAlignment: Text.AlignHCenter
        rotation: root.vertical ? -90 : 0
    }

    Repeater {
        model: root.cards
        delegate: Card {
            cardId: modelData.id
            cardStyle: root.cardStyle
            faceUp: false
            width: root.cardWidth
            height: root.cardHeight
            property int count: root.cards.length
            property real handLength: (count - 1) * root.cardSpacing
                                      + (root.vertical ? height : width)
            x: root.vertical ? (root.width - width) / 2
                             : (root.width - handLength) / 2 + index * root.cardSpacing
            y: root.vertical ? (root.height - handLength) / 2 + index * root.cardSpacing : 0
            z: index
            opacity: root.hiddenCardIds[modelData.id] ? 0.0 : 1.0
        }
    }
}

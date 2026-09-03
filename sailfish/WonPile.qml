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
    property int score: 0
    property string cardStyle: "Piatnik"
    property color accentColor: Theme.highlightColor
    property bool inspectable: false
    signal clicked

    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingSmall
        color: root.accentColor
        opacity: pileMouse.pressed ? 0.20 : 0.09
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingSmall
        color: "transparent"
        border.color: root.accentColor
        border.width: root.inspectable && root.cards.length > 0 ? 2 : 0
        opacity: 0.75
        z: 100
    }

    Label {
        anchors.right: parent.left
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.itemSizeHuge
        horizontalAlignment: Text.AlignRight
        text: root.cards.length > 0 ? qsTr("Tap to view →") : qsTr("Won cards")
        visible: root.inspectable
        font.pixelSize: Theme.fontSizeExtraSmall
        color: root.cards.length > 0 ? root.accentColor : Theme.secondaryColor
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.paddingSmall
        text: root.score
        visible: root.cards.length > 0
        font.pixelSize: Theme.fontSizeExtraSmall
        color: root.accentColor
    }

    Repeater {
        model: root.cards
        delegate: Card {
            cardId: modelData.id
            cardStyle: root.cardStyle
            faceUp: false
            width: root.width * 0.8
            height: width * 1.4
            x: (root.width - width) / 2 + index * 1.5
            y: (root.height - height) / 2 + index * 1.5
            z: index
            rotation: (index % 2 === 0 ? -2 : 2) * Math.min(index, 3)
            opacity: index >= model.count - 3 ? 1.0 : 0.6
        }
    }

    MouseArea {
        id: pileMouse
        anchors.fill: parent
        enabled: root.inspectable && root.cards.length > 0
        onClicked: root.clicked()
    }
}

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

CoverBackground {
    id: cover
    property string cardStyle: "Piatnik"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#184d1d" }
            GradientStop { position: 1.0; color: "#0b2710" }
        }
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.paddingLarge
        width: parent.width * 0.72
        height: parent.height * 0.55

        Card {
            width: parent.width * 0.46
            height: width * 1.4
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -width * 0.42
            anchors.verticalCenterOffset: Theme.paddingSmall
            rotation: -16
            cardId: "0_10"
            cardStyle: cover.cardStyle
            faceUp: true
        }
        Card {
            width: parent.width * 0.46
            height: width * 1.4
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.paddingSmall
            rotation: 0
            cardId: "1_14"
            cardStyle: cover.cardStyle
            faceUp: true
        }
        Card {
            width: parent.width * 0.46
            height: width * 1.4
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: width * 0.42
            anchors.verticalCenterOffset: Theme.paddingSmall
            rotation: 16
            cardId: "2_7"
            cardStyle: cover.cardStyle
            faceUp: true
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingLarge
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            text: "Zsírozás"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: "white"
        }
        Label {
            width: parent.width
            text: qsTr("Hit • collect • win")
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: "#b9dfbb"
        }
    }
}

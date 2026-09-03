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

Page {
    id: page
    property string ownerName: ""
    property string teamLabel: ""
    property var cards: []
    property int score: 0
    property string cardStyle: "Piatnik"
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator { }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.ownerName
                description: page.teamLabel
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge
                Label {
                    text: qsTr("Won cards: %1").arg(page.cards.length)
                    color: Theme.secondaryColor
                }
                Label {
                    text: qsTr("Zsír: %1 points").arg(page.score)
                    color: Theme.highlightColor
                    font.bold: true
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Tens and aces remain in colour. Other captured cards are shown in black and white.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Flow {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Repeater {
                    model: page.cards
                    delegate: Item {
                        width: (content.width - 2 * Theme.horizontalPageMargin
                                - 3 * Theme.paddingSmall) / 4
                        height: width * 1.4 + Theme.paddingSmall

                        Rectangle {
                            anchors.fill: cardFrame
                            anchors.margins: -Theme.paddingSmall / 2
                            radius: Theme.paddingSmall
                            color: Theme.highlightColor
                            opacity: modelData.isZsir ? 0.26 : 0.0
                        }

                        Card {
                            id: cardFrame
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - Theme.paddingSmall
                            height: width * 1.4
                            cardId: modelData.id
                            cardStyle: page.cardStyle
                            faceUp: true
                            visible: modelData.isZsir
                        }

                        Card {
                            id: grayscaleSource
                            anchors.fill: cardFrame
                            cardId: modelData.id
                            cardStyle: page.cardStyle
                            faceUp: true
                            visible: false
                        }

                        Desaturate {
                            anchors.fill: cardFrame
                            source: grayscaleSource
                            desaturation: 1.0
                            opacity: 0.72
                            visible: !modelData.isZsir
                        }
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                visible: page.cards.length === 0
                text: qsTr("No cards have been won yet.")
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryColor
            }
        }
    }
}

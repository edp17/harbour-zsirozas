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

Page {
    id: rulesPage

    property string cardStyle: "Piatnik"
    property real exampleCardWidth: Theme.itemSizeMedium

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
                title: qsTr("How to play")
                description: qsTr("Traditional Zsírozás (Zsír)")
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Play with one opponent, or choose three opponents for the traditional partnership game. In four-player mode, opposite players are partners: you play with the player across the table.")
            }

            SectionHeader { text: qsTr("Goal — collect the fat") }
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Tens and aces are the fat cards. Each is worth 10 points, so the deck contains 80 points. In partnership play, both partners' captured cards count toward one team score.")
            }

            Item {
                width: parent.width
                height: rulesPage.exampleCardWidth * 1.4

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall

                    Card {
                        cardId: "0_10"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                    Card {
                        cardId: "1_14"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                    Card {
                        cardId: "2_10"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                    Card {
                        cardId: "3_14"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                }
            }

            SectionHeader { text: qsTr("Hit the leading rank") }
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("The first card starts a pile and sets the rank to hit. A card hits when it has the same rank, or when it is any seven. A hit makes that player the current winner of the pile.")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Same rank")
            }

            Item {
                width: parent.width
                height: rulesPage.exampleCardWidth * 1.4

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Card {
                        cardId: "0_9"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "→"
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeLarge
                    }
                    Card {
                        cardId: "2_9"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                }
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Any seven")
            }

            Item {
                width: parent.width
                height: rulesPage.exampleCardWidth * 1.4

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Card {
                        cardId: "3_7"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "→"
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeLarge
                    }
                    Card {
                        cardId: "1_12"
                        cardStyle: rulesPage.cardStyle
                        width: rulesPage.exampleCardWidth
                        height: width * 1.4
                    }
                }
            }

            SectionHeader { text: qsTr("Play around the table") }
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Everyone plays one card in turn. On an ordinary turn you may hit or deliberately throw a non-hit card, even when you hold a hit. After a complete circuit, your partnership keeps the pile if your partner controls it. If the opposing side controls it, the original leader may hit again to continue.")
            }

            SectionHeader { text: qsTr("Let it go") }
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("When the pile returns to its original leader and the other side controls it, the leader may play a hit or choose Let it go. Letting go awards the whole pile to the last player who hit.")
            }

            SectionHeader { text: qsTr("Draw and lead") }
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("After a pile is collected, players draw back toward four cards while the deck lasts. The pile winner draws first, and drawing continues around the table. The same player leads the next pile.")
            }

            SectionHeader { text: qsTr("Winning the round") }
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("The side with more than 40 points wins. At 40–40, the side that won the final pile wins. If the final card played is a seven, the side that played it loses the round regardless of points.")
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Tip: tap your won-card pile to inspect it. Tens and aces stay in colour; the other captured cards are shown in black and white.")
            }
        }
    }
}

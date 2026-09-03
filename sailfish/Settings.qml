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
    id: page
    property var settings
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
                title: qsTr("Settings")
                description: qsTr("Players, cards and movement")
            }

            SectionHeader { text: qsTr("Players") }

            TextField {
                width: parent.width
                label: qsTr("Your name")
                placeholderText: qsTr("Player")
                text: settings.playerName
                onTextChanged: settings.playerName = text
            }

            ComboBox {
                width: parent.width
                label: qsTr("Opponents")
                description: currentIndex === 0
                             ? qsTr("Two-player individual game")
                             : qsTr("Four players: opposite seats are partners")
                currentIndex: settings.opponentCount === 3 ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("One opponent") }
                    MenuItem { text: qsTr("Three opponents (teams)") }
                }
                onCurrentIndexChanged: settings.opponentCount = currentIndex === 1 ? 3 : 1
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("A player-count change takes effect with the next New Game.")
            }

            SectionHeader { text: qsTr("AI opponents") }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                TextField {
                    width: parent.width
                    label: settings.opponentCount === 3 ? qsTr("Left opponent") : qsTr("Opponent name")
                    text: settings.ai1Name
                    onTextChanged: settings.ai1Name = text
                }
                ComboBox {
                    width: parent.width
                    label: qsTr("%1 difficulty").arg(settings.ai1Name || qsTr("AI 1"))
                    currentIndex: settings.ai1Difficulty
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Easy — relaxed and unpredictable") }
                        MenuItem { text: qsTr("Normal — balanced") }
                        MenuItem { text: qsTr("Hard — tactical") }
                        MenuItem { text: qsTr("Expert — card-aware") }
                    }
                    onCurrentIndexChanged: settings.ai1Difficulty = currentIndex
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: settings.opponentCount === 3
                TextField {
                    width: parent.width
                    label: qsTr("Partner (opposite seat)")
                    text: settings.ai2Name
                    onTextChanged: settings.ai2Name = text
                }
                ComboBox {
                    width: parent.width
                    label: qsTr("%1 difficulty").arg(settings.ai2Name || qsTr("AI 2"))
                    currentIndex: settings.ai2Difficulty
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Easy — relaxed and unpredictable") }
                        MenuItem { text: qsTr("Normal — balanced") }
                        MenuItem { text: qsTr("Hard — tactical") }
                        MenuItem { text: qsTr("Expert — card-aware") }
                    }
                    onCurrentIndexChanged: settings.ai2Difficulty = currentIndex
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: settings.opponentCount === 3
                TextField {
                    width: parent.width
                    label: qsTr("Right opponent")
                    text: settings.ai3Name
                    onTextChanged: settings.ai3Name = text
                }
                ComboBox {
                    width: parent.width
                    label: qsTr("%1 difficulty").arg(settings.ai3Name || qsTr("AI 3"))
                    currentIndex: settings.ai3Difficulty
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Easy — relaxed and unpredictable") }
                        MenuItem { text: qsTr("Normal — balanced") }
                        MenuItem { text: qsTr("Hard — tactical") }
                        MenuItem { text: qsTr("Expert — card-aware") }
                    }
                    onCurrentIndexChanged: settings.ai3Difficulty = currentIndex
                }
            }

            SectionHeader { text: qsTr("Cards") }

            ComboBox {
                width: parent.width
                label: qsTr("Card style")
                currentIndex: settings.cardStyle === "Betyar" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: "Piatnik" }
                    MenuItem { text: "Betyár" }
                }
                onCurrentIndexChanged: settings.cardStyle = currentIndex === 1 ? "Betyar" : "Piatnik"
            }

            SectionHeader { text: qsTr("Animation") }

            TextSwitch {
                width: parent.width
                text: qsTr("Enable animations")
                description: qsTr("Turn off for immediate card movement")
                checked: settings.animationsEnabled
                onCheckedChanged: settings.animationsEnabled = checked
            }

            Slider {
                width: parent.width
                minimumValue: 0.5
                maximumValue: 2.0
                stepSize: 0.25
                value: settings.tableFlightDuration > 10 ? 1.0 : settings.tableFlightDuration
                label: qsTr("Card speed")
                valueText: value <= 0.75 ? qsTr("Slow")
                           : value <= 1.25 ? qsTr("Normal") : qsTr("Fast")
                onValueChanged: settings.tableFlightDuration = value
            }

            Slider {
                width: parent.width
                minimumValue: 200
                maximumValue: 1500
                stepSize: 50
                value: settings.aiPlayDelay
                label: qsTr("AI thinking speed")
                valueText: value < 400 ? qsTr("Fast") : value < 900 ? qsTr("Normal") : qsTr("Slow")
                onValueChanged: settings.aiPlayDelay = value
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Reset to defaults")
                onClicked: {
                    settings.playerName = "Player"
                    settings.opponentCount = 1
                    settings.ai1Name = "AI 1"
                    settings.ai2Name = "AI 2"
                    settings.ai3Name = "AI 3"
                    settings.ai1Difficulty = 1
                    settings.ai2Difficulty = 2
                    settings.ai3Difficulty = 3
                    settings.cardStyle = "Piatnik"
                    settings.animationsEnabled = true
                    settings.tableFlightDuration = 1.0
                    settings.aiPlayDelay = 650
                }
            }
        }
    }
}

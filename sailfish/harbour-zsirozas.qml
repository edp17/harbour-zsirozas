import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.zsir 1.0
import Nemo.Configuration 1.0
import QtQuick.Layouts 1.0

ApplicationWindow
{
    ConfigurationGroup {
        id: appSettings
        path: "/apps/harbour-zsirozas/settings"

        // persisted values
        property int aiPlayDelay: 1500
        property real tableFlightDuration: 1.0   // kept for now, unused in minimal UI
        property string cardStyle: "Piatnik"
        property string ai1Name: "AI 1"
        property string ai2Name: "AI 2"
        property string ai3Name: "AI 3"

        // persisted UI state
        property bool cardStyleExpanded: true
        property bool animationsExpanded: false
        property bool namesExpanded: false
    }

    cover: Component { CoverPage { } }

    initialPage: Component
    {
        Page {
            id: mainPage

            GameEngine {
                id: engine
                aiPlayDelay: appSettings.aiPlayDelay
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: gameRoot.height

                PullDownMenu {
                    MenuItem {
                        text: qsTr("New Game")
                        onClicked: engine.newGame()
                    }
                    MenuItem {
                        text: qsTr("Settings")
                        onClicked: pageStack.push(Qt.resolvedUrl("Settings.qml"), { settings: appSettings })
                    }
                    MenuItem {
                        text: qsTr("Game Rules")
                        onClicked: pageStack.push(Qt.resolvedUrl("GameRules.qml"))
                    }
                    MenuItem {
                        text: qsTr("About")
                        onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                    }
                }

                Column {
                    id: gameRoot
                    width: parent.width
                    spacing: Theme.paddingLarge
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingLarge

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: engine.status
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.secondaryColor
                    }

                    // Scores + last trick
                    Row {
                        width: parent.width
                        spacing: Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter

                        Label {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("You: %1").arg(engine.playerScore)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primaryColor
                        }
                        Label {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("%1: %2").arg(appSettings.ai1Name).arg(engine.cpuScore)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryColor
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: engine.lastTrick
                        visible: text.length > 0
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                    }

                    // AI area
                    SectionHeader { text: appSettings.ai1Name }

                    Row {
                        width: parent.width
                        height: Theme.itemSizeLarge * 1.4
                        spacing: Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter

                        // AI hand (face down)
                        Item {
                            width: parent.width * 0.75
                            height: parent.height
                            Repeater {
                                model: engine.cpuHand
                                delegate: Card {
                                    faceUp: false
                                    cardId: modelData.id
                                    width: Theme.itemSizeLarge
                                    height: Theme.itemSizeLarge * 1.4
                                    x: index * (width * 0.35)
                                    y: 0
                                    opacity: 0.9
                                }
                            }
                        }

                        // Deck
                        Item {
                            width: Theme.itemSizeLarge
                            height: Theme.itemSizeLarge * 1.4
                            Card {
                                anchors.centerIn: parent
                                faceUp: false
                                cardId: "0_0"
                                width: Theme.itemSizeLarge
                                height: Theme.itemSizeLarge * 1.4
                                opacity: engine.deckSize > 0 ? 0.9 : 0.2
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                anchors.topMargin: Theme.paddingSmall
                                text: qsTr("%1").arg(engine.deckSize)
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.secondaryColor
                            }
                        }
                    }

                    // Table
                    SectionHeader { text: qsTr("Table") }

                    Row {
                        width: parent.width
                        height: Theme.itemSizeLarge * 1.5
                        spacing: Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter

                        Item {
                            width: parent.width
                            height: parent.height

                            Repeater {
                                model: engine.tableCards
                                delegate: Card {
                                    cardId: modelData.id
                                    faceUp: true
                                    width: Theme.itemSizeLarge
                                    height: Theme.itemSizeLarge * 1.4

                                    // Left = player, right = AI
                                    x: modelData.playedBy === 1
                                       ? (parent.width / 2 + Theme.paddingLarge)
                                       : (parent.width / 2 - width - Theme.paddingLarge)
                                    y: 0

                                    rotation: modelData.playedBy === 1 ? 6 : -6
                                }
                            }
                        }
                    }

                    // Let it go button
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Let it go")
                        visible: engine.playerCanPass
//-                        enabled: (engine.playerCanPass && engine.playerInputEnabled)
enabled: engine.playerCanPass
                        onClicked: engine.playerPass()
                    }

                    // Player won pile preview (count only)
                    Row {
                        width: parent.width
                        spacing: Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        Label {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Your won: %1 cards").arg(engine.playerWonCards.length)
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }
                        Label {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("%1 won: %2 cards").arg(appSettings.ai1Name).arg(engine.cpuWonCards.length)
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                        }
                    }

                    // Player area
                    SectionHeader { text: qsTr("You") }

                    Row {
                        width: parent.width
                        height: Theme.itemSizeLarge * 1.6
                        spacing: Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: engine.playerHand
                            delegate: MouseArea {
                                width: Theme.itemSizeLarge
                                height: Theme.itemSizeLarge * 1.4

                                // When "Let it go" is visible, only allow HIT cards
                                enabled: engine.playerInputEnabled &&
                                         (!engine.playerCanPass ||
                                          modelData.rank === engine.tableCards[engine.tableCards.length - 1].rank ||
                                          modelData.rank === 7)

                                onClicked: engine.playCard(index)

                                Card {
                                    anchors.fill: parent
                                    cardId: modelData.id
                                    faceUp: true
                                    opacity: enabled ? 1.0 : 0.4   // optional visual hint
                                }
                            }
                        }
                    }

                    // Round result + new game
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: engine.roundResult
                        visible: text.length > 0
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.highlightColor
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("New Game")
                        visible: engine.roundResult.length > 0
                        highlighted: true
                        onClicked: engine.newGame()
                    }

                    Item { width: 1; height: Theme.paddingLarge } // bottom padding
                }
            }
        }
    }
}

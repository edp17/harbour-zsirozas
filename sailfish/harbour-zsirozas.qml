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
import harbour.zsir 1.0
import Nemo.Configuration 1.0

ApplicationWindow {
    ConfigurationGroup {
        id: appSettings
        path: "/apps/harbour-zsirozas/settings"

        property int aiPlayDelay: 650
        property int aiDifficulty: 1 // legacy RC3 key
        property int ai1Difficulty: aiDifficulty
        property int ai2Difficulty: 2
        property int ai3Difficulty: 3
        property bool animationsEnabled: true
        property real tableFlightDuration: 1.0 // animation speed; legacy name retained
        property string cardStyle: "Piatnik"
        property string playerName: "Player"
        property int opponentCount: 1
        property string ai1Name: "AI 1"
        property string ai2Name: "AI 2"
        property string ai3Name: "AI 3"
    }

    cover: Component { CoverPage { cardStyle: appSettings.cardStyle } }

    initialPage: Component {
        Page {
            id: mainPage
            allowedOrientations: Orientation.Portrait

            property real pendingPlayerStartX: -1
            property real pendingPlayerStartY: -1
            property string hiddenTableId: ""
            property var hiddenDealIds: ({})
            property int activeFlights: 0
            property string activeFlightRole: ""
            property bool pulleyRestartPending: false
            property real wonPileEdgeMargin: Theme.paddingSmall

            function animationSpeed() {
                var speed = Number(appSettings.tableFlightDuration)
                // Old development builds stored milliseconds (normally 500).
                if (speed > 10)
                    speed = 500 / speed
                return Math.max(0.5, Math.min(2.0, speed || 1.0))
            }

            function dur(milliseconds) {
                return Math.max(1, Math.round(milliseconds / animationSpeed()))
            }

            function replaceHiddenDeal(cardId, hidden) {
                var replacement = ({})
                for (var key in hiddenDealIds) {
                    if (key !== cardId && hiddenDealIds[key])
                        replacement[key] = true
                }
                if (hidden)
                    replacement[cardId] = true
                hiddenDealIds = replacement
            }

            function clearFlights() {
                for (var index = animationLayer.children.length - 1; index >= 0; --index) {
                    var child = animationLayer.children[index]
                    if (child && child.isFlyingCard)
                        child.destroy()
                }
                activeFlights = 0
                activeFlightRole = ""
                hiddenTableId = ""
                hiddenDealIds = ({})
            }

            function deckCenter() {
                return deckDealPoint.mapToItem(animationLayer, 0, 0)
            }

            function participant(player) {
                return player >= 0 && player < engine.participants.length
                        ? engine.participants[player] : null
            }

            function handFor(player) {
                var value = participant(player)
                return value ? value.hand : []
            }

            function wonFor(player) {
                var value = participant(player)
                return value ? value.wonCards : []
            }

            function nameFor(player) {
                var value = participant(player)
                return value ? value.name : ""
            }

            function scoreFor(player) {
                var value = participant(player)
                return value ? value.score : 0
            }

            function playerCardCenter(handIndex, count) {
                var cardWidth = Theme.itemSizeLarge * 1.4
                var cardHeight = cardWidth * 1.4
                var left = handArea.width / 2
                        - ((count - 1) * cardWidth * 0.3)
                        + handIndex * (cardWidth * 0.6)
                return handArea.mapToItem(animationLayer,
                                          left + cardWidth / 2,
                                          cardHeight / 2)
            }

            function aiSeat(player) {
                if (!engine.teamGame)
                    return aiTopHandArea
                if (player === 1)
                    return aiLeftHandArea
                if (player === 2)
                    return aiTopHandArea
                return aiRightHandArea
            }

            function aiCardCenter(player, handIndex, count) {
                var seat = aiSeat(player)
                var vertical = engine.teamGame && (player === 1 || player === 3)
                var cardWidth = vertical ? Theme.itemSizeMedium : Theme.itemSizeLarge
                var cardHeight = cardWidth * 1.4
                var spacing = vertical ? cardHeight * 0.18 : cardWidth * 0.5
                var handLength = (count - 1) * spacing + (vertical ? cardHeight : cardWidth)
                var x = vertical ? seat.width / 2 : (seat.width - handLength) / 2
                        + handIndex * spacing + cardWidth / 2
                var y = vertical ? (seat.height - handLength) / 2
                        + handIndex * spacing + cardHeight / 2 : cardHeight / 2
                return seat.mapToItem(animationLayer, x, y)
            }

            function aiCardScale(player) {
                if (engine.teamGame && (player === 1 || player === 3))
                    return Theme.itemSizeMedium / (Theme.itemSizeLarge * 1.4)
                return 1.0 / 1.4
            }

            function scatterUnit(cardId, tableIndex, salt) {
                var value = ((tableIndex + 1) * 1103515245 + salt * 12345) >>> 0
                for (var index = 0; index < cardId.length; ++index)
                    value = ((value * 33) ^ cardId.charCodeAt(index)) >>> 0
                return (value % 2001) / 1000.0 - 1.0
            }

            function tableCardOffsetX(cardId, tableIndex) {
                return scatterUnit(cardId, tableIndex, 17) * Theme.paddingLarge * 0.72
            }

            function tableCardOffsetY(cardId, tableIndex) {
                return scatterUnit(cardId, tableIndex, 31) * Theme.paddingLarge * 0.58
                        + tableIndex * 1.5
            }

            function tableCardRotation(cardId, tableIndex) {
                var direction = scatterUnit(cardId, tableIndex, 43) < 0 ? -1 : 1
                return direction * (2 + Math.abs(scatterUnit(cardId, tableIndex, 59)) * 12)
            }

            function tableCardCenter(tableIndex, cardId) {
                return tableRow.mapToItem(animationLayer,
                                          tableCardOffsetX(cardId, tableIndex),
                                          tableCardOffsetY(cardId, tableIndex))
            }

            function wonPileCenter(winnerPlayer) {
                var target = winnerPlayer === 0 ? playerWonPile
                           : winnerPlayer === 1 ? ai1WonPile
                           : winnerPlayer === 2 ? ai2WonPile : ai3WonPile
                return target.mapToItem(animationLayer, target.width / 2, target.height / 2)
            }

            function openWonCards(player) {
                if (player !== 0)
                    return
                var value = participant(player)
                if (!value)
                    return
                pageStack.push(Qt.resolvedUrl("WonCardsPage.qml"), {
                    ownerName: value.name,
                    teamLabel: qsTr("Your captured cards"),
                    cards: value.wonCards,
                    score: value.score,
                    cardStyle: appSettings.cardStyle
                })
            }

            function spawnFlight(cardId, role, start, target, delay,
                                 faceUp, flipMode, startScale, endScale) {
                var cardWidth = Theme.itemSizeLarge * 1.4
                var cardHeight = cardWidth * 1.4
                return flyingCardComponent.createObject(animationLayer, {
                    cardId: cardId,
                    cardStyle: appSettings.cardStyle,
                    flightRole: role,
                    startCenterX: start.x,
                    startCenterY: start.y,
                    targetCenterX: target.x,
                    targetCenterY: target.y,
                    startDelay: delay,
                    flightDuration: dur(role === "pile" ? 420 : 360),
                    faceUp: faceUp,
                    flipMode: flipMode,
                    startScale: startScale,
                    endScale: endScale,
                    x: start.x - cardWidth / 2,
                    y: start.y - cardHeight / 2
                })
            }

            function startCardFlight(cardId, playedBy, oldHandIndex) {
                if (!appSettings.animationsEnabled)
                    return

                activeFlightRole = "table"
                activeFlights = 1
                hiddenTableId = cardId

                var start
                var scale
                if (playedBy === 0) {
                    start = pendingPlayerStartX >= 0 && pendingPlayerStartY >= 0
                            ? Qt.point(pendingPlayerStartX, pendingPlayerStartY)
                            : playerCardCenter(oldHandIndex, engine.playerHand.length + 1)
                    scale = 1.0
                } else {
                    start = aiCardCenter(playedBy, oldHandIndex,
                                         handFor(playedBy).length + 1)
                    scale = aiCardScale(playedBy)
                }
                pendingPlayerStartX = -1
                pendingPlayerStartY = -1

                spawnFlight(cardId,
                            "table",
                            start,
                            tableCardCenter(engine.tableCards.length - 1, cardId),
                            0,
                            playedBy === 0,
                            playedBy !== 0 ? 1 : 0,
                            scale,
                            1.0)
            }

            function startPileFlights(winnerPlayer) {
                if (!appSettings.animationsEnabled)
                    return

                if (activeFlights > 0)
                    clearFlights()
                activeFlightRole = "pile"
                activeFlights = engine.tableCards.length
                hiddenTableId = "*"
                if (activeFlights === 0) {
                    engine.completePileAnimation()
                    return
                }

                var target = wonPileCenter(winnerPlayer)
                for (var index = 0; index < engine.tableCards.length; ++index) {
                    var tableCard = engine.tableCards[index]
                    spawnFlight(tableCard.id,
                                "pile",
                                tableCardCenter(index, tableCard.id),
                                target,
                                index * dur(80),
                                true,
                                2,
                                1.0,
                                0.58)
                }
            }

            function startDealFlights(cards) {
                if (!appSettings.animationsEnabled)
                    return

                if (activeFlights > 0)
                    clearFlights()
                activeFlightRole = "deal"
                activeFlights = cards.length
                hiddenDealIds = ({})
                if (activeFlights === 0) {
                    engine.completeDealAnimation()
                    return
                }

                var start = deckCenter()
                for (var index = 0; index < cards.length; ++index) {
                    var dealt = cards[index]
                    replaceHiddenDeal(dealt.id, true)
                    var playerCard = dealt.player === 0
                    var target = playerCard
                            ? playerCardCenter(dealt.handIndex, engine.playerHand.length)
                            : aiCardCenter(dealt.player, dealt.handIndex,
                                           handFor(dealt.player).length)
                    spawnFlight(dealt.id,
                                "deal",
                                start,
                                target,
                                dealt.order * dur(110),
                                false,
                                playerCard ? 1 : 0,
                                playerCard ? 0.72 : 1.0,
                                playerCard ? 1.0 : aiCardScale(dealt.player))
                }
            }

            function flightFinished(role, cardId) {
                if (role !== activeFlightRole)
                    return

                if (role === "deal")
                    replaceHiddenDeal(cardId, false)

                activeFlights = Math.max(0, activeFlights - 1)
                if (activeFlights !== 0)
                    return

                activeFlightRole = ""
                if (role === "table") {
                    hiddenTableId = ""
                    engine.completeCardAnimation()
                } else if (role === "pile") {
                    hiddenTableId = ""
                    engine.completePileAnimation()
                } else if (role === "deal") {
                    hiddenDealIds = ({})
                    engine.completeDealAnimation()
                }
            }

            function restartGame() {
                clearFlights()
                engine.newGame()
            }

            function requestRestartFromPulley() {
                pulleyRestartPending = true
                pulleyRestartTimer.restart()
            }

            function tryRestartAfterPulley() {
                if (!pulleyRestartPending)
                    return

                // MenuItem.onClicked runs while the SilicaFlickable is still
                // returning from its pulled-down position.  Wait until both
                // the pulley and its motion are finished so mapToItem() sees
                // the normal table geometry before dealing starts.
                if (pulleyMenu.active || flick.moving || flick.dragging || flick.flicking) {
                    pulleyRestartTimer.restart()
                    return
                }

                pulleyRestartPending = false
                restartGame()
            }

            GameEngine {
                id: engine
                playerCount: appSettings.opponentCount === 3 ? 4 : 2
                playerName: appSettings.playerName
                ai1Name: appSettings.ai1Name
                ai2Name: appSettings.ai2Name
                ai3Name: appSettings.ai3Name
                aiPlayDelay: appSettings.aiPlayDelay
                ai1Difficulty: appSettings.ai1Difficulty
                ai2Difficulty: appSettings.ai2Difficulty
                ai3Difficulty: appSettings.ai3Difficulty
                animationsEnabled: appSettings.animationsEnabled
                paused: mainPage.status !== PageStatus.Active
            }

            Connections {
                target: engine

                onCardAnimationRequested: {
                    mainPage.startCardFlight(cardId, playedBy, oldHandIndex)
                }

                onPileAnimationRequested: {
                    mainPage.startPileFlights(winnerPlayer)
                }

                onDealAnimationRequested: {
                    mainPage.startDealFlights(dealtCards)
                }

                onVisualPhaseChanged: {
                    if (engine.visualPhase === 0 && mainPage.activeFlights > 0)
                        mainPage.clearFlights()
                }
            }

            Timer {
                interval: 0
                running: true
                repeat: false
                onTriggered: engine.start()
            }

            Timer {
                id: pulleyRestartTimer
                interval: 50
                repeat: false
                onTriggered: mainPage.tryRestartAfterPulley()
            }

            Item {
                id: animationLayer
                anchors.fill: parent
                z: 1000
            }

            Component {
                id: flyingCardComponent

                Card {
                    id: flyingCard
                    property bool isFlyingCard: true
                    property string flightRole: ""
                    property real startCenterX: 0
                    property real startCenterY: 0
                    property real targetCenterX: 0
                    property real targetCenterY: 0
                    property int startDelay: 0
                    property int flightDuration: 360
                    property int flipMode: 0 // 0 none, 1 face up, 2 face down
                    property real startScale: 1.0
                    property real endScale: 1.0
                    property real flipX: 1.0

                    x: startCenterX - width / 2
                    y: startCenterY - height / 2
                    scale: startScale
                    z: 1000

                    transform: Scale {
                        origin.x: flyingCard.width / 2
                        origin.y: flyingCard.height / 2
                        xScale: flyingCard.flipX
                        yScale: 1.0
                    }

                    Component.onCompleted: flight.start()

                    Timer {
                        id: flipTimer
                        interval: flyingCard.startDelay + flyingCard.flightDuration / 2 - 80
                        repeat: false
                        running: flyingCard.flipMode !== 0
                        onTriggered: flip.start()
                    }

                    SequentialAnimation {
                        id: flip
                        PropertyAnimation {
                            target: flyingCard
                            property: "flipX"
                            to: 0.08
                            duration: 80
                            easing.type: Easing.InQuad
                        }
                        ScriptAction {
                            script: flyingCard.faceUp = flyingCard.flipMode === 1
                        }
                        PropertyAnimation {
                            target: flyingCard
                            property: "flipX"
                            to: 1.0
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }

                    SequentialAnimation {
                        id: flight
                        PauseAnimation { duration: flyingCard.startDelay }
                        ParallelAnimation {
                            NumberAnimation {
                                target: flyingCard
                                property: "x"
                                from: flyingCard.startCenterX - flyingCard.width / 2
                                to: flyingCard.targetCenterX - flyingCard.width / 2
                                duration: flyingCard.flightDuration
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                target: flyingCard
                                property: "y"
                                from: flyingCard.startCenterY - flyingCard.height / 2
                                to: flyingCard.targetCenterY - flyingCard.height / 2
                                duration: flyingCard.flightDuration
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                target: flyingCard
                                property: "scale"
                                to: flyingCard.endScale
                                duration: flyingCard.flightDuration
                                easing.type: Easing.InOutCubic
                            }
                        }
                        ScriptAction {
                            script: {
                                mainPage.flightFinished(flyingCard.flightRole, flyingCard.cardId)
                                flyingCard.destroy()
                            }
                        }
                    }
                }
            }

            SilicaFlickable {
                id: flick
                anchors.fill: parent
                contentHeight: height
                onMovementEnded: mainPage.tryRestartAfterPulley()

                PullDownMenu {
                    id: pulleyMenu
                    onActiveChanged: {
                        if (!active && mainPage.pulleyRestartPending)
                            pulleyRestartTimer.restart()
                    }

                    MenuItem { text: qsTr("New Game"); onClicked: mainPage.requestRestartFromPulley() }
                    MenuItem { text: qsTr("Settings"); onClicked: pageStack.push(Qt.resolvedUrl("Settings.qml"), { settings: appSettings }) }
                    MenuItem {
                        text: qsTr("Game Rules")
                        onClicked: pageStack.push(Qt.resolvedUrl("GameRules.qml"),
                                                  { cardStyle: appSettings.cardStyle })
                    }
                    MenuItem { text: qsTr("About"); onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml")) }
                }

                Item {
                    id: gameRoot
                    width: flick.width
                    height: flick.height

                    Rectangle {
                        id: tableBackground
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: handArea.top

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#0f3d13"
                            border.width: 1
                            opacity: 0.4
                        }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#256d2c" }
                            GradientStop { position: 0.5; color: "#1b5e20" }
                            GradientStop { position: 1.0; color: "#144a18" }
                        }
                    }

                    AiHand {
                        id: aiTopHandArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: Theme.itemSizeLarge * 1.2
                        height: Theme.itemSizeLarge * 1.5
                        z: 1
                        playerName: mainPage.nameFor(engine.teamGame ? 2 : 1)
                        cards: mainPage.handFor(engine.teamGame ? 2 : 1)
                        cardStyle: appSettings.cardStyle
                        hiddenCardIds: mainPage.hiddenDealIds
                        activeTurn: engine.turnPlayer === (engine.teamGame ? 2 : 1)
                    }

                    AiHand {
                        id: aiLeftHandArea
                        visible: engine.teamGame
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -Theme.itemSizeLarge * 0.3
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge * 3.0
                        vertical: true
                        playerName: mainPage.nameFor(1)
                        cards: mainPage.handFor(1)
                        cardStyle: appSettings.cardStyle
                        hiddenCardIds: mainPage.hiddenDealIds
                        activeTurn: engine.turnPlayer === 1
                        z: 1
                    }

                    AiHand {
                        id: aiRightHandArea
                        visible: engine.teamGame
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -Theme.itemSizeLarge * 0.3
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge * 3.0
                        vertical: true
                        playerName: mainPage.nameFor(3)
                        cards: mainPage.handFor(3)
                        cardStyle: appSettings.cardStyle
                        hiddenCardIds: mainPage.hiddenDealIds
                        activeTurn: engine.turnPlayer === 3
                        z: 1
                    }

                    WonPile {
                        id: ai1WonPile
                        anchors.top: engine.teamGame ? aiLeftHandArea.bottom : aiTopHandArea.bottom
                        anchors.left: parent.left
                        anchors.topMargin: Theme.paddingMedium
                        anchors.leftMargin: engine.teamGame
                                            ? mainPage.wonPileEdgeMargin
                                            : Theme.paddingLarge
                        width: Theme.itemSizeMedium
                        height: width * 1.4
                        z: 0.5
                        playerName: mainPage.nameFor(1)
                        cards: mainPage.wonFor(1)
                        score: mainPage.scoreFor(1)
                        cardStyle: appSettings.cardStyle
                        accentColor: "#ffb74d"
                    }

                    WonPile {
                        id: ai2WonPile
                        visible: engine.teamGame
                        anchors.top: aiTopHandArea.bottom
                        anchors.left: ai1WonPile.left
                        anchors.topMargin: Theme.paddingMedium
                        width: Theme.itemSizeMedium
                        height: width * 1.4
                        z: 0.5
                        playerName: mainPage.nameFor(2)
                        cards: mainPage.wonFor(2)
                        score: mainPage.scoreFor(2)
                        cardStyle: appSettings.cardStyle
                        accentColor: "#66bb6a"
                    }

                    WonPile {
                        id: ai3WonPile
                        visible: engine.teamGame
                        anchors.top: aiTopHandArea.bottom
                        anchors.right: playerWonPile.right
                        anchors.topMargin: Theme.paddingMedium
                        width: Theme.itemSizeMedium
                        height: width * 1.4
                        z: 0.5
                        playerName: mainPage.nameFor(3)
                        cards: mainPage.wonFor(3)
                        score: mainPage.scoreFor(3)
                        cardStyle: appSettings.cardStyle
                        accentColor: "#ef5350"
                    }

                    Item {
                        id: deckArea
                        anchors.right: parent.right
                        anchors.rightMargin: engine.teamGame
                                             ? Theme.itemSizeLarge * 1.45
                                             : Theme.paddingLarge * 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -height * 1.4
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge * 1.4
                        z: 0.8

                        Repeater {
                            model: Math.min(engine.deckSize, 5)
                            delegate: Card {
                                cardId: "0_7"
                                cardStyle: appSettings.cardStyle
                                faceUp: false
                                width: Theme.itemSizeLarge
                                height: Theme.itemSizeLarge * 1.4
                                x: index * 2
                                y: index * 2
                                z: -index
                                opacity: 0.85
                                scale: index === 0 ? 1.0 : 0.96
                            }
                        }
                    }

                    Item {
                        id: deckDealPoint
                        width: 1
                        height: 1
                        anchors.horizontalCenter: deckArea.horizontalCenter
                        anchors.verticalCenter: deckArea.verticalCenter
                    }

                    Item {
                        id: tableRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 1

                        Repeater {
                            model: engine.tableCards
                            delegate: Card {
                                cardId: modelData.id
                                cardStyle: appSettings.cardStyle
                                faceUp: true
                                x: -width / 2 + mainPage.tableCardOffsetX(modelData.id, index)
                                y: -height / 2 + mainPage.tableCardOffsetY(modelData.id, index)
                                rotation: mainPage.tableCardRotation(modelData.id, index)
                                z: index
                                opacity: mainPage.hiddenTableId === "*"
                                         || mainPage.hiddenTableId === modelData.id ? 0.0 : 1.0
                            }
                        }
                    }

                    WonPile {
                        id: playerWonPile
                        anchors.bottom: handArea.top
                        anchors.right: handArea.right
                        anchors.bottomMargin: Theme.paddingMedium
                        anchors.rightMargin: mainPage.wonPileEdgeMargin
                        width: Theme.itemSizeMedium
                        height: width * 1.4
                        z: 0.5
                        playerName: mainPage.nameFor(0)
                        cards: mainPage.wonFor(0)
                        score: mainPage.scoreFor(0)
                        cardStyle: appSettings.cardStyle
                        accentColor: "#66bb6a"
                        inspectable: true
                        onClicked: mainPage.openWonCards(0)
                    }

                    Item {
                        id: handArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.paddingLarge
                        height: Theme.itemSizeLarge * 2
                        z: 1
                        enabled: engine.roundResult.length === 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paddingLarge
                            color: Theme.highlightColor
                            opacity: engine.playerInputEnabled ? 0.12 : 0.04
                            z: -1
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }

                        Repeater {
                            model: engine.playerHand
                            delegate: MouseArea {
                                id: playerMouse
                                property int count: engine.playerHand.length
                                property real cardWidth: Theme.itemSizeLarge * 1.4
                                property real cardHeight: cardWidth * 1.4
                                width: cardWidth
                                height: cardHeight
                                x: handArea.width / 2
                                   - ((count - 1) * cardWidth * 0.3)
                                   + index * (cardWidth * 0.6)
                                y: 0
                                z: index
                                // The explicit property read makes this binding
                                // re-evaluate when stateChanged releases the deal
                                // phase.  An invokable call alone has no QML
                                // dependency and remained false after initial deal.
                                enabled: engine.playerInputEnabled
                                         && engine.isPlayerCardPlayable(index)
                                         && !mainPage.hiddenDealIds[modelData.id]

                                onClicked: {
                                    // Copy primitive coordinates before playCard()
                                    // changes the hand model and destroys this delegate.
                                    var scenePoint = playerMouse.mapToItem(
                                                null, width / 2, height / 2)
                                    var startPoint = animationLayer.mapFromItem(
                                                null, scenePoint.x, scenePoint.y)
                                    mainPage.pendingPlayerStartX = startPoint.x
                                    mainPage.pendingPlayerStartY = startPoint.y
                                    engine.playCard(index)
                                }
                                onPressed: playerCard.pressed = true
                                onReleased: playerCard.pressed = false
                                onCanceled: playerCard.pressed = false

                                Card {
                                    id: playerCard
                                    cardId: modelData.id
                                    cardStyle: appSettings.cardStyle
                                    faceUp: true
                                    opacity: mainPage.hiddenDealIds[modelData.id] ? 0.0 : 1.0
                                }
                            }
                        }
                    }

                    Button {
                        text: qsTr("Let it go")
                        anchors.horizontalCenter: handArea.horizontalCenter
                        anchors.bottom: handArea.top
                        anchors.bottomMargin: Theme.paddingLarge
                        visible: engine.canLeave
                        enabled: engine.canLeave
                        onClicked: engine.playerLeave()
                        z: 50
                    }
                }

                Label {
                    id: statusLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingMedium
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    horizontalAlignment: Text.AlignHCenter
                    text: engine.teamGame
                          ? engine.status + "\n" + qsTr("Your team %1  •  Opponents %2")
                            .arg(engine.teamScore).arg(engine.opponentScore)
                          : engine.status
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.secondaryColor
                    z: 100
                }

                Label {
                    id: lastTrickLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: statusLabel.bottom
                    anchors.topMargin: Theme.paddingSmall
                    text: engine.lastTrick
                    visible: opacity > 0 && text.length > 0
                    opacity: text.length > 0 ? 1.0 : 0.0
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.highlightColor
                    z: 100

                    onTextChanged: {
                        if (text.length > 0) {
                            lastTrickLabel.opacity = 1.0
                            hideLastTrick.restart()
                        }
                    }
                    Timer {
                        id: hideLastTrick
                        interval: 2000
                        repeat: false
                        onTriggered: lastTrickLabel.opacity = 0.0
                    }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                Item {
                    id: roundResultPanel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Theme.itemSizeLarge * 0.5
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    height: resultContent.height + 2 * Theme.paddingLarge
                    visible: engine.roundResult.length > 0
                    z: 100

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingLarge
                        color: "#cc123716"
                        border.color: Theme.highlightColor
                        border.width: 1
                    }

                    Column {
                        id: resultContent
                        anchors.centerIn: parent
                        width: parent.width - 2 * Theme.paddingLarge
                        spacing: Theme.paddingLarge

                        Label {
                            id: roundResultLabel
                            width: parent.width
                            text: engine.roundResult
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: Theme.highlightColor
                        }

                        Button {
                            text: qsTr("New Game")
                            anchors.horizontalCenter: parent.horizontalCenter
                            highlighted: true
                            onClicked: mainPage.restartGame()
                        }
                    }
                }
            }
        }
    }
}

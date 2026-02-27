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
        property int aiPlayDelay: 650
        property int tableFlightDuration: 500
        property string cardStyle: "Piatnik"
        property string ai1Name: "AI 1"
        property string ai2Name: "AI 2"

        // persisted UI state
        property bool cardStyleExpanded: true
        property bool animationsExpanded: false
        property bool namesExpanded: false
    }

    cover: Component {
        CoverPage { }
    }

    initialPage: Component
    {
        Page {
            id: mainPage

            // Declarations ---------------------------
            property int lastTableCount: 0
            property var lastTableSnapshot: ([])
            property bool initialDeal: true
            property var seenPlayerIds: ({})
            property var seenAiIds: ({})
            property bool freshRound: true   // optional; used to animate first hand nicely
            property int trickResolveDelay: 700   // Delay before resiolving the trick in ms
            property string phase: "idle"          // "toTable" | "pause" | "toPile"
            property bool playerCardLanded: false
            property bool aiCardLanded: false
            property bool aiFlyingActive: false
            property string hideAiStaticId: ""
            property bool dealingPaused: false
            property int pileFlightsInProgress: 0
            property bool pendingTrickResolve: false
            property int tableFlightDuration:
                Math.round(500 / appSettings.tableFlightDuration)
            property int pileFlightDuration: 500   // ms (same animation, different target)
            property string ai1Name: appSettings.ai1Name

            function resetSeen() {
                seenPlayerIds = ({})
                seenAiIds = ({})
                freshRound = true
            }

            GameEngine {
                id: engine
                aiPlayDelay: appSettings.aiPlayDelay
            }

            Item {
                id: animationLayer
                anchors.fill: parent
                z: 10
            }

            Component.onCompleted: {
                // Run twice: first callLater is often still before anchors settle,
                // second callLater runs after the next polish pass.
                updateAllDealOriginsTimer.restart()
            }

            Timer {
                id: updateAllDealOriginsTimer
                interval: 0
                repeat: false
                onTriggered: {
                    updateAllDealOrigins()
                    updateAllDealOriginsTimer2.restart()
                }
            }

            Timer {
                id: updateAllDealOriginsTimer2
                interval: 0
                repeat: false
                onTriggered: updateAllDealOrigins()
            }

            // Prevent "vibration": delay hand deal animations right after pile capture flights
            Timer {
                id: dealResumeTimer
                interval: 750
                repeat: false
                onTriggered: mainPage.dealingPaused = false
            }


            // Helper functions ---------------------------
            function updateAllDealOrigins() {
                if (handArea) handArea.updateDealOrigin()
                if (aiHandArea) aiHandArea.updateDealOrigin()
            }

            function playerWonCurrentTrick() {
                // Determine winner from the full table according to the engine rule:
                // cardToHit = first card rank; any card with (rank==cardToHit || rank==7) is a hit.
                // Winner is the player who played the LAST hit in the pile.
                if (engine.tableCards.length < 2)
                    return true  // fallback (should not happen in a valid pile)

                var cardToHit = engine.tableCards[0].rank
                var lastHitterPlayedBy = engine.tableCards[0].playedBy

                for (var i = 1; i < engine.tableCards.length; ++i) {
                    var c = engine.tableCards[i]
                    if (c.rank === cardToHit || c.rank === 7)
                        lastHitterPlayedBy = c.playedBy
                }

                return lastHitterPlayedBy === 0
            }


            function spawnFlyingCard(cardId, startPos) {
                // New trick begins
                phase = "toTable"
                playerCardLanded = false
                aiCardLanded = false

                var c = flyingCardComponent.createObject(animationLayer, {
                    cardId: cardId,
                    faceUp: true,
                    flightRole: "playerToTable",
                    flightDuration: tableFlightDuration,
                    startScale: 1.0,
                    endScale: 1.0,
                    x: startPos.x,
                    y: startPos.y,
                    z: 1000,
                    opacity: 1.0
                })

                c.flyToTable()
            }

            function spawnAIFlyingCard(cardId) {
                mainPage.aiFlyingActive = true
                mainPage.hideAiStaticId = cardId
                var start = aiHandArea.mapToItem(animationLayer,
                                                 aiHandArea.width / 2,
                                                 aiHandArea.height / 2)

                var c = flyingCardComponent.createObject(animationLayer, {
                    cardId: cardId,
                    faceUp: false,
                    flipToFaceUpOnTable: true,
                    flightRole: "aiToTable",
                    flightDuration: tableFlightDuration,
                    startScale: 1.0,
                    endScale: 1.0,
                    x: start.x,
                    y: start.y,
                    z: 1000,
                    opacity: 1.0
                })

                c.flyToTable()
            }

            function animateTableCardsToWinner() {
                if (engine.tableCards.length < 2)
                    return

                var playerWon = playerWonCurrentTrick()
                var target = playerWon ? playerWonDealPoint : aiWonDealPoint

                mainPage.pileFlightsInProgress = engine.tableCards.length

                for (var i = 0; i < engine.tableCards.length; ++i) {
                    var card = engine.tableCards[i]

                    var start = tableDealPoint.mapToItem(animationLayer,
                                                         (i === 0 ? -Theme.paddingLarge : Theme.paddingLarge),
                                                         -Theme.paddingMedium)

                    var c = flyingCardComponent.createObject(animationLayer, {
                        cardId: card.id,
                        faceUp: true,                  // always start faceUp
                        wonByPlayer: playerWon,
                        shouldFlipMidFlight: true,     // always flip mid-flight
                        flightRole: "toPile",
                        flightDuration: pileFlightDuration,
                        startScale: 1.0,
                        endScale: 0.5,
                        x: start.x,
                        y: start.y,
                        z: 900
                    })

                    c.flyToPoint(target)
                }
            }
            function animateTableCardsToWinnerFrom(cards) {
                if (!cards || cards.length < 2)
                    return
                mainPage.dealingPaused = true
                dealResumeTimer.restart()

                // Winner = last hitter in this pile (same logic as playerWonCurrentTrick but using snapshot)
                var cardToHit = cards[0].rank
                var lastHitterPlayedBy = cards[0].playedBy
                for (var i = 1; i < cards.length; ++i) {
                    var cc = cards[i]
                    if (cc.rank === cardToHit || cc.rank === 7)
                        lastHitterPlayedBy = cc.playedBy
                }
                var playerWon = (lastHitterPlayedBy === 0)
                var target = playerWon ? playerWonDealPoint : aiWonDealPoint

                for (var j = 0; j < cards.length; ++j) {
                    var card = cards[j]
                    var start = tableDealPoint.mapToItem(animationLayer,
                        (j === 0 ? -Theme.paddingLarge : Theme.paddingLarge),
                        -Theme.paddingMedium)

                    var f = flyingCardComponent.createObject(animationLayer, {
                        cardId: card.id,
                        faceUp: true,
                        wonByPlayer: playerWon,
                        shouldFlipMidFlight: true,
                        flightRole: "toPile",
                        flightDuration: pileFlightDuration,
                        startScale: 1.0,
                        endScale: 0.5,
                        x: start.x,
                        y: start.y,
                        z: 900
                    })
                    f.flyToPoint(target)
                }
            }
            Component {
                id: flyingCardComponent

                Card {
                    id: flyingCard
                    faceUp: false
                    z: 1000
                    opacity: 1.0

                    property bool wonByPlayer: false
                    property real startScale: 1.0
                    property real endScale: 1.0   // match the pile card scale
                    scale: startScale
                    property bool shouldFlipMidFlight: false
                    property int flightDuration: 500   // must match x/y animation duration
                    property bool flipToFaceUpOnTable: false
                    property string flightRole: ""   // "playerToTable" | "aiToTable" | "toPile"

// Debug & show flying cards
//                    console.warn("AI FLY SPAWN", cardId)
//                    Rectangle {
//                        anchors.fill: parent
//                        color: "yellow"
//                        opacity: 0.25
//                        z: 1
//                    }

                    transform: Rotation {
                        id: flip
                        origin.x: flyingCard.width / 2
                        origin.y: flyingCard.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: 0
                    }

                    function flyToTable() {
                        if (flipToFaceUpOnTable) {
                            midFlipTimer.start()
                        }

                        var target = tableDealPoint.mapToItem(animationLayer, 0, 0)

                        xAnim.to = target.x
                        yAnim.to = target.y
                        flyAnim.start()

                    }

                    function flyToPoint(targetItem) {
                        var target = targetItem.mapToItem(animationLayer, 0, 0)
                        xAnim.to = target.x
                        yAnim.to = target.y
                        flyAnim.start()
                        // ONLY player-won cards flip mid-air
                        if (wonByPlayer && shouldFlipMidFlight) {
                            midFlipTimer.start()
                        }
                    }

                    Timer {
                        id: midFlipTimer
                        interval: flightDuration / 2
                        repeat: false
                        onTriggered: {
                            if (flipToFaceUpOnTable) flipUpAnim.start()
                            else flipAnim.start() // flip-to-face-down for pile
                        }
                    }

                    ParallelAnimation {
                        id: flyAnim

                        PropertyAnimation {
                            id: xAnim
                            target: flyingCard
                            property: "x"
                            duration: flyingCard.flightDuration
                            easing.type: Easing.OutCubic
                        }

                        PropertyAnimation {
                            id: yAnim
                            target: flyingCard
                            property: "y"
                            duration: flyingCard.flightDuration
                            easing.type: Easing.OutCubic
                        }

                        PropertyAnimation {
                            target: flyingCard
                            property: "scale"
                            to: flyingCard.endScale
                            duration: 500   // match your flight duration
                            easing.type: Easing.OutCubic
                        }

                        onStopped: {
                            // 1) Landing on table
                            if (flyingCard.flightRole === "playerToTable") {
                                mainPage.playerCardLanded = true
                            } else if (flyingCard.flightRole === "aiToTable") {
                                mainPage.aiCardLanded = true
                                mainPage.aiFlyingActive = false
                               mainPage.hideAiStaticId = ""
                            }
                            // When BOTH landed: show real table cards and start the pause timer
                            if (mainPage.phase === "toTable" &&
                                mainPage.playerCardLanded &&
                                mainPage.aiCardLanded &&
                                mainPage.pendingTrickResolve) {

                                mainPage.phase = "pause"
                                mainPage.pendingTrickResolve = false
                                resolveTrickTimer.restart()   // this is your trickResolveDelay pause
                            }

                            // 2) Flying to winner pile
                            if (flyingCard.flightRole === "toPile") {
                                mainPage.pileFlightsInProgress--
                                if (mainPage.pileFlightsInProgress === 0) {
                                    // engine.resolveCurrentTrick()  // removed: engine resolves internally
                                    mainPage.phase = "idle"
                                }
                            }

                            flyingCard.destroy()
                        }

                    }

                    SequentialAnimation {
                        id: flipAnim

                        PropertyAnimation {
                            target: flip
                            property: "angle"
                            from: 0
                            to: 90
                            duration: 80
                            easing.type: Easing.InQuad
                        }

                        ScriptAction {
                            script: flyingCard.faceUp = false
                        }

                        PropertyAnimation {
                            target: flip
                            property: "angle"
                            from: 90
                            to: 0
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }

                    SequentialAnimation {
                        id: flipUpAnim

                        PropertyAnimation {
                            target: flip
                            property: "angle"
                            from: 0
                            to: 90
                            duration: 80
                            easing.type: Easing.InQuad
                        }

                        ScriptAction {
                            script: flyingCard.faceUp = true
                        }

                        PropertyAnimation {
                            target: flip
                            property: "angle"
                            from: 90
                            to: 0
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
            
            // VISUAL / SCROLLABLE CONTENT ---------------------------
            SilicaFlickable {
                id: flick
                anchors.fill: parent
                contentHeight: height
                
                // Pulley menu ---------------------------
                PullDownMenu {
                    MenuItem {
                        text: "New Game"
                        onClicked: {
                            mainPage.resetSeen()
                            engine.newGame()
                        }
                    }

                    MenuItem {
                        text: "Restart Round"
                        onClicked: {
                            mainPage.resetSeen()
                            engine.newGame()   // or engine.restartRound() later
                        }
                    }

                    MenuItem {
                        text: "Settings"
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("Settings.qml"), { settings: appSettings })
                        }
                    }

                    MenuItem {
                        text: "Game Rules"
                        onClicked: pageStack.push(Qt.resolvedUrl("GameRules.qml"))
                    }

                    MenuItem {
                        text: "About"
                        onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                    }
                }
                
                // Table background ---------------------------        
                Item {
                    id: gameRoot
                    width: flick.width
                    height: flick.height

                    // Table background ---------------------------
                    Rectangle {
                        id: tableBackground
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            bottom: handArea.top
                        }
//                        color: "#1b5e20"   // dark green felt
                        Rectangle {
                            anchors.fill: tableBackground
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
//------------------------------------------------------------------------------------
//-            SilicaFlickable {
//-                anchors.fill: parent
//-                contentHeight: height

//---PullDownMenu
//---statusLabel
//---lastTrickLabel
//---scoreRow
//---roundResultLabel

//-                Button {
//-                    text: "New Game"
//-                    anchors.horizontalCenter: parent.horizontalCenter
//-                    anchors.top: roundResultLabel.bottom
//-                    anchors.topMargin: Theme.paddingLarge
//-                    highlighted: true
//-                    visible: engine.roundResult.length > 0
//-                    onClicked: engine.newGame()
//-                }
//-            }
//------------------------------------------------------------------------------------
                    // AI won pile target
                    Item {
                        id: aiWonDealPoint
                        width: 1
                        height: 1
                        anchors.left: aiWonPile.left
                        anchors.top: aiWonPile.top
// Debug Visual AI pile
//                        Rectangle {
//                            width: aiWonPile.width
//                            height: aiWonPile.height
//                            color: "red"
//                        }
                    }

                    // Player won pile target
                    Item {
                        id: playerWonDealPoint
                        width: 1
                        height: 1
                        anchors.left: playerWonPile.left
                        anchors.top: playerWonPile.top
// Debug Visual player pile
//                        Rectangle {
//                            width: 100
//                            height: 100
//                            color: "red"
//                        }
                    }

                    /* =========================
                       WON CARDS – AI
                       ========================= */
                    Item {
                        id: aiWonPile
                        anchors.top: aiHandArea.bottom
                        anchors.left: aiHandArea.left
                        anchors.topMargin: Theme.paddingMedium
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge * 1.4
                        z: 0.5

                        // AI won card pile area
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paddingSmall
                            color: "#2979ff"
                            opacity: 0.06
                            z: -2
                        }

                        Repeater {
                            model: engine.cpuWonCards

                            delegate: Card {
                                cardId: modelData.id
                                faceUp: false
                                width: Theme.itemSizeLarge * 0.8
                                height: Theme.itemSizeLarge * 1.12
                                x: index * 2
                                y: index * 2
                                z: index
                                scale: 0.9
                                rotation: (index % 2 === 0 ? 2 : -2) * Math.min(index, 3)
                                transformOrigin: Item.Center
                                opacity: index >= model.count - 3 ? 1.0 : 0.6

                                Behavior on x { NumberAnimation { duration: 200 } }
                                Behavior on y { NumberAnimation { duration: 200 } }
                                Behavior on rotation { NumberAnimation { duration: 200 } }
                            }
                        }
                    }

                    /* =========================
                       AI HAND AREA (top)
                       ========================= */
                    Item {
                        id: aiHandArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: Theme.itemSizeLarge * 1.2
                        height: Theme.itemSizeLarge * 1.5
                        z: 1

                        // AI deal origin
                        property point dealOrigin: Qt.point(0, 0)

                        function updateDealOrigin() {
                            var p = deckDealPoint.mapToItem(aiHandArea, 0, 0)
                            dealOrigin = Qt.point(p.x, p.y)
                        }

                        Component.onCompleted: {
                            // let anchors settle first
                            updateDealOriginTimerAI.restart()
                        }

                        Timer {
                            id: updateDealOriginTimerAI
                            interval: 0
                            repeat: false
                            onTriggered: aiHandArea.updateDealOrigin()
                        }
                        Connections {
                            target: deckArea
                            onXChanged: aiHandArea.updateDealOrigin()
                            onYChanged: aiHandArea.updateDealOrigin()
                            onWidthChanged: aiHandArea.updateDealOrigin()
                            onHeightChanged: aiHandArea.updateDealOrigin()
                        }

                        Repeater {
                            model: engine.cpuHand

                            delegate: Card {
                                id: aiCard
                                cardId: modelData.id
                                faceUp: false

                                // Small AI card size - match with deck size
                                width: Theme.itemSizeLarge
                                height: Theme.itemSizeLarge * 1.4

                                property int count: engine.cpuHand.length
                                property real spacing: width * 0.5
                                property real handWidth: (count - 1) * spacing + width

                                property bool bornAtDeck: (!mainPage.dealingPaused && !mainPage.seenAiIds[modelData.id])
                                property int dealDelay: index * 220
                                property real finalX: (aiHandArea.width - handWidth) / 2 + index * spacing
                                property real finalY: 0

                                property real dealOffsetX: 0
                                property real dealOffsetY: 0

                                x: finalX + dealOffsetX
                                y: finalY + dealOffsetY

                                opacity: 0.9

                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                Behavior on y {
                                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                }

                                Component.onCompleted: {
                                    mainPage.seenAiIds[modelData.id] = true

                                    if (bornAtDeck) {
                                        dealTimer.start()
                                    } else {
                                        bornAtDeck = false
                                    }
                                }

                                Timer {
                                    id: dealTimer
                                    interval: dealDelay
                                    repeat: false
                                    onTriggered: {
                                        // Start position = centered on dealOrigin
                                        dealOffsetX = (aiHandArea.dealOrigin.x - width / 2) - finalX
                                        dealOffsetY = (aiHandArea.dealOrigin.y - height / 2) - finalY

                                        dealAnim.restart()
                                    }
                                }

                                ParallelAnimation {
                                    id: dealAnim

                                    PropertyAnimation {
                                        target: aiCard
                                        property: "dealOffsetX"
                                        to: 0
                                        duration: 260
                                        easing.type: Easing.OutCubic
                                    }

                                    PropertyAnimation {
                                        target: aiCard
                                        property: "dealOffsetY"
                                        to: 0
                                        duration: 260
                                        easing.type: Easing.OutCubic
                                    }

                                    onStopped: bornAtDeck = false
                                }
                            }
                        }
                    }

                    Item {
                        id: deckArea
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingLarge * 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -deckArea.height * 1.4

                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge * 1.4
                        z: 0.8

                        Repeater {
                            model: Math.min(engine.deckSize, 5)

                            delegate: Card {
                                id: deckCard
                                faceUp: false
                                cardId: "0_0"   // dummy, never shown because faceUp=false

                                // Small size deck
                                width: Theme.itemSizeLarge
                                height: Theme.itemSizeLarge * 1.4

                                x: index * 2
                                y: index * 2
                                z: -index
                                opacity: 0.85
                                scale: index === 0 ? 1.0 : 0.96   // only stack cards are smaller
                            }
                        }

// Card counter on Deck
//                        Label {
//                            anchors.top: deckArea.top
//                            anchors.horizontalCenter: deckArea.horizontalCenter
//                            text: "Deck: " + engine.deckSize
//                            font.pixelSize: Theme.fontSizeTiny
//                            color: Theme.secondaryColor
//                        }
                    }

                    // Deck deal point “marker”
                    Item {
                        id: deckDealPoint
                        width: 1
                        height: 1
                        z: deckArea.z + 1

                        // exact center of the top visible card in the deck stack
                        anchors.horizontalCenter: deckArea.horizontalCenter
                        anchors.verticalCenter: deckArea.verticalCenter
                    }

                    // Table deal point "marker"
                    Item {
                        id: tableDealPoint
                        width: 1
                        height: 1
                        z: tableBackground.z + 1
                        anchors.horizontalCenter: tableBackground.horizontalCenter
                        anchors.verticalCenter: tableBackground.verticalCenter
                    }

                    /* =========================
                       TABLE AREA (center)
                       ========================= */
                    Item {
                        id: tableRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 1
                        z: 0

                        onChildrenChanged: {
                            if (children.length === 2) {
                                // Cards just landed → wait briefly
                                exitTimer.restart()
                            }
                        }

                        Connections {
                            target: engine

                            onStateChanged: {
                                var len = engine.tableCards.length
                                if (len > 0)
                                    lastTableSnapshot = engine.tableCards.slice(0)
                                if (len > lastTableCount) {
                                    var last = engine.tableCards[len - 1]
                                    if (last.playedBy === 1) {
                                        spawnAIFlyingCard(last.id)
                                    }
                                } else if (len === 0 && lastTableCount > 0) {
                                    // Table cleared: animate capture from snapshot
                                    animateTableCardsToWinnerFrom(lastTableSnapshot)
                                }
                                lastTableCount = len
                            }
                        }

                        Repeater {
                            model: engine.tableCards

                            delegate: Card {
                                id: tableCard
                                cardId: modelData.id
                                faceUp: true

                                // Stacking + layout for up to 4 cards
                                z: index

                                // Slight fan/stack so later cards are visible
                                x: (index % 2 === 0 ? -1 : 1) * Theme.paddingLarge * 0.6
                                y: -height / 2 - index * Theme.paddingSmall * 0.55
                                rotation: (index % 2 === 0 ? -1 : 1) * (4 + index * 1.5)

                                // Hide the newest AI table card while its flying clone is animating
                                opacity: (modelData.playedBy === 1 && mainPage.aiFlyingActive && modelData.id === mainPage.hideAiStaticId) ? 0.0 : 1.0

                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    Timer {
                        id: exitTimer
                        interval: 350
                        repeat: false
                        onTriggered: {
                            // Trigger exit animation on all table cards
                            for (var i = 0; i < tableRow.children.length; ++i) {
                                var c = tableRow.children[i]
                                if (c && c.objectName === "tableCard") {
                                    c.exiting = true
                                }
                            }
                        }
                    }

                    Timer {
                        id: resolveTrickTimer
                        interval: mainPage.trickResolveDelay
                        repeat: false
                        onTriggered: {
                            // Delay is over, NOW fly table cards to the winner pile
                            mainPage.phase = "toPile"
                            animateTableCardsToWinner()
                            // Do NOT call engine.resolveCurrentTrick() here anymore.
                            // That happens when pile flights finish.
                        }
                    }

                    /* =========================
                       WON CARDS – PLAYER
                       ========================= */
                    Item {
                        id: playerWonPile
                        anchors.bottom: handArea.top
                        anchors.right: handArea.right
                        anchors.bottomMargin: Theme.paddingMedium
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge * 1.4
                        z: 0.5

                        // Playe won cards pile area
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paddingSmall
                            color: "#00c853"
                            opacity: 0.08
                            z: -2
                        }
                        Repeater {
                            model: engine.playerWonCards

                            delegate: Card {
                                cardId: modelData.id
                                faceUp: false
                                width: Theme.itemSizeLarge * 0.8
                                height: Theme.itemSizeLarge * 1.12
                                x: index * 2
                                y: index * 2
                                z: index
                                scale: 0.9
                                rotation: (index % 2 === 0 ? -2 : 2) * Math.min(index, 3)
                                transformOrigin: Item.Center
                                opacity: index >= model.count - 3 ? 1.0 : 0.6

                                Behavior on x { NumberAnimation { duration: 200 } }
                                Behavior on y { NumberAnimation { duration: 200 } }
                                Behavior on rotation { NumberAnimation { duration: 200 } }
                            }
                        }
                    }


                    /* =========================
                       PLAYER HAND (bottom)
                       ========================= */
                    Item {
                        id: handArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.paddingLarge
                        height: Theme.itemSizeLarge * 2
                        z: 1
                        clip: false
                        enabled: engine.roundResult.length === 0
                        scale: engine.status === "Your turn" ? 1.0 : 0.98

                        property point dealOrigin: Qt.point(0, 0)

                        function updateDealOrigin() {
                            // Step 1: deck top → scene (Player deal origin)
                            // Step 2: scene → handArea
                            var scenePos = deckDealPoint.mapToItem(null, 0, 0)
                            dealOrigin = handArea.mapFromItem(null, scenePos.x, scenePos.y)
                        }

                        Component.onCompleted: {
                            // wait one frame so deckArea has final geometry
                            updateDealOriginTimerPlayer.restart()
                        }

                        Timer {
                            id: updateDealOriginTimerPlayer
                            interval: 0
                            repeat: false
                            onTriggered: handArea.updateDealOrigin()
                        }
                        Connections {
                            target: deckArea
                            onXChanged: handArea.updateDealOrigin()
                            onYChanged: handArea.updateDealOrigin()
                            onWidthChanged: handArea.updateDealOrigin()
                            onHeightChanged: handArea.updateDealOrigin()
                        }

                        Connections {
                            target: engine
                            onStateChanged: {
                                if (engine.playerHand.length === 4) {
                                }
                            }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        opacity: engine.roundResult.length > 0
                                 ? 0.4
                                 : (engine.status === "Your turn" ? 1.0 : 0.85)

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }

// Visual debug
//                        Rectangle {
//                            width: 10; height: 10
//                            radius: 5
//                            color: "red"
//                            x: handArea.dealOrigin.x - 5
//                            y: handArea.dealOrigin.y - 5
//                            z: 10
//                        }

                        Rectangle {
                            id: handHighlight
                            anchors.fill: parent
                            radius: Theme.paddingLarge
                            color: Theme.highlightColor
                            opacity: engine.status === "Your turn" ? 0.12 : 0.04
                            z: -1

                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }
                        }

                        Repeater {
                            model: engine.playerHand

                            delegate: MouseArea {
                                id: mouseArea

                                enabled: engine.playerInputEnabled &&
                                         (!engine.canLeave || modelData.rank === engine.cardToHit || modelData.rank === 7)

                                property int count: engine.playerHand.length
                                property real centerIndex: (count - 1) / 2
                                property real distanceFromCenter: Math.abs(index - centerIndex)
                                property real spacing: card.width * 0.6
                                property real handWidth: (count - 1) * spacing + card.width
                                property bool bornAtDeck: (mainPage.freshRound || (!mainPage.dealingPaused && !mainPage.seenPlayerIds[modelData.id]))
                                property int dealDelay: index * 220
                                property real dealOffsetX: 0
                                property real dealOffsetY: 0
                                property bool isBeingPlayed: false

                                property real finalX: (handArea.width / 2)
                                                     - ((count - 1) * card.width * 0.3)
                                                     + index * (card.width * 0.6)

                                property real finalY: 0

                                width: card.width
                                height: card.height

// center the whole hand
//                                x: (handArea.width - handWidth) / 2 + index * spacing

// show the whole hand at the right
//                                x: (handArea.width / 2)
//                                   - ((count - 1) * card.width * 0.3)
//                                   + index * (card.width * 0.6)

                                // Deal from deck to hand
                                x: bornAtDeck ? (handArea.dealOrigin.x - width/2) : finalX
                                y: bornAtDeck ? (handArea.dealOrigin.y - height/2) : finalY

                                onClicked: {
                                    if (isBeingPlayed) return            // prevent double-tap spam
                                    isBeingPlayed = true                 // hide immediately
                                    var p = mouseArea.mapToItem(animationLayer,
                                                                mouseArea.width / 2,
                                                                mouseArea.height / 2)
                                    spawnFlyingCard(card.cardId, p)
                                    playTimer.start()
                                }

                                onPressed: card.pressed = true
                                onReleased: card.pressed = false
                                onCanceled: card.pressed = false

                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                Behavior on y {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }

                                Component.onCompleted: {
                                    // Mark as seen immediately (persists across model rebuilds)
                                    mainPage.seenPlayerIds[modelData.id] = true

                                    if (bornAtDeck) {
                                        dealOffsetX = handArea.dealOrigin.x - x - width / 2
                                        dealOffsetY = handArea.dealOrigin.y - height / 2
                                        dealTimer.start()
                                    } else {
                                        // Skip animation: snap to final position
                                        bornAtDeck = false
                                    }

                                    // After first hand is created, we are no longer in fresh round
                                    // (this runs multiple times; safe)
                                    mainPage.freshRound = false
                                }

                                Timer {
                                    id: dealTimer
                                    interval: dealDelay
                                    repeat: false
                                    onTriggered: {
                                        if (bornAtDeck) {
                                            card.faceUp = false        // ensure starts faceDown
                                            dealFlipTimer.restart()    // flip halfway through dealAnim
                                        }
                                        dealAnim.restart()
                                    }
                                }

                                Timer {
                                    id: dealFlipTimer
                                    interval: 250               // 500ms deal / 2
                                    repeat: false
                                    onTriggered: dealFlipAnim.start()
                                }

                                Timer {
                                    id: playTimer
                                    interval: 500
                                    repeat: false
                                    onTriggered: engine.playCard(index)
                                }

                                ParallelAnimation {
                                    id: dealAnim

                                    PropertyAnimation {
                                        target: mouseArea
                                        property: "x"
                                        to: mouseArea.finalX
                                        duration: 280
                                        easing.type: Easing.OutCubic
                                    }

                                    PropertyAnimation {
                                        target: mouseArea
                                        property: "y"
                                        to: mouseArea.finalY
                                        duration: 280
                                        easing.type: Easing.OutCubic
                                    }

                                    onStopped: bornAtDeck = false
                                }

                                Card {
                                    id: card
                                    cardId: modelData.id
                                    faceUp: !mouseArea.bornAtDeck   // faceDown during deal, faceUp otherwise

                                    scale: bornAtDeck ? 0.72 : 1.0

                                    property int count: engine.playerHand.length
                                    property real centerIndex: (count - 1) / 2
                                    property real distanceFromCenter: Math.abs(index - centerIndex)

                                    y: 0

                                    opacity: isBeingPlayed ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 80 } }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 260
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    transform: Rotation {
                                        id: dealFlip
                                        origin.x: card.width / 2
                                        origin.y: card.height / 2
                                        axis { x: 0; y: 1; z: 0 }
                                        angle: 0
                                    }

                                    SequentialAnimation {
                                        id: dealFlipAnim
                                        PropertyAnimation {
                                            target: dealFlip
                                            property: "angle"
                                            from: 0
                                            to: 90
                                            duration: 80
                                            easing.type: Easing.InQuad
                                        }
                                        ScriptAction { script: card.faceUp = true }
                                        PropertyAnimation {
                                            target: dealFlip
                                            property: "angle"
                                            from: 90
                                            to: 0
                                            duration: 80
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Let it go button (only when engine offers the choice)
                    Button {
                        id: letGoButton
                        text: qsTr("Let it go")
                        anchors.horizontalCenter: handArea.horizontalCenter
                        anchors.bottom: handArea.top
                        anchors.bottomMargin: Theme.paddingLarge
                        visible: engine && engine.canLeave
                        enabled: engine && engine.canLeave
                        onClicked: engine.playerLeave()
                        z: 50
                    }

                } // end of gameRoot

                
                Label {
                    id: statusLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingMedium

                    text: engine.status
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.secondaryColor

                    Behavior on text {
                        SequentialAnimation {
                            PropertyAnimation { property: "opacity"; to: 0; duration: 80 }
                            PropertyAnimation { property: "opacity"; to: 1; duration: 120 }
                        }
                    }
                }
//------------------------------------------------------------------------------------
                Label {
                    id: lastTrickLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: statusLabel.bottom
                    anchors.topMargin: Theme.paddingSmall
                    property bool playerWon: text.indexOf("You won") === 0
                    property bool cpuWon: text.indexOf("AI won") === 0

                    text: engine.lastTrick
                    visible: text.length > 0

                    font.pixelSize: Theme.fontSizeSmall

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    onTextChanged: {
                        if (text.length > 0) {
                            opacity = 0
                            scale = 1.0
                            appearTimer.restart()
                        }
                    }

                    Timer {
                        id: appearTimer
                        interval: 200    // aligns with score pop
                        repeat: false
                        onTriggered: {
                            lastTrickLabel.opacity = 1
                            hideTimer.restart()
                        }
                    }

                    Timer {
                        id: hideTimer
                        interval: 2000
                        repeat: false
                        onTriggered: lastTrickLabel.opacity = 0
                    }

                    color: playerWon
                           ? Theme.primaryColor
                           : cpuWon
                             ? Theme.secondaryColor
                             : Theme.highlightColor

                    scale: (playerWon || cpuWon) ? 1.05 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
//------------------------------------------------------------------------------------
                Row {
                    id: scoreRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: lastTrickLabel.bottom
                    anchors.topMargin: Theme.paddingSmall
                    spacing: Theme.paddingLarge

                    Label {
                        id: playerScoreLabel
                        text: "You: " + engine.playerScore
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }

                        property int lastScore: engine.playerScore

                        onTextChanged: {
                            if (engine.playerScore > lastScore) {
                                playerScorePop.restart()
                            }
                            lastScore = engine.playerScore
                        }

                        SequentialAnimation {
                            id: playerScorePop

                            PropertyAnimation {
                                target: playerScoreLabel
                                property: "scale"
                                to: 1.15
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                            PropertyAnimation {
                                target: playerScoreLabel
                                property: "scale"
                                to: 1.0
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Label {
                        id: cpuScoreLabel
                        text: appSettings.ai1Name + ": " + engine.cpuScore
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }

                        property int lastScore: engine.cpuScore

                        onTextChanged: {
                            if (engine.cpuScore > lastScore) {
                                cpuScorePop.restart()
                            }
                            lastScore = engine.cpuScore
                        }

                        SequentialAnimation {
                            id: cpuScorePop

                            PropertyAnimation {
                                target: cpuScoreLabel
                                property: "scale"
                                to: 1.15
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                            PropertyAnimation {
                                target: cpuScoreLabel
                                property: "scale"
                                to: 1.0
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
//------------------------------------------------------------------------------------                
                Label {
                    id: roundResultLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: scoreRow.bottom
                    anchors.topMargin: Theme.paddingMedium

                    text: engine.roundResult
                    visible: text.length > 0

                    font.pixelSize: Theme.fontSizeLarge
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    color: Theme.highlightColor

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    scale: text.length > 0 ? 1.1 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
                
                Button {
                    text: "New Game"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: roundResultLabel.bottom
                    anchors.topMargin: Theme.paddingLarge
                    highlighted: true
                    visible: engine.roundResult.length > 0
                    onClicked: engine.newGame()
                }
                
            } // end of SilicaFlickable
        }
    }


}

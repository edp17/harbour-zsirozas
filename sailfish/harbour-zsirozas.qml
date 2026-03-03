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

            property string pendingAiCardId: ""
            property bool dealingPaused: false
            property bool capturePending: false
            property int pileFlightsInProgress: 0
            property bool captureGateTimerFired: true
            property double captureGateStartedAt: 0
            property bool pendingTrickResolve: false
            property int tableFlightDuration: effDur(appSettings.tableFlightDuration, 250)
            property int pileFlightDuration: tableFlightDuration + 250   // ms
            property string ai1Name: appSettings.ai1Name

                        function effDur(v, baseMs) {
                // Backward compatible: older settings may store a small "speed factor" (1..10).
                // If v is small, treat it as a multiplier; otherwise treat it as milliseconds.
                if (v === undefined || v === null) return baseMs;
                if (v <= 0) return baseMs;
                if (v < 50) return v * baseMs;
                return v;
            }

            function dur(baseMs) {
                // Apply the same animation speed scaling as tableFlightDuration.
                return effDur(appSettings.tableFlightDuration, baseMs);
            }

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
                interval: 250
                repeat: false
                onTriggered: {
                    mainPage.captureGateTimerFired = true
                    console.info("[DEAL_GATE] dealResumeTimer fired interval=", interval,
                                 "pileFlightsInProgress=", mainPage.pileFlightsInProgress,
                                 "dealingPaused=", mainPage.dealingPaused)
                    mainPage.tryResumeDealing("timer")
                }
            }



            Timer {
                id: aiSpawnTimer
                interval: 0
                repeat: false
                onTriggered: {
                    if (mainPage.pendingAiCardId !== "") {
                        spawnAIFlyingCard(mainPage.pendingAiCardId)
                        mainPage.pendingAiCardId = ""
                    }
                }
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

            
function scheduleDealResumeAfterCapture(nCards) {
    // Ensure dealing resumes only AFTER capture flights are expected to finish.
    // nCards: number of cards flying from table to winner pile.
    if (nCards === undefined || nCards === null) nCards = 0;

    // Capture flight uses pileFlightDuration with per-card stagger of 80ms.
    var stagger = 80;
    var buffer = dur(320); // small settle time after landing/rotation
    var total = pileFlightDuration + Math.max(0, (nCards - 1)) * stagger + buffer;

    if (total < dur(250)) total = dur(250);

    dealResumeTimer.interval = total;
    dealResumeTimer.restart();
}


function tryResumeDealing(reason) {
    // Resume dealing only when BOTH: capture flights are done AND our time gate has elapsed.
    if (mainPage.pileFlightsInProgress === 0 && mainPage.captureGateTimerFired) {
        if (mainPage.dealingPaused || mainPage.capturePending) {
            console.info('[DEAL_GATE] RESUME dealing (reason=' + reason + ') elapsedMs=', (Date.now() - mainPage.captureGateStartedAt))
        }
        mainPage.dealingPaused = false
        mainPage.capturePending = false
    } else {
        console.info('[DEAL_GATE] keep paused (reason=' + reason + ') timerFired=', mainPage.captureGateTimerFired,
                     ' flights=', mainPage.pileFlightsInProgress)
    }
}

function animateTableCardsToWinner() {
                if (engine.tableCards.length < 2)
                    return

                var playerWon = playerWonCurrentTrick()
                var target = playerWon ? playerWonDealPoint : aiWonDealPoint


                mainPage.dealingPaused = true
                mainPage.capturePending = true
                mainPage.pileFlightsInProgress = engine.tableCards.length

                console.info("[DEAL_GATE] CAPTURE start (live) nCards=", engine.tableCards.length,
                             "tableFlightDuration=", tableFlightDuration,
                             "pileFlightDuration=", pileFlightDuration)

                scheduleDealResumeAfterCapture(engine.tableCards.length);
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
                        startDelay: i * dur(120),
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
                mainPage.capturePending = true
                mainPage.pileFlightsInProgress = cards.length

                console.info("[DEAL_GATE] CAPTURE start (snapshot) nCards=", cards.length,
                             "tableFlightDuration=", tableFlightDuration,
                             "pileFlightDuration=", pileFlightDuration)

                scheduleDealResumeAfterCapture(cards.length); // Winner = last hitter in this pile (same logic as playerWonCurrentTrick but using snapshot)
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
                        startDelay: j * dur(120),
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
                    property int startDelay: 0
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

                    Timer {
                        id: startDelayTimer
                        interval: flyingCard.startDelay
                        repeat: false
                        onTriggered: {
                            flyAnim.start()
                            // Start flip after flight starts if requested
                            if (flyingCard.flipToFaceUpOnTable) {
                                midFlipTimer.start()
                            } else if (flyingCard.wonByPlayer && flyingCard.shouldFlipMidFlight) {
                                midFlipTimer.start()
                            }
                        }
                    }

                    function startFlight() {
                        if (flyingCard.startDelay > 0) {
                            startDelayTimer.restart()
                        } else {
                            flyAnim.start()
                            if (flyingCard.flipToFaceUpOnTable) {
                                midFlipTimer.start()
                            } else if (flyingCard.wonByPlayer && flyingCard.shouldFlipMidFlight) {
                                midFlipTimer.start()
                            }
                        }
                    }

                    function flyToTable() {
                        // flip handled in startFlight()
var target = tableDealPoint.mapToItem(animationLayer, 0, 0)

                        xAnim.to = target.x
                        yAnim.to = target.y
                        startFlight()

                    }

                    function flyToPoint(targetItem) {
                        var target = targetItem.mapToItem(animationLayer, 0, 0)
                        xAnim.to = target.x
                        yAnim.to = target.y
                        startFlight()
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
                            duration: flyingCard.flightDuration
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

                                // Gate dealing as soon as the trick is complete (both cards landed).
                                // The engine may already update hands before the capture animation starts.
                                mainPage.dealingPaused = true
                                mainPage.capturePending = true
                                mainPage.phase = "pause"
                                mainPage.pendingTrickResolve = false
                                resolveTrickTimer.restart()   // this is your trickResolveDelay pause
                            }

                            // 2) Flying to winner pile
                            if (flyingCard.flightRole === "toPile") {
                                mainPage.pileFlightsInProgress--
                                console.info("[DEAL_GATE] pile flight finished cardId=", flyingCard.cardId,
                                             "remaining=", mainPage.pileFlightsInProgress)
                                if (mainPage.pileFlightsInProgress === 0) {
                                    mainPage.phase = "idle"
                                }
                                mainPage.tryResumeDealing("flight")
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
                                property int dealDelay: index * dur(220)
                                property real finalX: (aiHandArea.width - handWidth) / 2 + index * spacing
                                property real finalY: 0

                                property real dealOffsetX: 0
                                property real dealOffsetY: 0

                                x: finalX + dealOffsetX
                                y: finalY + dealOffsetY

                                opacity: 0.9

                                Behavior on x {
                                    NumberAnimation { duration: dur(200); easing.type: Easing.OutCubic }
                                }

                                Behavior on y {
                                    NumberAnimation { duration: dur(240); easing.type: Easing.OutCubic }
                                }

                                function startDealIfNeeded() {
                                    if (mainPage.seenAiIds[modelData.id]) {
                                        aiCard.opacity = 1.0
                                        return
                                    }

                                    if (bornAtDeck) {
                                        if (mainPage.dealingPaused || mainPage.capturePending || mainPage.pileFlightsInProgress > 0) {
                                            aiCard.opacity = 0
                                            waitDealTimer.start()
                                            return
                                        }
                                        mainPage.seenAiIds[modelData.id] = true
                                        aiCard.opacity = 0
                                        deferDealStartTimer.restart()
                                    } else {
                                        mainPage.seenAiIds[modelData.id] = true
                                        aiCard.opacity = 1.0
                                    }
                                }

                                Component.onCompleted: {
                                     // Decide once per delegate if this card should animate from deck.
                                     bornAtDeck = mainPage.freshRound || (!mainPage.seenAiIds[modelData.id])
                                     console.info("[DEAL_GATE] AI card delegate created id=", modelData.id,
                                                  "dealingPaused=", mainPage.dealingPaused,
                                                  "capturePending=", mainPage.capturePending,
                                                  "bornAtDeck=", bornAtDeck)


                                     if (mainPage.dealingPaused || mainPage.capturePending) {
                                        // During capture/deal-pause: only gate newly dealt cards.
                                        if (bornAtDeck) {
                                            opacity = 0.0;
                                            waitDealTimer.start();
                                        } else {
                                            opacity = 1.0;
                                        }
                                    } else {
                                        startDealIfNeeded();
                                    }
                                }

                                Timer {
                                    id: waitDealTimer
                                    interval: 50
                                    repeat: true
                                    running: false
                                    onTriggered: {
                                        if (!mainPage.dealingPaused && !mainPage.capturePending && mainPage.pileFlightsInProgress === 0) {
                                             console.info("[DEAL_GATE] AI waitDealTimer release id=", modelData.id,
                                                          "bornAtDeck=", bornAtDeck)
                                             stop();
                                             if (bornAtDeck) {
                                                 mainPage.seenAiIds[modelData.id] = true
                                                 opacity = 1.0
                                                 dealTimer.restart()
                                             } else {
                                                 opacity = 1.0
                                             }
                                        }
                                    }
                                }

                                Timer {
                                    id: deferDealStartTimer
                                    interval: 0
                                    repeat: false
                                    running: false
                                    onTriggered: {
                                        if (mainPage.dealingPaused || mainPage.capturePending || mainPage.pileFlightsInProgress > 0) {
                                            aiCard.opacity = 0
                                            waitDealTimer.start()
                                            return
                                        }
                                        aiCard.opacity = 0.9
                                        dealTimer.start()
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
                                        duration: dur(260)
                                        easing.type: Easing.OutCubic
                                    }

                                    PropertyAnimation {
                                        target: aiCard
                                        property: "dealOffsetY"
                                        to: 0
                                        duration: dur(260)
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
                                        mainPage.aiFlyingActive = true
                                        mainPage.hideAiStaticId = last.id
                                        mainPage.pendingAiCardId = last.id
                                        aiSpawnTimer.restart()
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

                                // Fan/stack so all cards remain visible
                                x: 0
                                y: -height / 2 + index * Theme.paddingMedium * 1.10
                                rotation: -12 + index * 6

                                // Hide the newest AI table card while its flying clone is animating
                                opacity: (modelData.playedBy === 1 && mainPage.aiFlyingActive && modelData.id === mainPage.hideAiStaticId) ? 0.0 : 1.0

                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
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
                            NumberAnimation { duration: dur(200); easing.type: Easing.OutCubic }
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
                                         (!engine.canLeave || modelData.rank === engine.cardToHit || modelData.rank === 7) &&
                                         !bornAtDeck && opacity > 0.2

                                property int count: engine.playerHand.length
                                property real centerIndex: (count - 1) / 2
                                property real distanceFromCenter: Math.abs(index - centerIndex)
                                property real spacing: card.width * 0.6
                                property real handWidth: (count - 1) * spacing + card.width
                                property bool bornAtDeck: false
                                property int dealDelay: index * dur(220)
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
                                    if (bornAtDeck || opacity <= 0.2) return
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
                                    NumberAnimation { duration: dur(200); easing.type: Easing.OutCubic }
                                }

                                Behavior on y {
                                    NumberAnimation { duration: dur(240); easing.type: Easing.OutCubic }
                                }

                                function startDealIfNeeded() {
                                    // If we already handled this card, just make sure it is visible.
                                    if (mainPage.seenPlayerIds[modelData.id]) {
                                        mouseArea.opacity = 1.0
                                        return
                                    }

                                    if (bornAtDeck) {
                                        // Newly dealt card: if we are currently gating dealing, keep it hidden and wait.
                                        if (mainPage.dealingPaused || mainPage.capturePending || mainPage.pileFlightsInProgress > 0) {
                                            mouseArea.opacity = 0
                                            waitDealTimer.start()
                                            return
                                        }

                                        // We are allowed to deal now.
                                        mainPage.seenPlayerIds[modelData.id] = true
                                        mouseArea.opacity = 0
                                        // x/y are bound to bornAtDeck; keep bornAtDeck=true until dealAnim stops.
                                        deferDealStartTimer.restart()
                                    } else {
                                        // Existing hand card (not from deck)
                                        mainPage.seenPlayerIds[modelData.id] = true
                                        mouseArea.opacity = 1.0
                                    }
                                }

                                Component.onCompleted: {
                                     // Decide once per delegate if this card should animate from deck.
                                     // Important: do NOT bind bornAtDeck to seen/dealingPaused, otherwise it flips mid-flow.
                                     bornAtDeck = mainPage.freshRound || (!mainPage.seenPlayerIds[modelData.id])
                                     console.info("[DEAL_GATE] PLAYER card delegate created id=", modelData.id,
                                                  "dealingPaused=", mainPage.dealingPaused,
                                                  "capturePending=", mainPage.capturePending,
                                                  "bornAtDeck=", bornAtDeck)


                                     // After first hand is created, we are no longer in fresh round
                                    // (this runs multiple times; safe)
                                    mainPage.freshRound = false

                                    if (mainPage.dealingPaused || mainPage.capturePending) {
                                        // During capture/deal-pause: only gate *newly dealt* cards.
                                        // Already-in-hand cards must remain visible (delegates can be recreated while paused).
                                        if (bornAtDeck) {
                                            mouseArea.opacity = 0
                                            waitDealTimer.start()
                                        } else {
                                            mouseArea.opacity = 1.0
                                        }
                                    } else {
                                        startDealIfNeeded()
                                    }
                                }

                                Timer {
                                    id: waitDealTimer
                                    interval: 50
                                    repeat: true
                                    running: false
                                    onTriggered: {
                                        if (!mainPage.dealingPaused && !mainPage.capturePending && mainPage.pileFlightsInProgress === 0) {
                                             console.info("[DEAL_GATE] PLAYER waitDealTimer release id=", modelData.id,
                                                          "bornAtDeck=", bornAtDeck)
                                             stop()
                                             if (bornAtDeck) {
                                                 // Start the actual deal animation now (even if seen was set earlier).
                                                 mainPage.seenPlayerIds[modelData.id] = true
                                                 mouseArea.opacity = 1.0
                                                 dealTimer.restart()
                                             } else {
                                                 // Delegate recreated while paused; restore visibility.
                                                 mouseArea.opacity = 1.0
                                             }
                                        }
                                    }
                                }

                                Timer {
                                    id: deferDealStartTimer
                                    interval: 0
                                    repeat: false
                                    running: false
                                    onTriggered: {
                                        if (mainPage.dealingPaused || mainPage.capturePending || mainPage.pileFlightsInProgress > 0) {
                                            mouseArea.opacity = 0
                                            waitDealTimer.start()
                                            return
                                        }
                                        mouseArea.opacity = 1.0
                                        dealTimer.start()
                                    }
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
                                    interval: dur(250)               // scaled
                                    repeat: false
                                    onTriggered: dealFlipAnim.start()
                                }

                                Timer {
                                    id: playTimer
                                    interval: dur(500)
                                    repeat: false
                                    onTriggered: engine.playCard(index)
                                }

                                ParallelAnimation {
                                    id: dealAnim

                                    PropertyAnimation {
                                        target: mouseArea
                                        property: "x"
                                        to: mouseArea.finalX
                                        duration: dur(280)
                                        easing.type: Easing.OutCubic
                                    }

                                    PropertyAnimation {
                                        target: mouseArea
                                        property: "y"
                                        to: mouseArea.finalY
                                        duration: dur(280)
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
                                            duration: dur(260)
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
                        NumberAnimation { duration: dur(200); easing.type: Easing.OutCubic }
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
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: settingsPage

    property var settings

    // -------------------------------
    // REUSABLE EXPAND/COLLAPSE HEADER
    // -------------------------------
    Component {
        id: expandingHeader

        BackgroundItem {
            id: header
            property alias text: headerLabel.text
            property bool expanded: false
            signal toggled(bool state)

            width: parent.width
            height: Theme.itemSizeSmall

            onClicked: {
                expanded = !expanded
                toggled(expanded)
            }

            Label {
                id: headerLabel
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
            }

            Image {
                id: arrow
                source: "image://theme/icon-m-left"
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter
                rotation: expanded ? -90 : 0

                Behavior on rotation {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: qsTr("Settings") }

            Label {
                id: settingsSubtitle
                text: qsTr("Controls how fast cards move on the table")
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                visible: settings.animationsExpanded
            }


            // -------------------------------
            // 1. GAME STYLE
            // -------------------------------

            Loader {
                id: cardStyleHeaderLoader
                width: parent.width
                sourceComponent: expandingHeader
                onLoaded: {
                    item.text = qsTr("Card Style")
                    item.expanded = settings.cardStyleExpanded
                    item.toggled.connect(function(state) {
                        settings.cardStyleExpanded = state
                    })
                }
            }

            Item {
                id: cardStyleContainer
                width: parent.width
                clip: true

                property int targetHeight:
                    settings.cardStyleExpanded ? cardStyleContent.implicitHeight : 0

                height: targetHeight

                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                Column {
                    id: cardStyleContent
                    width: parent.width
                    spacing: Theme.paddingSmall

                    ComboBox {
                        width: parent.width - 2 * Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: qsTr("Card style")

                        currentIndex: {
                            switch (settings.cardStyle) {
                            case "Piatnik": return 0
                            case "Cartamundi": return 1
                            case "Trefl": return 2
                            case "Luxus": return 3
                            case "Betyar": return 4
                            case "Trianon": return 5
                            case "Hadsegelyezo": return 6
                            default: return 0
                            }
                        }

                        menu: ContextMenu {
                            MenuItem { text: "Piatnik" }
                            MenuItem { text: "Cartamundi" }
                            MenuItem { text: "Trefl" }
                            MenuItem { text: "Luxus" }
                            MenuItem { text: "Betyár" }
                            MenuItem { text: "Trianon" }
                            MenuItem { text: "Hadsegélyező" }
                        }

                        onCurrentIndexChanged: {
                            settings.cardStyle = [
                                "Piatnik",
                                "Cartamundi",
                                "Trefl",
                                "Luxus",
                                "Betyar",
                                "Trianon",
                                "Hadsegelyezo"
                            ][currentIndex]
                        }
                    }
                }
            }

            // -------------------------------
            // 3. ANIMATIONS
            // -------------------------------

            Loader {
                id: animationsHeaderLoader
                width: parent.width
                sourceComponent: expandingHeader
                onLoaded: {
                    item.text = qsTr("Animations")
                    item.expanded = settings.animationsExpanded
                    item.toggled.connect(function(state) {
                        settings.animationsExpanded = state
                    })
                }
            }

            Item {
                id: animationsContainer
                width: parent.width
                clip: true

                property int targetHeight:
                    settings.animationsExpanded ? animationsContent.implicitHeight : 0

                height: targetHeight

                Behavior on height { NumberAnimation { duration: 200 } }

                Column {
                    id: animationsContent
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Column {
                        width: parent.width - 2 * Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall

                        Slider {
                            id: tableSpeedSlider
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.paddingLarge
                            anchors.rightMargin: Theme.paddingLarge

                            minimumValue: 0.5
                            maximumValue: 2.0
                            stepSize: 0.25

                            value: settings.tableFlightDuration

                            label: qsTr("Table animation speed")
                            valueText: {
                                if (value <= 0.75) return qsTr("Slow")
                                if (value <= 1.25) return qsTr("Normal")
                                return qsTr("Fast")
                            }

                            onValueChanged: settings.tableFlightDuration = value
                        }
                    }


                    Column {
                        width: parent.width - 2 * Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall

                        Slider {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.paddingLarge
                            anchors.rightMargin: Theme.paddingLarge

                            minimumValue: 200
                            maximumValue: 1500
                            stepSize: 50

                            value: settings.aiPlayDelay

                            label: qsTr("AI thinking speed")
                            valueText: value < 400 ? qsTr("Fast")
                                       : value < 900 ? qsTr("Normal")
                                       : qsTr("Slow")

                            onValueChanged: settings.aiPlayDelay = value
                        }
                    }

                    Column {
                        width: parent.width - 2 * Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall

                        ComboBox {
                            width: parent.width
                            label: qsTr("AI difficulty")

                            currentIndex: settings.aiDifficulty

                            menu: ContextMenu {
                                MenuItem { text: qsTr("Easy") }
                                MenuItem { text: qsTr("Normal") }
                                MenuItem { text: qsTr("Hard") }
                                MenuItem { text: qsTr("Expert") }
                            }

                            onCurrentIndexChanged: settings.aiDifficulty = currentIndex
                        }
                    }
                }
            }

            // -------------------------------
            // 3. AI NAMES
            // -------------------------------

            Loader {
                id: namesHeaderLoader
                width: parent.width
                sourceComponent: expandingHeader
                onLoaded: {
                    item.text = qsTr("AI Names")
                    item.expanded = settings.namesExpanded
                    item.toggled.connect(function(state) {
                        settings.namesExpanded = state
                    })
                }
            }

            Item {
                id: namesContainer
                width: parent.width
                clip: true

                property int targetHeight:
                    settings.namesExpanded ? namesContent.implicitHeight : 0

                height: targetHeight

                Behavior on height { NumberAnimation { duration: 200 } }

                Column {
                    id: namesContent
                    width: parent.width
                    spacing: Theme.paddingSmall

                    TextField {
                        width: parent.width - 2 * Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: qsTr("AI 1 name")
                        text: settings.ai1Name
                        onTextChanged: settings.ai1Name = text
                    }

                    TextField {
                        width: parent.width - 2 * Theme.paddingLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: qsTr("AI 2 name")
                        text: settings.ai2Name
                        onTextChanged: settings.ai2Name = text
                    }
                }
            }


            // -------------------------------
            // RESET BUTTON
            // -------------------------------

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Reset to defaults")

                onClicked: {
                    settings.cardStyle = "Piatnik"
                    settings.tableFlightDuration = 1.0
                    settings.aiPlayDelay = 650
                    settings.aiDifficulty = 1
                    settings.ai1Name = "AI 1"
                    settings.ai2Name = "AI 2"

                    settings.cardStyleExpanded = true
                    settings.animationsExpanded = false
                    settings.namesExpanded = false
                }
            }
        }
    }
}

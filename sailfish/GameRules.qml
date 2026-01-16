import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: rulesPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: rulesColumn.height + Theme.paddingLarge

        PageHeader {
            title: "Game Rules"
        }

        Column {
            id: rulesColumn
            width: parent.width
            spacing: Theme.paddingLarge
            anchors.top: parent.top
            anchors.topMargin: Theme.itemSizeLarge   // below header area

            // Optional: short intro
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: "Zsírozás (also known as Zsír) is a Hungarian trick-taking card game. " +
                      "This page explains the basic rules used by this app."
            }

            SectionHeader {
                text: "Goal"
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text:
                    "Win tricks to collect scoring cards. At the end of the round, total points decide the winner."
            }

            SectionHeader {
                text: "Turn flow"
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text:
                    "1) The player on turn plays one card to the table.\n" +
                    "2) The next player plays one card.\n" +
                    "3) The trick winner takes both cards into their won pile.\n" +
                    "4) If the deck is not empty, players draw to restore hand size."
            }

            SectionHeader {
                text: "Trick winner"
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text:
                    "In the current app logic:\n" +
                    "• The second card wins if it matches the first card’s rank.\n" +
                    "• The second card also wins if it is a 7.\n" +
                    "• Otherwise, the first card wins.\n\n" +
                    "Note: this is a simplified ruleset and will be updated when we implement full Zsírozás logic."
            }

            SectionHeader {
                text: "Scoring"
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text:
                    "Scoring depends on the exact variant. This app will show score totals in the UI. " +
                    "Once we implement full game logic, this section will be updated with the precise scoring cards and points."
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}

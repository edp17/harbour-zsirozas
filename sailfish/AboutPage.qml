import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: aboutPage

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            anchors.top: parent.top
            anchors.topMargin: Theme.paddingLarge

            PageHeader {
                title: "About"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Zsírozás"
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Classic Hungarian card game"
                color: Theme.secondaryColor
            }

            Separator {
                width: parent.width
            }

            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                text:
                    "Zsírozás is a traditional Hungarian trick-taking card game.\n\n" +
                    "This Sailfish OS implementation focuses on smooth animations, " +
                    "clean visuals, and faithful gameplay."
            }

            Separator {
                width: parent.width
            }

            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Author: Miklós"
            }

            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Platform: Sailfish OS"
            }

            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Version: 1.0"
            }

            Separator {
                width: parent.width
            }

            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                text:
                    "Cards and animations are original.\n\n" +
                    "This application is not affiliated with any card publishers."
            }
        }
    }
}

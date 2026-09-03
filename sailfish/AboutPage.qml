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
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator { }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("About Zsírozás") }

            Image {
                width: Theme.itemSizeHuge
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl("icons/icon-256.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Label {
                width: parent.width
                text: "Zsírozás"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeHuge
                font.bold: true
                color: Theme.highlightColor
            }

            Label {
                width: parent.width
                text: qsTr("The Hungarian game of fat cards")
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("A native Sailfish OS edition of the traditional card game, with individual two-player rounds and the classic four-player partnership game.")
            }

            SectionHeader { text: qsTr("Included") }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                text: qsTr("• One or three computer opponents\n" +
                           "• Four independently configurable difficulty levels\n" +
                           "• Piatnik and Betyár card designs\n" +
                           "• Animated or immediate play\n" +
                           "• Captured-card inspection\n" +
                           "• English and Hungarian interface\n" +
                           "• Automatic recovery of an unfinished round")
            }

            SectionHeader { text: qsTr("Release") }

            DetailItem { label: qsTr("Version"); value: "1.0" }
            DetailItem { label: qsTr("Developer"); value: "edp17" }
            DetailItem { label: qsTr("License"); value: "MIT" }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("View source on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/edp17/harbour-zsirozas")
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Made for players who want a small piece of Hungarian card-table tradition in their pocket. This independent application is not affiliated with any card publisher.")
            }
        }
    }
}

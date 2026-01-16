import QtQuick 2.6
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        Label {
            text: "Zsírozás"
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
        }

        Label {
            text: "Hungarian Card Game"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
            horizontalAlignment: Text.AlignHCenter
        }
    }
}

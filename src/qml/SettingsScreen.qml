import QtQuick
import Logos.Theme
import Logos.Controls

Item {
    LogosText {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacing.large
        text: "Settings"
        font.pixelSize: Theme.typography.titleText
        color: Theme.palette.text
    }
}

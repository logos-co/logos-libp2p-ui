import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property string title: ""

    LogosText {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacing.large
        text: root.title
        font.pixelSize: Theme.typography.titleText
        color: Theme.palette.text
    }
}

import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    property alias title: titleText.text
    property alias message: messageText.text

    function show(title, message) {
        root.title = title
        root.message = message
        root.visible = true
        closeTimer.restart()
    }

    visible: false
    width: Math.min(560, parent ? parent.width - 2 * Theme.spacing.large : 560)
    implicitHeight: content.implicitHeight + 2 * Theme.spacing.medium
    radius: Theme.spacing.radiusLarge
    color: Theme.palette.backgroundSecondary
    border.color: Theme.palette.borderSecondary
    border.width: 1
    z: 100

    Timer {
        id: closeTimer
        interval: 4500
        repeat: false
        onTriggered: root.visible = false
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.spacing.medium
        spacing: Theme.spacing.tiny

        LogosText {
            id: titleText
            Layout.fillWidth: true
            font.pixelSize: Theme.typography.primaryText
            color: Theme.palette.text
        }

        LogosText {
            id: messageText
            Layout.fillWidth: true
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            wrapMode: Text.Wrap
        }
    }
}

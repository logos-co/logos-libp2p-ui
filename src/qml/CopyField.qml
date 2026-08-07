import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

ColumnLayout {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property bool copied: false

    spacing: Theme.spacing.tiny

    Timer {
        id: copiedTimer

        interval: 1400
        onTriggered: root.copied = false
    }

    LogosText {
        text: root.label
        font.pixelSize: Theme.typography.secondaryText
        color: Theme.palette.textTertiary
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: Theme.spacing.radiusSmall
        color: Theme.palette.backgroundInset
        border.color: Theme.palette.borderSecondary
        border.width: 1

        function copyValue() {
            if (root.value.length === 0)
                return
            valueText.selectAll()
            valueText.copy()
            valueText.deselect()
            root.copied = true
            copiedTimer.restart()
        }

        TextEdit {
            id: valueText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.small
            anchors.right: copyButton.left
            anchors.rightMargin: Theme.spacing.small
            text: root.value.length > 0 ? root.value : root.placeholder
            font.pixelSize: Theme.typography.secondaryText
            color: root.value.length > 0 ? Theme.palette.text : Theme.palette.textTertiary
            readOnly: true
            selectByMouse: false
            selectedTextColor: Theme.palette.text
            selectionColor: Theme.palette.primary
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.NoWrap
            clip: true
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: root.value.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: parent.parent.copyValue()
            }
        }

        Rectangle {
            id: copyButton

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.small
            width: root.copied ? 78 : 30
            height: 30
            radius: Theme.spacing.radiusSmall
            color: root.copied ? Theme.palette.backgroundButton : "transparent"
            border.width: root.copied ? 1 : 0
            border.color: Theme.palette.borderSecondary
            opacity: root.value.length > 0 ? 1.0 : 0.45

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacing.tiny

                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    opacity: root.copied ? 1.0 : 0.85

                    Rectangle {
                        x: 2
                        y: 5
                        width: 9
                        height: 9
                        radius: 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: root.value.length > 0 ? Theme.palette.text : Theme.palette.textTertiary
                    }

                    Rectangle {
                        x: 5
                        y: 2
                        width: 9
                        height: 9
                        radius: 2
                        color: Theme.palette.backgroundInset
                        border.width: 1.5
                        border.color: root.value.length > 0 ? Theme.palette.text : Theme.palette.textTertiary
                    }
                }

                LogosText {
                    visible: root.copied
                    text: "Copied"
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.text
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.value.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: parent.parent.copyValue()
            }
        }
    }
}

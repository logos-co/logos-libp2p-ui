import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

ColumnLayout {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""

    spacing: Theme.spacing.tiny

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
        }

        TextEdit {
            id: valueText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.small
            anchors.right: copyLabel.left
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

        LogosText {
            id: copyLabel

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.small
            text: "Copy"
            font.pixelSize: Theme.typography.secondaryText
            color: root.value.length > 0 ? Theme.palette.primary : Theme.palette.textTertiary

            MouseArea {
                anchors.fill: parent
                cursorShape: root.value.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: parent.parent.copyValue()
            }
        }
    }
}

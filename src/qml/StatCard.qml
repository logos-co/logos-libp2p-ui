import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

LogosFrame {
    id: root

    property string title: ""
    property int value: 0
    property string iconSource: ""

    implicitHeight: 132
    backgroundColor: Theme.palette.backgroundSecondary
    borderColor: Theme.palette.borderSecondary
    radius: Theme.spacing.radiusLarge
    padding: Theme.spacing.medium

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.small

        LogosText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.typography.primaryText
            font.weight: Theme.typography.weightMedium
            color: Theme.palette.textSecondary
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing.medium

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: Theme.spacing.radiusSmall
                color: Theme.palette.backgroundButton

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: Qt.resolvedUrl(root.iconSource)
                    sourceSize: Qt.size(44, 44)
                    fillMode: Image.PreserveAspectFit
                }
            }

            LogosText {
                Layout.fillWidth: true
                text: root.value
                font.pixelSize: Theme.typography.titleText
                color: Theme.palette.text
                elide: Text.ElideRight
            }
        }
    }
}

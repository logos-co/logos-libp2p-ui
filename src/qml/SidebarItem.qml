import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    property string title: ""
    property string iconSource: ""
    property bool selected: false

    signal clicked

    implicitHeight: 44
    radius: Theme.spacing.radiusSmall
    color: selected ? Theme.palette.backgroundButton : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing.medium
        anchors.rightMargin: Theme.spacing.medium
        spacing: Theme.spacing.small

        Image {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: Qt.resolvedUrl(root.iconSource)
            sourceSize: Qt.size(40, 40)
            fillMode: Image.PreserveAspectFit
            opacity: root.selected ? 1.0 : 0.7
        }

        LogosText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.typography.secondaryText
            color: root.selected ? Theme.palette.text : Theme.palette.textSecondary
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

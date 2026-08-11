import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    implicitWidth: 1200
    implicitHeight: 800
    Layout.fillWidth: true
    Layout.fillHeight: true

    QtObject {
        id: d
        readonly property string mod: "libp2p_ui"
        readonly property var liveBackend: typeof logos !== "undefined" && logos ? logos.module(mod) : null
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.background
    }

    Loader {
        anchors.fill: parent
        active: d.liveBackend !== null
        sourceComponent: consoleComponent
    }

    Component {
        id: consoleComponent

        Libp2pConsoleLayout {
            backend: d.liveBackend
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 2 * Theme.spacing.large, 560)
        spacing: Theme.spacing.medium
        visible: d.liveBackend === null

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            source: Qt.resolvedUrl("assets/network.svg")
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
        }

        LogosText {
            Layout.fillWidth: true
            text: "Libp2p backend unavailable"
            font.pixelSize: Theme.typography.titleText
            color: Theme.palette.text
            horizontalAlignment: Text.AlignHCenter
        }

        LogosText {
            Layout.fillWidth: true
            text: "The libp2p UI backend could not be loaded. Verify that the libp2p_ui module is installed and initialized by Logos Core, then restart the application."
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    ErrorToast {
        id: errorToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing.medium
    }

    Connections {
        target: d.liveBackend
        ignoreUnknownSignals: true

        function onError(message) {
            errorToast.show("Error", message)
        }

        function onStartFailed(message) {
            errorToast.show("Start failed", message)
        }
    }
}

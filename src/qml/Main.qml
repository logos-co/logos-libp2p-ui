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

    Libp2pConsoleLayout {
        anchors.fill: parent
        backend: d.liveBackend || MockBackend
    }

    ErrorToast {
        id: errorToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing.medium
    }

    Connections {
        target: d.liveBackend || MockBackend
        ignoreUnknownSignals: true

        function onError(message) {
            errorToast.show("Error", message)
        }

        function onStartFailed(message) {
            errorToast.show("Start failed", message)
        }
    }
}

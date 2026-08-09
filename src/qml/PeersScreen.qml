import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: MockBackend
    readonly property bool running: backend && backend.status === 2
    readonly property var inboundPeers: backend && backend.inboundPeers !== undefined ? backend.inboundPeers : []
    readonly property var outboundPeers: backend && backend.outboundPeers !== undefined ? backend.outboundPeers : []
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    property string successMessage: ""

    function metric(name) {
        return metrics[name] === undefined ? 0 : metrics[name]
    }

    function refresh() {
        if (backend) {
            backend.refreshPeers()
            backend.refreshMetrics()
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        repeat: true
        running: root.visible && root.running
        onTriggered: root.refresh()
    }

    LogosScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Theme.spacing.large

            RowLayout {
                Layout.fillWidth: true
                LogosText {
                    text: "Peers"
                    font.pixelSize: Theme.typography.titleText
                    color: Theme.palette.text
                }
                Item { Layout.fillWidth: true }
                LogosButton {
                    text: "Refresh"
                    enabled: root.running
                    onClicked: root.refresh()
                }
            }

            LogosText {
                Layout.fillWidth: true
                visible: !root.running
                text: "Start the node from Overview to connect and manage peers."
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.warning
                wrapMode: Text.Wrap
            }

            LogosText {
                Layout.fillWidth: true
                visible: root.successMessage.length > 0
                text: root.successMessage
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.success
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 4 : width > 500 ? 2 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Connected"; value: root.metric("connectedPeersMetric"); iconSource: "assets/peers.svg" }
                StatCard { Layout.fillWidth: true; title: "Inbound"; value: root.inboundPeers.length; iconSource: "assets/peers.svg" }
                StatCard { Layout.fillWidth: true; title: "Outbound"; value: root.outboundPeers.length; iconSource: "assets/peers.svg" }
                StatCard { Layout.fillWidth: true; title: "Known peers"; value: root.backend ? root.backend.knownPeers : 0; iconSource: "assets/peers.svg" }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacing.medium
                    LogosText { text: "Connect peer"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosTextField { id: peerIdField; Layout.fillWidth: true; enabled: root.running; placeholderText: "Peer ID"; onTextChanged: root.successMessage = "" }
                    RowLayout {
                        Layout.fillWidth: true
                        LogosTextField { id: multiaddrField; Layout.fillWidth: true; enabled: root.running; placeholderText: "Multiaddress (for example /ip4/127.0.0.1/tcp/9000)"; onTextChanged: root.successMessage = "" }
                        LogosButton {
                            text: "Connect"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running && peerIdField.text.trim().length > 0 && multiaddrField.text.trim().length > 0
                            onClicked: root.backend.connectPeer(peerIdField.text, multiaddrField.text)
                        }
                    }
                }
            }

            Repeater {
                model: [ { "title": "Inbound peers", "peers": root.inboundPeers }, { "title": "Outbound peers", "peers": root.outboundPeers } ]
                LogosFrame {
                    required property var modelData
                    Layout.fillWidth: true
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.small
                        LogosText { text: modelData.title; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        LogosText {
                            Layout.fillWidth: true
                            visible: modelData.peers.length === 0
                            text: root.running ? "No " + modelData.title.toLowerCase() + "." : "No peers are available while the node is stopped."
                            font.pixelSize: Theme.typography.secondaryText
                            color: Theme.palette.textTertiary
                            wrapMode: Text.Wrap
                        }
                        Repeater {
                            model: modelData.peers
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: peerRow.implicitHeight + 2 * Theme.spacing.small
                                radius: Theme.spacing.radiusSmall
                                color: Theme.palette.background
                                border.width: 1
                                border.color: Theme.palette.borderSecondary
                                RowLayout {
                                    id: peerRow
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing.small
                                    LogosText { Layout.fillWidth: true; text: modelData; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text; elide: Text.ElideRight }
                                    LogosButton { text: "Disconnect"; enabled: root.running; onClicked: root.backend.disconnectPeer(modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root.backend
        ignoreUnknownSignals: true
        function onPeerConnected(peerId) { peerIdField.text = ""; multiaddrField.text = ""; root.successMessage = "Connected to " + peerId + "." }
        function onPeerDisconnected(peerId) { root.successMessage = "Disconnected from " + peerId + "." }
    }
}

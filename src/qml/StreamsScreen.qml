import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: null
    readonly property bool running: backend && backend.status === 2
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var ping: backend && backend.lastPingResult !== undefined ? backend.lastPingResult : ({})
    readonly property var protocolRows: metrics.streamsByProtocol || []
    readonly property var history: metrics.trafficHistory || []
    property string successMessage: ""

    function metric(name) { return metrics[name] === undefined ? 0 : metrics[name] }
    function refresh() { if (backend) backend.refreshMetrics() }
    Component.onCompleted: refresh()

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
                LogosText { text: "Streams"; font.pixelSize: Theme.typography.titleText; color: Theme.palette.text }
                Item { Layout.fillWidth: true }
                LogosButton { text: "Refresh"; enabled: root.running; onClicked: root.refresh() }
            }
            LogosText { Layout.fillWidth: true; visible: !root.running; text: "Start the node from Overview to open a ping stream."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.warning; wrapMode: Text.Wrap }
            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 4 : width > 500 ? 2 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Open streams"; value: root.metric("openStreams"); iconSource: "assets/streams.svg" }
                StatCard { Layout.fillWidth: true; title: "Inbound streams"; value: root.metric("openInboundStreams"); iconSource: "assets/streams.svg" }
                StatCard { Layout.fillWidth: true; title: "Outbound streams"; value: root.metric("openOutboundStreams"); iconSource: "assets/streams.svg" }
                StatCard { Layout.fillWidth: true; title: "Cap rejections"; value: root.metric("streamCapRejections"); iconSource: "assets/streams.svg" }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 4 : width > 500 ? 2 : 1
                columnSpacing: Theme.spacing.medium; rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Opened"; value: root.metric("streamsOpened"); iconSource: "assets/streams.svg" }
                StatCard { Layout.fillWidth: true; title: "Closed"; value: root.metric("streamsClosed"); iconSource: "assets/streams.svg" }
                StatCard { Layout.fillWidth: true; title: "Resets"; value: root.metric("streamResets"); iconSource: "assets/streams.svg" }
                StatCard { Layout.fillWidth: true; title: "Timeouts"; value: root.metric("streamTimeouts"); iconSource: "assets/streams.svg" }
            }
            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.medium
                    LogosText { text: "Open streams over time"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    MetricLineChart { Layout.fillWidth: true; history: root.history; firstField: "streams"; secondField: "unused"; firstColor: "#7C3AED"; windowMinutes: 15 }
                }
            }
            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.small
                    LogosText { text: "Streams by protocol"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { Layout.fillWidth: true; visible: root.protocolRows.length === 0; text: "No labeled protocol streams are currently open."; color: Theme.palette.textTertiary }
                    Repeater {
                        model: root.protocolRows
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 42; radius: Theme.spacing.radiusSmall; color: Theme.palette.background
                            RowLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacing.small
                                LogosText { Layout.fillWidth: true; text: modelData.protocol; color: Theme.palette.text; elide: Text.ElideMiddle }
                                LogosText { text: "In " + (modelData.inbound || 0); color: Theme.palette.textSecondary }
                                LogosText { text: "Out " + (modelData.outbound || 0); color: Theme.palette.textSecondary }
                                LogosText { text: "Rejected " + (modelData.rejections || 0); color: (modelData.rejections || 0) > 0 ? Theme.palette.warning : Theme.palette.textSecondary }
                            }
                        }
                    }
                }
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
                    LogosText { text: "Ping stream"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { Layout.fillWidth: true; text: "Open the built-in /ipfs/ping/1.0.0 protocol against a connected peer. The stream is closed and released after the echo completes."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                    RowLayout {
                        Layout.fillWidth: true
                        LogosTextField { id: peerIdField; Layout.fillWidth: true; enabled: root.running; placeholderText: "Connected peer ID"; onTextChanged: root.successMessage = "" }
                        LogosButton { text: "Ping"; variant: LogosButton.Variant.Primary; enabled: root.running && peerIdField.text.trim().length > 0; onClicked: root.backend.pingPeer(peerIdField.text) }
                    }
                    LogosText { Layout.fillWidth: true; visible: root.successMessage.length > 0; text: root.successMessage; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.success; wrapMode: Text.Wrap }
                    LogosText { Layout.fillWidth: true; visible: ping.success === true; text: "Last successful ping: " + ping.peerId + " in " + ping.latencyMs + " ms."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary; wrapMode: Text.Wrap }
                }
            }
        }
    }
    Connections { target: root.backend; ignoreUnknownSignals: true; function onPingCompleted(result) { root.successMessage = "Ping to " + result.peerId + " completed in " + result.latencyMs + " ms." } }
}

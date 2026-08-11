import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: null
    readonly property bool running: backend && backend.status === 2
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var config: backend && backend.nodeConfig !== undefined ? backend.nodeConfig : ({})
    function metric(name) { return metrics[name] === undefined ? 0 : metrics[name] }
    function percent(value) { return (Number(value || 0) * 100).toFixed(0) + "%" }
    function formatBytes(value) {
        var number = Number(value || 0); var units = ["B", "KiB", "MiB", "GiB"]; var unit = 0
        while (number >= 1024 && unit < units.length - 1) { number /= 1024; ++unit }
        return number.toFixed(unit === 0 ? 0 : 1) + " " + units[unit]
    }

    Component.onCompleted: if (backend) backend.refreshMetrics()

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
                LogosText { text: "Connectivity"; font.pixelSize: Theme.typography.titleText; color: Theme.palette.text }
                Item { Layout.fillWidth: true }
                LogosButton { text: "Refresh"; enabled: root.running; onClicked: root.backend.refreshMetrics() }
            }
            LogosText { Layout.fillWidth: true; visible: !root.running; text: "Start the node to inspect reachability, dialing, and relay state."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.warning; wrapMode: Text.Wrap }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 900 ? 4 : width > 520 ? 2 : 1
                columnSpacing: Theme.spacing.medium; rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "AutoNAT v1"; value: config.autonat ? root.metric("autonatReachability") : "Disabled"; iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "AutoNAT v2"; value: config.autonatV2 ? root.metric("autonatV2Reachability") : "Disabled"; iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Dial success"; value: Number(root.metric("dialSuccessRate")).toFixed(1) + "%"; iconSource: "assets/peers.svg" }
                StatCard { Layout.fillWidth: true; title: "Relay reservations"; value: root.metric("relayReservationsActive"); iconSource: "assets/relay.svg" }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary; borderColor: Theme.palette.borderSecondary; radius: Theme.spacing.radiusLarge; padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.medium
                    LogosText { text: "Reachability"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { Layout.fillWidth: true; text: "AutoNAT v1: " + root.metric("autonatReachability") + " (confidence " + root.percent(root.metric("autonatConfidence")) + ")"; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                    LogosText { Layout.fillWidth: true; text: "AutoNAT v2: " + root.metric("autonatV2Reachability") + " (confidence " + root.percent(root.metric("autonatV2Confidence")) + ")"; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                    LogosText { Layout.fillWidth: true; text: "Listener: " + (backend && backend.listenAddress ? backend.listenAddress : "Unavailable"); color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                    LogosText { Layout.fillWidth: true; visible: !config.autonat && !config.autonatV2; text: "Enable AutoNAT v1 or v2 in Settings, then restart the node to measure public reachability."; color: Theme.palette.warning; wrapMode: Text.Wrap }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary; borderColor: Theme.palette.borderSecondary; radius: Theme.spacing.radiusLarge; padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.medium
                    LogosText { text: "Connection quality"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    GridLayout {
                        Layout.fillWidth: true; columns: width > 650 ? 3 : 1
                        LogosText { text: "Attempts  " + root.metric("dialAttempts"); color: Theme.palette.textSecondary }
                        LogosText { text: "Successful  " + root.metric("dialSuccesses"); color: Theme.palette.textSecondary }
                        LogosText { text: "Failed  " + root.metric("dialFailures"); color: Theme.palette.textSecondary }
                        LogosText { visible: root.metric("dialLatencyAvailable"); text: "Successful dial p50  " + root.metric("dialLatencyP50Ms") + " ms"; color: Theme.palette.textSecondary }
                        LogosText { visible: root.metric("dialLatencyAvailable"); text: "Successful dial p95  " + root.metric("dialLatencyP95Ms") + " ms"; color: Theme.palette.textSecondary }
                        LogosText { visible: root.metric("dialLatencyAvailable"); text: "Successful dial p99  " + root.metric("dialLatencyP99Ms") + " ms"; color: Theme.palette.textSecondary }
                        LogosText { text: "Failed inbound upgrades  " + root.metric("failedUpgradesInbound"); color: Theme.palette.textSecondary }
                        LogosText { text: "Failed outbound upgrades  " + root.metric("failedUpgradesOutbound"); color: Theme.palette.textSecondary }
                        LogosText { text: "Peers pruned  " + root.metric("connectionManagerPrunedPeers"); color: Theme.palette.textSecondary }
                    }
                    LogosText { Layout.fillWidth: true; visible: !root.metric("dialLatencyAvailable"); text: "Dial latency percentiles appear after a successful dial when the node exports histogram metrics."; color: Theme.palette.textTertiary; wrapMode: Text.Wrap }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary; borderColor: Theme.palette.borderSecondary; radius: Theme.spacing.radiusLarge; padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.medium
                    LogosText { text: "Circuit relay"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { Layout.fillWidth: true; text: "Reservations: " + root.metric("relayReservationsActive") + "    Active circuits: " + root.metric("relayCircuitsActive"); color: Theme.palette.textSecondary }
                    LogosText { Layout.fillWidth: true; text: "Relayed traffic: ↓ " + root.formatBytes(root.metric("relayBytesReceived")) + "  ↑ " + root.formatBytes(root.metric("relayBytesSent")); color: Theme.palette.textSecondary }
                    LogosText { Layout.fillWidth: true; visible: !config.circuitRelay && !config.circuitRelayClient; text: "Circuit Relay is disabled. Enable the server or client in Settings before starting the node."; color: Theme.palette.warning; wrapMode: Text.Wrap }
                    LogosText { Layout.fillWidth: true; visible: (config.circuitRelay || config.circuitRelayClient) && root.metric("relayReservationsActive") === 0; text: "No active reservation details are exposed by the current Logos module. Aggregate metrics will appear when the module provides them."; color: Theme.palette.textTertiary; wrapMode: Text.Wrap }
                }
            }
        }
    }
}

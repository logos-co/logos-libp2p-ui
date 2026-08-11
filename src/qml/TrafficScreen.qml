import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: MockBackend
    readonly property bool running: backend && backend.status === 2
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var history: metrics.trafficHistory || []
    readonly property var protocols: metrics.trafficByProtocol || []
    readonly property var agents: metrics.trafficByAgent || []
    property int chartWindowMinutes: 15

    function metric(name) { return metrics[name] === undefined ? 0 : metrics[name] }
    function formatBytes(value) {
        var number = Number(value || 0)
        var units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var unit = 0
        while (number >= 1024 && unit < units.length - 1) { number /= 1024; ++unit }
        return (unit === 0 ? number.toFixed(0) : number.toFixed(number >= 100 ? 0 : 1)) + " " + units[unit]
    }
    function formatRate(value) { return formatBytes(value) + "/s" }

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
                LogosText { text: "Traffic"; font.pixelSize: Theme.typography.titleText; color: Theme.palette.text }
                Item { Layout.fillWidth: true }
                LogosText { text: metrics.lastMetricsUpdateMs ? "Updated " + new Date(metrics.lastMetricsUpdateMs).toLocaleTimeString(Qt.locale(), Locale.ShortFormat) : "Not sampled"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary }
                LogosButton { text: "Refresh"; enabled: root.running; onClicked: root.backend.refreshMetrics() }
            }

            LogosText { Layout.fillWidth: true; visible: !root.running; text: "Start the node from Overview to measure network traffic."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.warning; wrapMode: Text.Wrap }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1050 ? 4 : width > 600 ? 2 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Total received"; value: root.formatBytes(root.metric("trafficBytesReceived")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Total sent"; value: root.formatBytes(root.metric("trafficBytesSent")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Receive rate"; value: root.formatRate(root.metric("trafficReceiveRate")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Send rate"; value: root.formatRate(root.metric("trafficSendRate")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Session received"; value: root.formatBytes(root.metric("trafficSessionBytesReceived")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Session sent"; value: root.formatBytes(root.metric("trafficSessionBytesSent")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Peak receive"; value: root.formatRate(root.metric("trafficPeakReceiveRate")); iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Peak send"; value: root.formatRate(root.metric("trafficPeakSendRate")); iconSource: "assets/network.svg" }
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
                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { text: "Network throughput"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        Item { Layout.fillWidth: true }
                        ComboBox { model: ["1 minute", "5 minutes", "15 minutes"]; currentIndex: 2; onActivated: root.chartWindowMinutes = index === 0 ? 1 : index === 1 ? 5 : 15 }
                    }
                    RowLayout {
                        spacing: Theme.spacing.large
                        LogosText { text: "● Received"; color: "#2563EB"; font.pixelSize: Theme.typography.secondaryText }
                        LogosText { text: "● Sent"; color: "#16A34A"; font.pixelSize: Theme.typography.secondaryText }
                    }
                    MetricLineChart { Layout.fillWidth: true; history: root.history; windowMinutes: root.chartWindowMinutes }
                    LogosText { Layout.fillWidth: true; visible: root.history.length < 2; text: "Two metric samples are required before a rate chart can be drawn."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary; horizontalAlignment: Text.AlignHCenter }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                visible: root.protocols.length > 0 || root.agents.length > 0
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.medium
                    LogosText { text: "Optional breakdowns"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    Repeater {
                        model: root.protocols
                        LogosText { required property var modelData; Layout.fillWidth: true; text: modelData.protocol + "  ↓ " + root.formatBytes(modelData.bytesReceived || 0) + "  ↑ " + root.formatBytes(modelData.bytesSent || 0); color: Theme.palette.textSecondary; elide: Text.ElideMiddle }
                    }
                    Repeater {
                        model: root.agents
                        LogosText { required property var modelData; Layout.fillWidth: true; text: modelData.agent + "  ↓ " + root.formatBytes(modelData.bytesReceived || 0) + "  ↑ " + root.formatBytes(modelData.bytesSent || 0); color: Theme.palette.textSecondary; elide: Text.ElideMiddle }
                    }
                }
            }
        }
    }
}

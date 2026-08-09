import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root
    property var backend: MockBackend
    readonly property bool running: backend && backend.status === 2
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var advertisedServices: backend && backend.advertisedServices !== undefined ? backend.advertisedServices : []
    readonly property var results: backend && backend.discoveryResults !== undefined ? backend.discoveryResults : []
    property string successMessage: ""

    function metric(name) { return metrics[name] === undefined ? 0 : metrics[name] }
    function refresh() { if (backend) backend.refreshMetrics() }
    Component.onCompleted: refresh()
    Timer { interval: 5000; repeat: true; running: root.visible && root.running; onTriggered: root.refresh() }

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
                LogosText { text: "Service Discovery"; font.pixelSize: Theme.typography.titleText; color: Theme.palette.text }
                Item { Layout.fillWidth: true }
                LogosButton { text: "Refresh"; enabled: root.running; onClicked: root.refresh() }
            }
            LogosText { Layout.fillWidth: true; visible: !root.running; text: "Start the node from Overview to advertise and discover services."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.warning; wrapMode: Text.Wrap }
            LogosText { Layout.fillWidth: true; visible: root.successMessage.length > 0; text: root.successMessage; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.success; wrapMode: Text.Wrap }
            GridLayout {
                Layout.fillWidth: true
                columns: width > 1050 ? 5 : width > 680 ? 2 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Cached ads"; value: root.metric("discoveryAdvertisements"); iconSource: "assets/discovery.svg" }
                StatCard { Layout.fillWidth: true; title: "Known services"; value: root.metric("discoveryServices"); iconSource: "assets/discovery.svg" }
                StatCard { Layout.fillWidth: true; title: "Service peers"; value: root.metric("discoveryServicePeers"); iconSource: "assets/discovery.svg" }
                StatCard { Layout.fillWidth: true; title: "Lookups"; value: root.metric("discoveryLookupRequests"); iconSource: "assets/discovery.svg" }
                StatCard { Layout.fillWidth: true; title: "Peers found"; value: root.metric("discoveryPeersFound"); iconSource: "assets/discovery.svg" }
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
                    LogosText { text: "Advertise service"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosTextField { id: advertiseId; Layout.fillWidth: true; enabled: root.running; placeholderText: "Service ID"; onTextChanged: root.successMessage = "" }
                    RowLayout {
                        Layout.fillWidth: true
                        LogosTextField { id: advertiseData; Layout.fillWidth: true; enabled: root.running; placeholderText: "Service data (may be empty)"; onTextChanged: root.successMessage = "" }
                        LogosButton { text: "Advertise"; variant: LogosButton.Variant.Primary; enabled: root.running && advertiseId.text.trim().length > 0; onClicked: root.backend.serviceDiscoveryAdvertise(advertiseId.text, advertiseData.text) }
                    }
                    LogosText { Layout.fillWidth: true; visible: root.advertisedServices.length === 0; text: root.running ? "No local services are being advertised." : "No services are available while the node is stopped."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary; wrapMode: Text.Wrap }
                    Repeater {
                        model: root.advertisedServices
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: serviceRow.implicitHeight + 2 * Theme.spacing.small; radius: Theme.spacing.radiusSmall; color: Theme.palette.background; border.width: 1; border.color: Theme.palette.borderSecondary
                            RowLayout {
                                id: serviceRow; anchors.fill: parent; anchors.margins: Theme.spacing.small; spacing: Theme.spacing.medium
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: Theme.spacing.tiny
                                    LogosText { Layout.fillWidth: true; text: modelData.serviceId; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text; elide: Text.ElideRight }
                                    LogosText { Layout.fillWidth: true; visible: modelData.serviceData.length > 0; text: modelData.serviceData; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary; elide: Text.ElideRight }
                                }
                                LogosButton { text: "Stop"; enabled: root.running; onClicked: root.backend.serviceDiscoveryStopAdvertising(modelData.serviceId) }
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
                    LogosText { text: "Lookup service"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { Layout.fillWidth: true; text: "Service data is matched exactly; leave it empty to find advertisements with empty data."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                    LogosTextField { id: lookupId; Layout.fillWidth: true; enabled: root.running; placeholderText: "Service ID"; onTextChanged: root.successMessage = "" }
                    RowLayout {
                        Layout.fillWidth: true
                        LogosTextField { id: lookupData; Layout.fillWidth: true; enabled: root.running; placeholderText: "Service data (may be empty)"; onTextChanged: root.successMessage = "" }
                        LogosButton { text: "Lookup"; variant: LogosButton.Variant.Primary; enabled: root.running && lookupId.text.trim().length > 0; onClicked: root.backend.serviceDiscoveryLookup(lookupId.text, lookupData.text) }
                    }
                    LogosText { Layout.fillWidth: true; visible: root.results.length === 0; text: root.running ? "No matching service records found yet." : "No results are available while the node is stopped."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary; wrapMode: Text.Wrap }
                    Repeater {
                        model: root.results
                        LogosFrame {
                            required property var modelData
                            Layout.fillWidth: true; backgroundColor: Theme.palette.background; borderColor: Theme.palette.borderSecondary; radius: Theme.spacing.radiusSmall; padding: Theme.spacing.medium
                            ColumnLayout {
                                anchors.fill: parent; spacing: Theme.spacing.tiny
                                LogosText { Layout.fillWidth: true; text: modelData.peerId; font.pixelSize: Theme.typography.secondaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text; elide: Text.ElideRight }
                                LogosText { Layout.fillWidth: true; text: (modelData.addrs || []).join("\n"); font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary; wrapMode: Text.Wrap }
                                Repeater {
                                    model: modelData.services || []
                                    LogosText { required property var modelData; Layout.fillWidth: true; text: modelData.id + (modelData.data.length > 0 ? ": " + modelData.data : ""); font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
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
        function onServiceAdvertised(serviceId) { advertiseId.text = ""; advertiseData.text = ""; root.successMessage = "Advertising " + serviceId + "." }
        function onServiceStoppedAdvertising(serviceId) { root.successMessage = "Stopped advertising " + serviceId + "." }
        function onServiceLookupCompleted(serviceId) { root.successMessage = "Service lookup completed for " + serviceId + "." }
    }
}

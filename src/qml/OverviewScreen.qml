import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: null
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var config: backend && backend.nodeConfig !== undefined ? backend.nodeConfig : ({})

    readonly property int statusStopped: 0
    readonly property int statusStarting: 1
    readonly property int statusRunning: 2
    readonly property int statusStopping: 3

    readonly property bool running: backend && backend.status === statusRunning
    readonly property bool busy: backend && (backend.status === statusStarting || backend.status === statusStopping)
    readonly property bool stopping: backend && backend.status === statusStopping
    readonly property color actionColor: root.running ? "#DC2626" : "#16A34A"
    readonly property color actionHoverColor: root.running ? "#B91C1C" : "#15803D"

    function statusText() {
        if (!backend)
            return "Stopped"
        switch (backend.status) {
        case statusStarting:
            return "Starting"
        case statusRunning:
            return "Running"
        case statusStopping:
            return "Stopping"
        default:
            return "Stopped"
        }
    }

    function toggleNode() {
        if (!backend || busy)
            return
        if (running)
            backend.stop()
        else
            backend.start()
    }

    function backendString(name) {
        if (!backend || backend[name] === undefined || backend[name] === null)
            return ""
        return backend[name]
    }

    function backendCount(name) {
        if (!backend || backend[name] === undefined || backend[name] === null)
            return 0
        return backend[name]
    }

    function metric(name) { return metrics[name] === undefined ? 0 : metrics[name] }
    function formatBytes(value) {
        var number = Number(value || 0); var units = ["B", "KiB", "MiB", "GiB", "TiB"]; var unit = 0
        while (number >= 1024 && unit < units.length - 1) { number /= 1024; ++unit }
        return (unit === 0 ? number.toFixed(0) : number.toFixed(1)) + " " + units[unit]
    }
    function formatDuration(seconds) {
        seconds = Number(seconds || 0)
        if (seconds < 60) return Math.floor(seconds) + "s"
        if (seconds < 3600) return Math.floor(seconds / 60) + "m"
        if (seconds < 86400) return Math.floor(seconds / 3600) + "h " + Math.floor(seconds % 3600 / 60) + "m"
        return Math.floor(seconds / 86400) + "d " + Math.floor(seconds % 86400 / 3600) + "h"
    }
    function healthWarnings() {
        var warnings = []
        if (!running) return warnings
        if (backendCount("connectedPeers") === 0) warnings.push("No connected peers")
        if (config.maxConnections && backendCount("connectedPeers") / config.maxConnections >= 0.9) warnings.push("Connection capacity above 90%")
        if (metric("streamCapRejections") > 0) warnings.push("Protocol stream caps have rejected requests")
        if ((config.autonat && String(metric("autonatReachability")).indexOf("Not") === 0) || (config.autonatV2 && String(metric("autonatV2Reachability")).indexOf("Not") === 0)) warnings.push("Node is not publicly reachable")
        if (config.mountKad && metric("dhtRoutingPeers") === 0) warnings.push("DHT routing table is empty")
        if (config.mountGossipsub && metric("gossipsubNoPeerTopics") > 0) warnings.push("GossipSub topics have no mesh peers")
        if (metric("gossipsubQueueDrops") > 0) warnings.push("GossipSub queues have dropped messages")
        if (metric("discoveryPendingActions") > 0) warnings.push("Service discovery has pending actions")
        return warnings
    }

    Component.onCompleted: {
        if (backend)
            backend.refreshOverview()
    }

    LogosScrollView {
        id: scroll

        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Theme.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.spacing.small

                LogosText {
                    text: "Overview"
                    font.pixelSize: Theme.typography.titleText
                    color: Theme.palette.text
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                implicitHeight: 116
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacing.large

                    ColumnLayout {
                        Layout.preferredWidth: 128
                        spacing: Theme.spacing.tiny

                        LogosText {
                            text: "Status"
                            font.pixelSize: Theme.typography.secondaryText
                            color: Theme.palette.textTertiary
                        }

                        RowLayout {
                            spacing: Theme.spacing.small

                            Rectangle {
                                Layout.preferredWidth: 9
                                Layout.preferredHeight: 9
                                radius: 9
                                color: root.running ? Theme.palette.success
                                                    : root.busy ? Theme.palette.warning
                                                                : Theme.palette.textTertiary
                            }

                            LogosText {
                                text: root.statusText()
                                font.pixelSize: Theme.typography.primaryText
                                color: Theme.palette.text
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Theme.palette.borderSecondary
                    }

                    CopyField {
                        Layout.fillWidth: true
                        label: "PeerID"
                        value: root.backendString("peerId")
                        placeholder: "Start the node to read PeerID"
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Theme.palette.borderSecondary
                    }

                    CopyField {
                        Layout.fillWidth: true
                        label: "Listener address"
                        value: root.backendString("listenAddress")
                        placeholder: "Start the node to read listen address"
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Theme.palette.borderSecondary
                    }

                    Rectangle {
                        id: nodeActionButton
                        objectName: root.running ? "stopButton" : "startButton"
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 42
                        radius: Theme.spacing.radiusLarge
                        color: {
                            if (!nodeActionMouse.enabled)
                                return Theme.palette.backgroundMuted
                            return nodeActionMouse.pressed || nodeActionMouse.containsMouse
                                ? root.actionHoverColor
                                : root.actionColor
                        }
                        border.width: 1
                        border.color: color

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacing.small

                            Image {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                source: Qt.resolvedUrl(root.running ? "assets/stop.svg" : "assets/run.svg")
                                sourceSize: Qt.size(36, 36)
                                fillMode: Image.PreserveAspectFit
                                opacity: nodeActionMouse.enabled ? 1.0 : 0.45
                            }

                            LogosText {
                                text: root.running ? "Stop" : "Run"
                                font.pixelSize: Theme.typography.secondaryText
                                font.weight: Theme.typography.weightMedium
                                color: nodeActionMouse.enabled ? Theme.palette.text : Theme.palette.textMuted
                            }
                        }

                        MouseArea {
                            id: nodeActionMouse
                            anchors.fill: parent
                            enabled: !root.stopping
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.toggleNode()
                        }
                    }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                visible: root.running
                backgroundColor: root.healthWarnings().length > 0 ? Theme.palette.backgroundSecondary : Theme.palette.backgroundSecondary
                borderColor: root.healthWarnings().length > 0 ? Theme.palette.warning : Theme.palette.success
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.medium
                RowLayout {
                    anchors.fill: parent
                    LogosText { text: root.healthWarnings().length > 0 ? "Attention" : "Node healthy"; font.weight: Theme.typography.weightMedium; color: root.healthWarnings().length > 0 ? Theme.palette.warning : Theme.palette.success }
                    LogosText { Layout.fillWidth: true; text: root.healthWarnings().length > 0 ? root.healthWarnings().join("  •  ") : "No active health warnings."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1050 ? 4 : width > 680 ? 2 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium

                StatCard {
                    Layout.fillWidth: true
                    title: "Connected Peers"
                    value: root.backendCount("connectedPeers")
                    iconSource: "assets/peers.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Inbound / Outbound"
                    value: (root.backend && root.backend.inboundPeers ? root.backend.inboundPeers.length : 0) + " / " + (root.backend && root.backend.outboundPeers ? root.backend.outboundPeers.length : 0)
                    iconSource: "assets/peers.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Active Streams"
                    value: root.backendCount("activeStreams")
                    iconSource: "assets/streams.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Gossipsub Topics"
                    value: root.backendCount("gossipsubTopics")
                    iconSource: "assets/gossipsub.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "DHT Routing Peers"
                    value: root.metric("dhtRoutingPeers")
                    iconSource: "assets/dht.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Relay Reservations"
                    value: root.backendCount("relayReservations")
                    iconSource: "assets/relay.svg"
                }

                StatCard { Layout.fillWidth: true; title: "Receive rate"; value: root.formatBytes(root.metric("trafficReceiveRate")) + "/s"; iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Send rate"; value: root.formatBytes(root.metric("trafficSendRate")) + "/s"; iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Reachability"; value: config.autonatV2 ? root.metric("autonatV2Reachability") : config.autonat ? root.metric("autonatReachability") : "Not monitored"; iconSource: "assets/network.svg" }
                StatCard { Layout.fillWidth: true; title: "Uptime"; value: root.formatDuration(root.metric("nodeUptimeSeconds")); iconSource: "assets/overview.svg" }
            }
        }
    }
}

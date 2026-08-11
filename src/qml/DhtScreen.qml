import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: MockBackend
    readonly property bool running: backend && backend.status === 2
    readonly property bool featureEnabled: !backend || !backend.nodeConfig || backend.nodeConfig.mountKad !== false
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var results: backend && backend.dhtLookupResults !== undefined ? backend.dhtLookupResults : []
    readonly property var messageTypes: metrics.dhtMessagesByType || []
    readonly property var bucketSizes: metrics.dhtBucketSizes || []
    property string successMessage: ""

    function metric(name) {
        return metrics[name] === undefined ? 0 : metrics[name]
    }

    function refresh() {
        if (backend)
            backend.refreshMetrics()
    }

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

                LogosText {
                    text: "DHT"
                    font.pixelSize: Theme.typography.titleText
                    color: Theme.palette.text
                }

                Item {
                    Layout.fillWidth: true
                }

                LogosButton {
                    text: "Refresh"
                    enabled: root.running && root.featureEnabled
                    onClicked: root.refresh()
                }
            }

            LogosText {
                Layout.fillWidth: true
                visible: !root.running
                text: "Start the node from Overview to search the Kademlia DHT."
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.warning
                wrapMode: Text.Wrap
            }

            LogosText {
                Layout.fillWidth: true
                visible: root.running && !root.featureEnabled
                text: "Kademlia DHT is disabled in Settings. Stop the node, enable it, then apply the configuration."
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.warning
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 680 ? 3 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium

                StatCard {
                    Layout.fillWidth: true
                    title: "Routing peers"
                    value: root.metric("dhtRoutingPeers")
                    iconSource: "assets/dht.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Routing buckets"
                    value: root.metric("dhtRoutingBuckets")
                    iconSource: "assets/dht.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Estimated network"
                    value: root.metric("dhtNetworkSizeEstimate")
                    iconSource: "assets/dht.svg"
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 4 : width > 500 ? 2 : 1
                columnSpacing: Theme.spacing.medium; rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Insertions"; value: root.metric("dhtRoutingInsertions"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Replacements"; value: root.metric("dhtRoutingReplacements"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Evictions"; value: root.metric("dhtRoutingEvictions"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Liveness failures"; value: root.metric("dhtLivenessFailures"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Lookup follow-ups"; value: root.metric("dhtLookupFollowups"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Provider rejections"; value: root.metric("dhtProviderRejections"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Republished regions"; value: root.metric("dhtRepublishedRegions"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Republished keys"; value: root.metric("dhtRepublishedKeys"); iconSource: "assets/dht.svg" }
            }

            LogosFrame {
                Layout.fillWidth: true
                visible: root.messageTypes.length > 0
                backgroundColor: Theme.palette.backgroundSecondary; borderColor: Theme.palette.borderSecondary; radius: Theme.spacing.radiusLarge; padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.small
                    LogosText { text: "DHT messages by operation"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    Repeater {
                        model: root.messageTypes
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 44; radius: Theme.spacing.radiusSmall; color: Theme.palette.background
                            RowLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacing.small
                                LogosText { Layout.fillWidth: true; text: modelData.type; color: Theme.palette.text }
                                LogosText { text: "Messages ↓ " + (modelData.messagesReceived || 0) + " ↑ " + (modelData.messagesSent || 0); color: Theme.palette.textSecondary }
                                LogosText { text: "Bytes ↓ " + (modelData.bytesReceived || 0) + " ↑ " + (modelData.bytesSent || 0); color: Theme.palette.textSecondary }
                            }
                        }
                    }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                visible: root.bucketSizes.length > 0
                backgroundColor: Theme.palette.backgroundSecondary; borderColor: Theme.palette.borderSecondary; radius: Theme.spacing.radiusLarge; padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.small
                    LogosText { text: "Routing bucket occupancy"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    Repeater {
                        model: root.bucketSizes
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            LogosText { Layout.preferredWidth: 120; text: "Bucket " + modelData.bucket; color: Theme.palette.textSecondary }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: Theme.palette.backgroundMuted; Rectangle { height: parent.height; radius: parent.radius; color: Theme.palette.success; width: parent.width * Math.min(1, Number(modelData.peers || 0) / 20) } }
                            LogosText { text: modelData.peers; color: Theme.palette.text }
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

                    LogosText {
                        text: "Find closest peers"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        LogosTextField {
                            id: peerIdField
                            Layout.fillWidth: true
                            enabled: root.running && root.featureEnabled
                            placeholderText: "Peer ID"
                            onTextChanged: root.successMessage = ""
                        }

                        LogosButton {
                            text: "Find"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running && root.featureEnabled && peerIdField.text.trim().length > 0
                            onClicked: root.backend.dhtFindPeer(peerIdField.text)
                        }
                    }

                    LogosText {
                        Layout.fillWidth: true
                        visible: root.successMessage.length > 0
                        text: root.successMessage
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.success
                        wrapMode: Text.Wrap
                    }

                    LogosText {
                        Layout.fillWidth: true
                        visible: root.results.length === 0
                        text: !root.running ? "No results are available while the node is stopped."
                                            : !root.featureEnabled ? "DHT is disabled in Settings."
                                                                   : "Enter a peer ID to find the closest DHT peers."
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.textTertiary
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: root.results

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: resultText.implicitHeight + 2 * Theme.spacing.small
                            radius: Theme.spacing.radiusSmall
                            color: Theme.palette.background
                            border.width: 1
                            border.color: Theme.palette.borderSecondary

                            LogosText {
                                id: resultText
                                anchors.fill: parent
                                anchors.margins: Theme.spacing.small
                                text: modelData
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.text
                                elide: Text.ElideRight
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

        function onDhtLookupCompleted(peerId) {
            root.successMessage = "DHT lookup completed for " + peerId + "."
        }
    }
}

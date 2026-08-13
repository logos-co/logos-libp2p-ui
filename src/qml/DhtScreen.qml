import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls
import "InputValidation.js" as InputValidation

Item {
    id: root

    property var backend: null
    property int selectedTab: 0
    readonly property bool running: backend && backend.status === 2
    readonly property bool featureEnabled: !backend || !backend.nodeConfig || backend.nodeConfig.mountKad !== false
    readonly property bool discoveryEnabled: !backend || !backend.nodeConfig || backend.nodeConfig.mountServiceDiscovery !== false
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var closestPeers: backend && backend.dhtLookupResults !== undefined ? backend.dhtLookupResults : []
    readonly property var valueResult: backend && backend.dhtValueResult !== undefined ? backend.dhtValueResult : ({})
    readonly property var providers: backend && backend.dhtProviderResults !== undefined ? backend.dhtProviderResults : []
    readonly property var providedCids: backend && backend.dhtProvidedCids !== undefined ? backend.dhtProvidedCids : []
    readonly property var resolvedPeer: backend && backend.dhtResolvedPeer !== undefined ? backend.dhtResolvedPeer : ({})
    readonly property var randomRecords: backend && backend.dhtRandomRecords !== undefined ? backend.dhtRandomRecords : []
    readonly property var operation: backend && backend.dhtOperationState !== undefined ? backend.dhtOperationState : ({ "busy": false })
    readonly property var history: backend && backend.dhtOperationHistory !== undefined ? backend.dhtOperationHistory : []
    readonly property var messageTypes: metrics.dhtMessagesByType || []
    readonly property var bucketSizes: metrics.dhtBucketSizes || []
    readonly property bool canOperate: running && featureEnabled && !operation.busy

    function metric(name) {
        return metrics[name] === undefined ? 0 : metrics[name]
    }

    function joinValues(values) {
        if (!values || values.length === 0)
            return "No addresses"
        return Array.prototype.join.call(values, "\n")
    }

    function quorumValue(index) {
        return [-1, 1, 2, 3, 5][index]
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

                ColumnLayout {
                    spacing: Theme.spacing.tiny
                    LogosText {
                        text: "DHT"
                        font.pixelSize: Theme.typography.titleText
                        color: Theme.palette.text
                    }
                    LogosText {
                        text: root.running && root.featureEnabled
                              ? "Connected · " + root.metric("dhtRoutingPeers") + " routing peers · Server mode"
                              : root.running ? "Disabled" : "Node stopped"
                        font.pixelSize: Theme.typography.secondaryText
                        color: root.running && root.featureEnabled ? Theme.palette.success : Theme.palette.textTertiary
                    }
                }

                Item { Layout.fillWidth: true }

                LogosButton {
                    text: "Refresh routing"
                    enabled: root.canOperate && root.backend.peerId.length > 0
                    onClicked: root.backend.dhtRefreshRouting()
                }
                LogosButton {
                    text: "Refresh metrics"
                    enabled: root.running && root.featureEnabled
                    onClicked: root.refresh()
                }
            }

            LogosText {
                Layout.fillWidth: true
                visible: !root.running || !root.featureEnabled
                text: !root.running
                      ? "Start the node from Overview to use the Kademlia DHT."
                      : "Kademlia DHT is disabled in Settings. Stop the node, enable it, then apply the configuration."
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.warning
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 680 ? 3 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium

                StatCard { Layout.fillWidth: true; title: "Routing peers"; value: root.metric("dhtRoutingPeers"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Routing buckets"; value: root.metric("dhtRoutingBuckets"); iconSource: "assets/dht.svg" }
                StatCard { Layout.fillWidth: true; title: "Estimated network"; value: root.metric("dhtNetworkSizeEstimate"); iconSource: "assets/dht.svg" }
            }

            LogosFrame {
                Layout.fillWidth: true
                visible: root.operation.operation !== undefined
                backgroundColor: root.operation.success === false ? Theme.palette.backgroundSecondary : Theme.palette.background
                borderColor: root.operation.success === false ? Theme.palette.warning : Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.medium

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacing.medium
                    LogosText {
                        text: root.operation.busy ? "Working" : root.operation.success === false ? "Failed" : "Completed"
                        color: root.operation.busy ? Theme.palette.warning
                              : root.operation.success === false ? Theme.palette.warning : Theme.palette.success
                        font.weight: Theme.typography.weightMedium
                    }
                    LogosText {
                        Layout.fillWidth: true
                        text: (root.operation.operation || "")
                              + (root.operation.target ? " · " + root.operation.target : "")
                              + (root.operation.message ? " — " + root.operation.message : "")
                        color: Theme.palette.text
                        elide: Text.ElideMiddle
                    }
                    LogosText {
                        visible: !root.operation.busy && root.operation.durationMs !== undefined
                        text: root.operation.durationMs + " ms"
                        color: Theme.palette.textTertiary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: tabRow.implicitHeight + 2
                color: "transparent"
                border.width: 0

                RowLayout {
                    id: tabRow
                    anchors.left: parent.left
                    spacing: Theme.spacing.small

                    Repeater {
                        model: ["Values", "Providers", "Peers", "Diagnostics"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            Layout.preferredWidth: tabLabel.implicitWidth + 2 * Theme.spacing.medium
                            Layout.preferredHeight: 40
                            radius: Theme.spacing.radiusSmall
                            color: root.selectedTab === index ? Theme.palette.backgroundButton : "transparent"
                            border.width: root.selectedTab === index ? 1 : 0
                            border.color: Theme.palette.borderSecondary
                            LogosText {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: root.selectedTab === index ? Theme.palette.text : Theme.palette.textSecondary
                                font.weight: root.selectedTab === index ? Theme.typography.weightMedium : Theme.typography.weightRegular
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedTab = index
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedTab === 0
                spacing: Theme.spacing.large

                GridLayout {
                    Layout.fillWidth: true
                    columns: width > 760 ? 2 : 1
                    columnSpacing: Theme.spacing.large
                    rowSpacing: Theme.spacing.large

                    LogosFrame {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        backgroundColor: Theme.palette.backgroundSecondary
                        borderColor: Theme.palette.borderSecondary
                        radius: Theme.spacing.radiusLarge
                        padding: Theme.spacing.large
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing.medium
                            LogosText { text: "Put value"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                            LogosText { Layout.fillWidth: true; text: "Store a UTF-8 value on the DHT nodes closest to the key."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                            LogosTextField { id: putKey; Layout.fillWidth: true; placeholderText: "Key"; enabled: root.canOperate }
                            LogosTextArea { id: putValue; Layout.fillWidth: true; Layout.preferredHeight: 130; placeholderText: "Value"; enabled: root.canOperate }
                            RowLayout {
                                Layout.fillWidth: true
                                LogosComboBox { id: putEncoding; Layout.preferredWidth: 150; model: ["UTF-8", "Base64", "Hex"]; enabled: root.canOperate }
                                Item { Layout.fillWidth: true }
                                LogosButton {
                                    text: "Put value"
                                    variant: LogosButton.Variant.Primary
                                    enabled: root.canOperate && putKey.text.trim().length > 0 && putValue.text.length > 0
                                    onClicked: root.backend.dhtPutValue(putKey.text, putValue.text, putEncoding.currentText)
                                }
                            }
                        }
                    }

                    LogosFrame {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        backgroundColor: Theme.palette.backgroundSecondary
                        borderColor: Theme.palette.borderSecondary
                        radius: Theme.spacing.radiusLarge
                        padding: Theme.spacing.large
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing.medium
                            LogosText { text: "Get value"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                            LogosText { Layout.fillWidth: true; text: "Retrieve a value. A larger quorum asks more peers to agree and may take longer."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                            LogosTextField { id: getKey; Layout.fillWidth: true; placeholderText: "Key"; enabled: root.canOperate }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    spacing: Theme.spacing.tiny
                                    LogosText { text: "Quorum"; color: Theme.palette.textTertiary; font.pixelSize: Theme.typography.secondaryText }
                                    LogosComboBox { id: getQuorum; Layout.preferredWidth: 180; model: ["Configured default", "1 peer", "2 peers", "3 peers", "5 peers"]; enabled: root.canOperate }
                                }
                                Item { Layout.fillWidth: true }
                                LogosButton {
                                    text: "Get value"
                                    variant: LogosButton.Variant.Primary
                                    enabled: root.canOperate && getKey.text.trim().length > 0
                                    onClicked: root.backend.dhtGetValue(getKey.text, root.quorumValue(getQuorum.currentIndex))
                                }
                            }
                        }
                    }
                }

                LogosFrame {
                    Layout.fillWidth: true
                    visible: root.valueResult.kind !== undefined
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.medium
                        RowLayout {
                            Layout.fillWidth: true
                            LogosText { text: root.valueResult.kind === "cid" ? "Generated CID" : "Latest value result"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                            Item { Layout.fillWidth: true }
                            LogosText { visible: root.valueResult.size !== undefined; text: root.valueResult.size + " bytes"; color: Theme.palette.textTertiary }
                        }
                        CopyField { Layout.fillWidth: true; label: "Key"; value: root.valueResult.key || "" }
                        CopyField { Layout.fillWidth: true; visible: root.valueResult.kind === "cid"; label: "CID"; value: root.valueResult.cid || "" }
                        CopyField { Layout.fillWidth: true; visible: root.valueResult.kind === "get" && root.valueResult.validUtf8 === true; label: "UTF-8 value"; value: root.valueResult.text || "" }
                        CopyField { Layout.fillWidth: true; visible: root.valueResult.base64 !== undefined; label: "Base64"; value: root.valueResult.base64 || "" }
                        LogosText { Layout.fillWidth: true; visible: root.valueResult.kind === "get" && root.valueResult.validUtf8 === false; text: "The value is binary or invalid UTF-8; use the Base64 representation."; color: Theme.palette.warning; wrapMode: Text.Wrap }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedTab === 1
                spacing: Theme.spacing.large

                LogosFrame {
                    Layout.fillWidth: true
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.medium
                        LogosText { text: "Provider records"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        LogosText { Layout.fillWidth: true; text: "Announce that this node provides a CID, or discover peers already advertising it."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                        LogosTextField { id: providerCid; Layout.fillWidth: true; placeholderText: "CID"; enabled: root.canOperate }
                        LogosText { Layout.fillWidth: true; visible: providerCid.text.trim().length > 0 && !InputValidation.isCid(providerCid.text); text: "Enter a valid CIDv0 or CIDv1."; color: Theme.palette.warning; wrapMode: Text.Wrap }
                        RowLayout {
                            Layout.fillWidth: true
                            LogosButton { text: "Find providers"; enabled: root.canOperate && InputValidation.isCid(providerCid.text); onClicked: root.backend.dhtGetProviders(providerCid.text) }
                            Item { Layout.fillWidth: true }
                            LogosButton { text: "Announce once"; enabled: root.canOperate && InputValidation.isCid(providerCid.text); onClicked: root.backend.dhtAddProvider(providerCid.text) }
                            LogosButton { text: "Keep announcing"; variant: LogosButton.Variant.Primary; enabled: root.canOperate && InputValidation.isCid(providerCid.text); onClicked: root.backend.dhtStartProviding(providerCid.text) }
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
                        LogosText { text: "Generate CID from text"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        RowLayout {
                            Layout.fillWidth: true
                            LogosTextField { id: cidKey; Layout.fillWidth: true; placeholderText: "Content name or text"; enabled: root.canOperate }
                            LogosButton { text: "Generate"; enabled: root.canOperate && cidKey.text.trim().length > 0; onClicked: root.backend.dhtCreateCid(cidKey.text) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.valueResult.kind === "cid"
                            CopyField { Layout.fillWidth: true; label: "Generated CID"; value: root.valueResult.cid || "" }
                            LogosButton { text: "Use CID"; onClicked: providerCid.text = root.valueResult.cid || "" }
                        }
                    }
                }

                LogosFrame {
                    Layout.fillWidth: true
                    visible: root.providedCids.length > 0
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.small
                        LogosText { text: "My persistent announcements"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        LogosText { Layout.fillWidth: true; text: "Tracked for this node session. Stopping prevents future re-announcements; existing remote records expire separately."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                        Repeater {
                            model: root.providedCids
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: providedRow.implicitHeight + 2 * Theme.spacing.small
                                radius: Theme.spacing.radiusSmall
                                color: Theme.palette.background
                                RowLayout {
                                    id: providedRow
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing.small
                                    LogosText { Layout.fillWidth: true; text: modelData; color: Theme.palette.text; elide: Text.ElideMiddle }
                                    LogosButton { text: "Stop"; enabled: root.canOperate; onClicked: root.backend.dhtStopProviding(modelData) }
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
                        spacing: Theme.spacing.small
                        LogosText { text: "Discovered providers"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        LogosText { Layout.fillWidth: true; visible: root.providers.length === 0; text: "No provider results yet."; color: Theme.palette.textTertiary }
                        Repeater {
                            model: root.providers
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: providerRow.implicitHeight + 2 * Theme.spacing.small
                                radius: Theme.spacing.radiusSmall
                                color: Theme.palette.background
                                border.width: 1
                                border.color: Theme.palette.borderSecondary
                                RowLayout {
                                    id: providerRow
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing.small
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        CopyField { Layout.fillWidth: true; label: "Peer ID"; value: modelData.peerId || "" }
                                        CopyField { Layout.fillWidth: true; label: "Addresses"; value: root.joinValues(modelData.addrs) }
                                    }
                                    LogosButton { text: "Connect"; enabled: root.running && modelData.addrs && modelData.addrs.length > 0; onClicked: root.backend.connectPeer(modelData.peerId, modelData.addrs[0]) }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedTab === 2
                spacing: Theme.spacing.large

                LogosFrame {
                    Layout.fillWidth: true
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.medium
                        LogosText { text: "Peer lookup"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        LogosText { Layout.fillWidth: true; text: "Resolve one peer and its addresses, or inspect the peers closest to its DHT key."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                        LogosTextField { id: peerIdField; Layout.fillWidth: true; placeholderText: "Peer ID"; enabled: root.canOperate }
                        LogosText { Layout.fillWidth: true; visible: peerIdField.text.trim().length > 0 && !InputValidation.isPeerId(peerIdField.text); text: "Enter a valid base58 or CIDv1 libp2p peer ID."; color: Theme.palette.warning; wrapMode: Text.Wrap }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            LogosButton { text: "Find closest"; enabled: root.canOperate && InputValidation.isPeerId(peerIdField.text); onClicked: root.backend.dhtFindPeer(peerIdField.text) }
                            LogosButton { text: "Resolve peer"; variant: LogosButton.Variant.Primary; enabled: root.canOperate && InputValidation.isPeerId(peerIdField.text); onClicked: root.backend.dhtResolvePeer(peerIdField.text) }
                        }
                    }
                }

                LogosFrame {
                    Layout.fillWidth: true
                    visible: root.resolvedPeer.peerId !== undefined
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.medium
                        LogosText { text: "Resolved peer"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        CopyField { Layout.fillWidth: true; label: "Peer ID"; value: root.resolvedPeer.peerId || "" }
                        CopyField { Layout.fillWidth: true; label: "Addresses"; value: root.joinValues(root.resolvedPeer.addrs) }
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
                        spacing: Theme.spacing.small
                        LogosText { text: "Closest peers"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        LogosText { Layout.fillWidth: true; visible: root.closestPeers.length === 0; text: "No closest-peer results yet."; color: Theme.palette.textTertiary }
                        Repeater {
                            model: root.closestPeers
                            CopyField { required property var modelData; Layout.fillWidth: true; label: "Peer ID"; value: modelData }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedTab === 3
                spacing: Theme.spacing.large

                GridLayout {
                    Layout.fillWidth: true
                    columns: width > 850 ? 4 : width > 500 ? 2 : 1
                    columnSpacing: Theme.spacing.medium
                    rowSpacing: Theme.spacing.medium
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
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.small
                        LogosText { text: "DHT messages by operation"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        Repeater {
                            model: root.messageTypes
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 44
                                radius: Theme.spacing.radiusSmall
                                color: Theme.palette.background
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing.small
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
                    backgroundColor: Theme.palette.backgroundSecondary
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.small
                        LogosText { text: "Routing bucket occupancy"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        Repeater {
                            model: root.bucketSizes
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                LogosText { Layout.preferredWidth: 120; text: "Bucket " + modelData.bucket; color: Theme.palette.textSecondary }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: Theme.palette.backgroundMuted
                                    Rectangle { height: parent.height; radius: parent.radius; color: Theme.palette.success; width: parent.width * Math.min(1, Number(modelData.peers || 0) / 20) }
                                }
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
                        spacing: Theme.spacing.small
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                LogosText { text: "Advanced discovery records"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                                LogosText { Layout.fillWidth: true; text: "Extended peer records from a random service-discovery DHT walk."; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                            }
                            LogosButton { text: "Lookup random records"; enabled: root.canOperate && root.discoveryEnabled; onClicked: root.backend.dhtGetRandomRecords() }
                        }
                        LogosText { Layout.fillWidth: true; visible: !root.discoveryEnabled; text: "Enable Service Discovery in Settings to use this operation."; color: Theme.palette.warning; wrapMode: Text.Wrap }
                        Repeater {
                            model: root.randomRecords
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: recordColumn.implicitHeight + 2 * Theme.spacing.small
                                radius: Theme.spacing.radiusSmall
                                color: Theme.palette.background
                                ColumnLayout {
                                    id: recordColumn
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing.small
                                    CopyField { Layout.fillWidth: true; label: "Peer ID"; value: modelData.peerId || "" }
                                    CopyField { Layout.fillWidth: true; label: "Addresses"; value: root.joinValues(modelData.addrs) }
                                    LogosText { Layout.fillWidth: true; text: "Sequence " + (modelData.seqNo || 0) + " · " + ((modelData.addrs || []).length) + " address(es) · " + ((modelData.services || []).length) + " service(s)"; color: Theme.palette.textSecondary }
                                    Repeater {
                                        model: modelData.services || []
                                        CopyField {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            label: "Service " + (modelData.id || "") + " (Base64)"
                                            value: modelData.data || ""
                                        }
                                    }
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
                        spacing: Theme.spacing.small
                        RowLayout {
                            Layout.fillWidth: true
                            LogosText { text: "Operation history"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                            Item { Layout.fillWidth: true }
                            LogosButton { text: "Clear"; enabled: root.history.length > 0; onClicked: root.backend.clearDhtOperationHistory() }
                        }
                        LogosText { Layout.fillWidth: true; visible: root.history.length === 0; text: "No DHT operations in this session."; color: Theme.palette.textTertiary }
                        Repeater {
                            model: root.history
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: historyRow.implicitHeight + 2 * Theme.spacing.small
                                radius: Theme.spacing.radiusSmall
                                color: Theme.palette.background
                                RowLayout {
                                    id: historyRow
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing.small
                                    LogosText { text: modelData.success ? "✓" : "!"; color: modelData.success ? Theme.palette.success : Theme.palette.warning }
                                    LogosText { Layout.preferredWidth: 170; text: modelData.operation; color: Theme.palette.text }
                                    LogosText { Layout.fillWidth: true; text: modelData.target || modelData.message || ""; color: Theme.palette.textSecondary; elide: Text.ElideMiddle }
                                    LogosText { text: modelData.durationMs + " ms"; color: Theme.palette.textTertiary }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

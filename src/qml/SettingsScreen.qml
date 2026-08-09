import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: MockBackend
    property bool loading: false
    property bool dirty: false
    property string successMessage: ""

    function markDirty() {
        if (!loading)
            dirty = true
    }

    function lines(text) {
        var values = []
        var raw = text.split("\n")
        for (var index = 0; index < raw.length; ++index) {
            var value = raw[index].trim()
            if (value.length > 0)
                values.push(value)
        }
        return values
    }

    function refreshIntervalIndex(intervalMs) {
        if (intervalMs === 0)
            return 0
        if (intervalMs === 10000)
            return 2
        if (intervalMs === 30000)
            return 3
        return 1
    }

    function refreshIntervalValue(index) {
        return [0, 5000, 10000, 30000][index]
    }

    function loadConfig() {
        if (!backend)
            return

        loading = true
        var config = backend.nodeConfig || ({})
        listenAddresses.text = (config.addrs || []).join("\n")
        transport.currentIndex = config.transport === "quic" ? 1 : 0
        maxConnections.value = config.maxConnections || 50
        maxInboundConnections.value = config.maxInConnections || 25
        maxOutboundConnections.value = config.maxOutConnections || 25
        maxConnectionsPerPeer.value = config.maxConnsPerPeer || 1
        mountGossipsub.checked = config.mountGossipsub !== false
        mountKad.checked = config.mountKad !== false
        mountServiceDiscovery.checked = config.mountServiceDiscovery !== false
        gossipsubTriggerSelf.checked = config.gossipsubTriggerSelf !== false
        autonat.checked = config.autonat === true
        autonatV2.checked = config.autonatV2 === true
        autonatV2Server.checked = config.autonatV2Server === true
        circuitRelay.checked = config.circuitRelay === true
        circuitRelayClient.checked = config.circuitRelayClient === true
        refreshInterval.currentIndex = refreshIntervalIndex(backend.metricsRefreshIntervalMs)

        bootstrapNodes.clear()
        var nodes = config.bootstrapNodes || []
        for (var index = 0; index < nodes.length; ++index) {
            bootstrapNodes.append({
                                      "peerId": nodes[index].peerId || "",
                                      "addrsText": (nodes[index].addrs || []).join("\n")
                                  })
        }
        dirty = false
        loading = false
    }

    function draftConfig() {
        var nodes = []
        for (var index = 0; index < bootstrapNodes.count; ++index) {
            var node = bootstrapNodes.get(index)
            nodes.push({ "peerId": node.peerId.trim(), "addrs": lines(node.addrsText) })
        }
        return {
            "addrs": lines(listenAddresses.text),
            "transport": transport.currentIndex === 1 ? "quic" : "tcp",
            "maxConnections": maxConnections.value,
            "maxInConnections": maxInboundConnections.value,
            "maxOutConnections": maxOutboundConnections.value,
            "maxConnsPerPeer": maxConnectionsPerPeer.value,
            "mountGossipsub": mountGossipsub.checked,
            "mountKad": mountKad.checked,
            "mountServiceDiscovery": mountServiceDiscovery.checked,
            "gossipsubTriggerSelf": gossipsubTriggerSelf.checked,
            "autonat": autonat.checked,
            "autonatV2": autonatV2.checked,
            "autonatV2Server": autonatV2Server.checked,
            "circuitRelay": circuitRelay.checked,
            "circuitRelayClient": circuitRelayClient.checked,
            "bootstrapNodes": nodes
        }
    }

    function validDraft() {
        if (lines(listenAddresses.text).length === 0)
            return false
        for (var index = 0; index < bootstrapNodes.count; ++index) {
            var node = bootstrapNodes.get(index)
            if (node.peerId.trim().length === 0 || lines(node.addrsText).length === 0)
                return false
        }
        return true
    }

    function apply() {
        if (backend)
            backend.applyNodeConfig(draftConfig())
    }

    function copyJson() {
        jsonPreview.selectAll()
        jsonPreview.copy()
        jsonPreview.deselect()
        successMessage = "Configuration JSON copied."
    }

    Component.onCompleted: loadConfig()

    ListModel {
        id: bootstrapNodes
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

                ColumnLayout {
                    spacing: Theme.spacing.tiny

                    LogosText {
                        text: "Settings"
                        font.pixelSize: Theme.typography.titleText
                        color: Theme.palette.text
                    }

                    LogosText {
                        text: root.dirty ? "Unsaved changes" : "Applied configuration"
                        font.pixelSize: Theme.typography.secondaryText
                        color: root.dirty ? Theme.palette.warning : Theme.palette.textTertiary
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                LogosButton {
                    text: "Apply"
                    variant: LogosButton.Variant.Primary
                    enabled: root.backend && root.backend.settingsEditable && root.dirty && root.validDraft()
                    onClicked: root.apply()
                }
            }

            LogosText {
                Layout.fillWidth: true
                visible: root.backend && !root.backend.settingsEditable
                text: "Stop the node from Overview to change its configuration."
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
                        text: "Network"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }

                    LogosText {
                        text: "Listen multiaddresses, one per line"
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.textSecondary
                    }

                    LogosTextArea {
                        id: listenAddresses
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        enabled: root.backend && root.backend.settingsEditable
                        placeholderText: "/ip4/127.0.0.1/tcp/0"
                        onTextChanged: root.markDirty()
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.tiny
                            LogosText { text: "Transport"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary }
                            LogosComboBox {
                                id: transport
                                Layout.fillWidth: true
                                model: ["TCP", "QUIC"]
                                enabled: root.backend && root.backend.settingsEditable
                                onActivated: root.markDirty()
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    LogosText {
                        text: "Bootstrap peers"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }

                    Repeater {
                        model: bootstrapNodes

                        LogosFrame {
                            required property int index
                            Layout.fillWidth: true
                            backgroundColor: Theme.palette.background
                            borderColor: Theme.palette.borderSecondary
                            radius: Theme.spacing.radiusSmall
                            padding: Theme.spacing.medium

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    LogosText { text: "Bootstrap peer " + (index + 1); font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text }
                                    Item { Layout.fillWidth: true }
                                    LogosButton {
                                        text: "Remove"
                                        enabled: root.backend && root.backend.settingsEditable
                                        onClicked: {
                                            bootstrapNodes.remove(index)
                                            root.markDirty()
                                        }
                                    }
                                }

                                LogosTextField {
                                    Layout.fillWidth: true
                                    enabled: root.backend && root.backend.settingsEditable
                                    placeholderText: "Peer ID"
                                    text: model.peerId
                                    onTextChanged: {
                                        bootstrapNodes.setProperty(index, "peerId", text)
                                        root.markDirty()
                                    }
                                }

                                LogosTextArea {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    enabled: root.backend && root.backend.settingsEditable
                                    placeholderText: "Bootstrap multiaddress, one per line"
                                    text: model.addrsText
                                    onTextChanged: {
                                        bootstrapNodes.setProperty(index, "addrsText", text)
                                        root.markDirty()
                                    }
                                }
                            }
                        }
                    }

                    LogosButton {
                        text: "Add bootstrap peer"
                        enabled: root.backend && root.backend.settingsEditable
                        onClicked: {
                            bootstrapNodes.append({ "peerId": "", "addrsText": "" })
                            root.markDirty()
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

                GridLayout {
                    id: connectionGrid
                    anchors.fill: parent
                    columns: width > 700 ? 2 : 1
                    columnSpacing: Theme.spacing.large
                    rowSpacing: Theme.spacing.medium

                    LogosText {
                        Layout.columnSpan: connectionGrid.columns
                        text: "Connection limits"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { Layout.fillWidth: true; text: "Maximum total connections"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text }
                        LogosSpinBox { id: maxConnections; Layout.preferredWidth: 130; from: 1; to: 100000; value: 50; enabled: root.backend && root.backend.settingsEditable; onValueModified: root.markDirty() }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { Layout.fillWidth: true; text: "Maximum inbound connections"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text }
                        LogosSpinBox { id: maxInboundConnections; Layout.preferredWidth: 130; from: 1; to: 100000; value: 25; enabled: root.backend && root.backend.settingsEditable; onValueModified: root.markDirty() }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { Layout.fillWidth: true; text: "Maximum outbound connections"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text }
                        LogosSpinBox { id: maxOutboundConnections; Layout.preferredWidth: 130; from: 1; to: 100000; value: 25; enabled: root.backend && root.backend.settingsEditable; onValueModified: root.markDirty() }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { Layout.fillWidth: true; text: "Maximum connections per peer"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.text }
                        LogosSpinBox { id: maxConnectionsPerPeer; Layout.preferredWidth: 130; from: 1; to: 100000; value: 1; enabled: root.backend && root.backend.settingsEditable; onValueModified: root.markDirty() }
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

                    LogosText { text: "Protocols"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { Layout.fillWidth: true; text: "Disabling a protocol also disables actions on its operational screen."; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textSecondary; wrapMode: Text.Wrap }
                    LogosCheckbox { id: mountGossipsub; text: "Enable GossipSub"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: mountKad; text: "Enable Kademlia DHT"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: mountServiceDiscovery; text: "Enable Service Discovery"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: gossipsubTriggerSelf; text: "Trigger local GossipSub messages"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large

                GridLayout {
                    id: connectivityGrid
                    anchors.fill: parent
                    columns: width > 700 ? 2 : 1
                    columnSpacing: Theme.spacing.large
                    rowSpacing: Theme.spacing.small

                    LogosText {
                        Layout.columnSpan: connectivityGrid.columns
                        text: "Advanced connectivity"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }

                    LogosCheckbox { id: autonat; text: "Enable AutoNAT"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: autonatV2; text: "Enable AutoNAT v2"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: autonatV2Server; text: "Enable AutoNAT v2 server"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: circuitRelay; text: "Enable Circuit Relay"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
                    LogosCheckbox { id: circuitRelayClient; text: "Enable Circuit Relay client"; enabled: root.backend && root.backend.settingsEditable; onToggled: root.markDirty() }
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

                    LogosText { text: "UI behavior"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    LogosText { text: "Metrics refresh interval"; font.pixelSize: Theme.typography.secondaryText; color: Theme.palette.textTertiary }
                    LogosComboBox {
                        id: refreshInterval
                        Layout.fillWidth: true
                        model: ["Off", "5 seconds", "10 seconds", "30 seconds"]
                        onActivated: function(index) {
                            if (root.backend)
                                root.backend.setMetricsRefreshInterval(root.refreshIntervalValue(index))
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

                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { text: "Configuration JSON"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                        Item { Layout.fillWidth: true }
                        LogosButton { text: "Copy"; onClicked: root.copyJson() }
                    }

                    TextEdit {
                        id: jsonPreview
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        text: root.backend ? root.backend.nodeConfigJson : ""
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.NoWrap
                        font.family: "monospace"
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.textSecondary
                        selectionColor: Theme.palette.primary
                        clip: true
                    }
                }
            }

            LogosButton {
                text: "Restore defaults"
                enabled: root.backend && root.backend.settingsEditable
                onClicked: restoreDefaultsDialog.open()
            }
        }
    }

    LogosWarningDialog {
        id: restoreDefaultsDialog
        anchors.centerIn: parent
        title: "Restore default settings?"
        message: "This replaces the saved node configuration with the built-in defaults."
        leftActions: [
            LogosButton {
                text: "Cancel"
                onClicked: restoreDefaultsDialog.close()
            }
        ]
        rightActions: [
            LogosButton {
                text: "Restore defaults"
                variant: LogosButton.Variant.Primary
                onClicked: {
                    root.backend.restoreDefaultNodeConfig()
                    restoreDefaultsDialog.close()
                }
            }
        ]
    }

    Connections {
        target: root.backend
        ignoreUnknownSignals: true

        function onNodeConfigApplied() {
            root.successMessage = "Node configuration applied."
            root.loadConfig()
        }

        function onNodeConfigRestored() {
            root.successMessage = "Default node configuration restored."
            root.loadConfig()
        }

        function onMetricsRefreshIntervalChanged(intervalMs) {
            root.loading = true
            refreshInterval.currentIndex = root.refreshIntervalIndex(intervalMs)
            root.loading = false
            root.successMessage = intervalMs === 0 ? "Metrics polling disabled." : "Metrics refresh interval updated."
        }

        function onNodeConfigChanged() {
            if (!root.dirty)
                root.loadConfig()
        }
    }
}

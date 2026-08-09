import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: MockBackend
    readonly property bool running: backend && backend.status === 2
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var results: backend && backend.dhtLookupResults !== undefined ? backend.dhtLookupResults : []
    property string successMessage: ""

    function metric(name) {
        return metrics[name] === undefined ? 0 : metrics[name]
    }

    function refresh() {
        if (backend)
            backend.refreshMetrics()
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
                    text: "DHT"
                    font.pixelSize: Theme.typography.titleText
                    color: Theme.palette.text
                }

                Item {
                    Layout.fillWidth: true
                }

                LogosButton {
                    text: "Refresh"
                    enabled: root.running
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
                            enabled: root.running
                            placeholderText: "Peer ID"
                            onTextChanged: root.successMessage = ""
                        }

                        LogosButton {
                            text: "Find"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running && peerIdField.text.trim().length > 0
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
                        text: root.running ? "Enter a peer ID to find the closest DHT peers."
                                           : "No results are available while the node is stopped."
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

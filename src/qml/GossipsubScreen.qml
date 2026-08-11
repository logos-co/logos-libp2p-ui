import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Item {
    id: root

    property var backend: MockBackend
    property string successMessage: ""

    readonly property bool running: backend && backend.status === 2
    readonly property bool featureEnabled: !backend || !backend.nodeConfig || backend.nodeConfig.mountGossipsub !== false
    readonly property var topics: backend && backend.subscribedTopics !== undefined
                                  ? backend.subscribedTopics : []
    readonly property var metrics: backend && backend.metrics !== undefined ? backend.metrics : ({})
    readonly property var topicMetrics: metrics.gossipsubByTopic || []

    function metric(name) {
        return metrics[name] === undefined ? 0 : metrics[name]
    }

    function refresh() {
        if (backend)
            backend.refreshMetrics()
    }

    function subscribe() {
        if (backend)
            backend.gossipsubSubscribe(subscriptionTopicField.text)
    }

    function unsubscribe(topic) {
        if (backend)
            backend.gossipsubUnsubscribe(topic)
    }

    function publish() {
        if (backend)
            backend.gossipsubPublish(publishTopicField.text, messageField.text)
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.tiny

                LogosText {
                    text: "GossipSub"
                    font.pixelSize: Theme.typography.titleText
                    color: Theme.palette.text
                }

                LogosText {
                    Layout.fillWidth: true
                    text: "Subscribe to topics and publish text messages to the GossipSub network."
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                    wrapMode: Text.Wrap
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                LogosButton {
                    text: "Refresh"
                    enabled: root.running && root.featureEnabled
                    onClicked: root.refresh()
                }
            }

            LogosText {
                Layout.fillWidth: true
                visible: !root.running
                text: "Start the node from Overview to manage GossipSub topics and publish messages."
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.warning
                wrapMode: Text.Wrap
            }

            LogosText {
                Layout.fillWidth: true
                visible: root.running && !root.featureEnabled
                text: "GossipSub is disabled in Settings. Stop the node, enable it, then apply the configuration."
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.warning
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 3 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium

                StatCard {
                    Layout.fillWidth: true
                    title: "Subscribed topics"
                    value: root.topics.length
                    iconSource: "assets/gossipsub.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Messages published"
                    value: root.metric("gossipsubPublished")
                    iconSource: "assets/gossipsub.svg"
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "Messages received"
                    value: root.metric("gossipsubReceived")
                    iconSource: "assets/gossipsub.svg"
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 4 : width > 500 ? 2 : 1
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.medium
                StatCard { Layout.fillWidth: true; title: "Healthy topics"; value: root.metric("gossipsubHealthyTopics"); iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Low/no-peer topics"; value: Number(root.metric("gossipsubLowPeerTopics")) + Number(root.metric("gossipsubNoPeerTopics")); iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Duplicate ratio"; value: Number(root.metric("gossipsubDuplicateRatio")).toFixed(1) + "%"; iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Validation failures"; value: root.metric("gossipsubValidationFailures"); iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Failed publishes"; value: root.metric("gossipsubFailedPublishes"); iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Signature failures"; value: root.metric("gossipsubSignatureFailures"); iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Rate-limit hits"; value: root.metric("gossipsubRateLimitHits"); iconSource: "assets/gossipsub.svg" }
                StatCard { Layout.fillWidth: true; title: "Queue drops"; value: root.metric("gossipsubQueueDrops"); iconSource: "assets/gossipsub.svg" }
            }

            LogosFrame {
                Layout.fillWidth: true
                visible: root.topicMetrics.length > 0
                backgroundColor: Theme.palette.backgroundSecondary
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.spacing.small
                    LogosText { text: "Topic health and traffic"; font.pixelSize: Theme.typography.primaryText; font.weight: Theme.typography.weightMedium; color: Theme.palette.text }
                    Repeater {
                        model: root.topicMetrics
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 48; radius: Theme.spacing.radiusSmall; color: Theme.palette.background
                            RowLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacing.small
                                LogosText { Layout.fillWidth: true; text: modelData.topic; color: Theme.palette.text; elide: Text.ElideMiddle }
                                LogosText { text: "Mesh " + (modelData.meshPeers || 0); color: (modelData.meshPeers || 0) > 0 ? Theme.palette.success : Theme.palette.warning }
                                LogosText { text: "Published " + (modelData.published || 0); color: Theme.palette.textSecondary }
                                LogosText { text: "Received " + (modelData.received || 0); color: Theme.palette.textSecondary }
                                LogosText { text: "Rebroadcast " + (modelData.rebroadcasted || 0); color: Theme.palette.textSecondary }
                            }
                        }
                    }
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

                        LogosText {
                            text: "Subscribed topics"
                            font.pixelSize: Theme.typography.primaryText
                            font.weight: Theme.typography.weightMedium
                            color: Theme.palette.text
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        LogosText {
                            text: root.topics.length + (root.topics.length === 1 ? " topic" : " topics")
                            font.pixelSize: Theme.typography.secondaryText
                            color: Theme.palette.textTertiary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        LogosTextField {
                            id: subscriptionTopicField

                            Layout.fillWidth: true
                            placeholderText: "Topic name"
                            enabled: root.running && root.featureEnabled
                            onTextChanged: root.successMessage = ""
                            Keys.onReturnPressed: root.subscribe()
                        }

                        LogosButton {
                            text: "Subscribe"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running && root.featureEnabled && subscriptionTopicField.text.trim().length > 0
                            onClicked: root.subscribe()
                        }
                    }

                    LogosText {
                        Layout.fillWidth: true
                        visible: root.topics.length === 0
                        text: !root.running ? "No topics are available while the node is stopped."
                                           : !root.featureEnabled ? "GossipSub is disabled in Settings."
                                                                  : "No topics subscribed yet. Enter a topic name to subscribe."
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.textTertiary
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: root.topics

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: topicRow.implicitHeight + 2 * Theme.spacing.small
                            radius: Theme.spacing.radiusSmall
                            color: Theme.palette.background
                            border.width: 1
                            border.color: Theme.palette.borderSecondary

                            RowLayout {
                                id: topicRow

                                anchors.fill: parent
                                anchors.margins: Theme.spacing.small
                                spacing: Theme.spacing.medium

                                LogosText {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.pixelSize: Theme.typography.secondaryText
                                    color: Theme.palette.text
                                    elide: Text.ElideRight
                                }

                                LogosButton {
                                    text: "Unsubscribe"
                                    enabled: root.running && root.featureEnabled
                                    onClicked: root.unsubscribe(modelData)
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
                    spacing: Theme.spacing.medium

                    LogosText {
                        text: "Publish message"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }

                    LogosTextField {
                        id: publishTopicField

                        Layout.fillWidth: true
                        placeholderText: "Topic name"
                        enabled: root.running && root.featureEnabled
                        onTextChanged: root.successMessage = ""
                    }

                    LogosTextArea {
                        id: messageField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 144
                        placeholderText: "Write a message to publish"
                        enabled: root.running && root.featureEnabled
                        onTextChanged: root.successMessage = ""
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        LogosButton {
                            text: "Publish"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running && root.featureEnabled
                                     && publishTopicField.text.trim().length > 0
                                     && messageField.text.trim().length > 0
                            onClicked: root.publish()
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root.backend
        ignoreUnknownSignals: true

        function onGossipsubTopicSubscribed(topic) {
            subscriptionTopicField.text = ""
            root.successMessage = "Subscribed to " + topic + "."
        }

        function onGossipsubTopicUnsubscribed(topic) {
            root.successMessage = "Unsubscribed from " + topic + "."
        }

        function onGossipsubMessagePublished(topic) {
            messageField.text = ""
            root.successMessage = "Message published to " + topic + "."
        }
    }
}

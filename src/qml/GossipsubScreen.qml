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
    readonly property var topics: backend && backend.subscribedTopics !== undefined
                                  ? backend.subscribedTopics : []

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
                            enabled: root.running
                            onTextChanged: root.successMessage = ""
                            Keys.onReturnPressed: root.subscribe()
                        }

                        LogosButton {
                            text: "Subscribe"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running && subscriptionTopicField.text.trim().length > 0
                            onClicked: root.subscribe()
                        }
                    }

                    LogosText {
                        Layout.fillWidth: true
                        visible: root.topics.length === 0
                        text: root.running
                              ? "No topics subscribed yet. Enter a topic name to subscribe."
                              : "No topics are available while the node is stopped."
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
                                    enabled: root.running
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
                        enabled: root.running
                        onTextChanged: root.successMessage = ""
                    }

                    LogosTextArea {
                        id: messageField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 144
                        placeholderText: "Write a message to publish"
                        enabled: root.running
                        onTextChanged: root.successMessage = ""
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        LogosButton {
                            text: "Publish"
                            variant: LogosButton.Variant.Primary
                            enabled: root.running
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

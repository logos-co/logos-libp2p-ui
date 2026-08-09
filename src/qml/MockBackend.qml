pragma Singleton

import QtQuick

QtObject {
    readonly property bool isMock: true

    property int status: 0
    property string peerId: ""
    property string listenAddress: ""
    property string uiVersion: "0.1.0"
    property int connectedPeers: 0
    property int activeStreams: 0
    property int gossipsubTopics: 0
    property var subscribedTopics: []
    property int dhtRecords: 0
    property int relayReservations: 0

    signal initCompleted(bool success, string error)
    signal startCompleted
    signal startFailed(string error)
    signal stopCompleted
    signal overviewUpdated(var overview)
    signal gossipsubTopicSubscribed(string topic)
    signal gossipsubTopicUnsubscribed(string topic)
    signal gossipsubMessagePublished(string topic)
    signal error(string message)

    function init(configJson) {
        initCompleted(true, "")
    }

    function start() {
        status = 2
        peerId = "16Uiu2HAmMockPeerIdForLogosNetworkConsole"
        listenAddress = "/ip4/127.0.0.1/tcp/39421"
        connectedPeers = 0
        startCompleted()
        refreshOverview()
    }

    function stop() {
        status = 0
        connectedPeers = 0
        gossipsubTopics = 0
        subscribedTopics = []
        stopCompleted()
    }

    function gossipsubSubscribe(topic) {
        topic = topic.trim()
        if (status !== 2) {
            error("Cannot subscribe to a GossipSub topic while the libp2p node is not running.")
            return
        }
        if (!topic.length) {
            error("A GossipSub topic is required.")
            return
        }
        if (subscribedTopics.indexOf(topic) !== -1) {
            error("Already subscribed to GossipSub topic '" + topic + "'.")
            return
        }

        subscribedTopics = subscribedTopics.concat([topic])
        gossipsubTopics = subscribedTopics.length
        gossipsubTopicSubscribed(topic)
    }

    function gossipsubUnsubscribe(topic) {
        topic = topic.trim()
        if (status !== 2) {
            error("Cannot unsubscribe from a GossipSub topic while the libp2p node is not running.")
            return
        }

        var index = subscribedTopics.indexOf(topic)
        if (index === -1) {
            error("Not subscribed to GossipSub topic '" + topic + "'.")
            return
        }

        var topics = subscribedTopics.slice()
        topics.splice(index, 1)
        subscribedTopics = topics
        gossipsubTopics = topics.length
        gossipsubTopicUnsubscribed(topic)
    }

    function gossipsubPublish(topic, message) {
        topic = topic.trim()
        if (status !== 2) {
            error("Cannot publish a GossipSub message while the libp2p node is not running.")
            return
        }
        if (!topic.length) {
            error("A GossipSub topic is required.")
            return
        }
        if (!message.trim().length) {
            error("A GossipSub message is required.")
            return
        }

        gossipsubMessagePublished(topic)
    }

    function refreshOverview() {
        overviewUpdated({
                            "peerId": peerId,
                            "listenAddress": listenAddress,
                            "connectedPeers": connectedPeers,
                            "activeStreams": activeStreams,
                            "gossipsubTopics": gossipsubTopics,
                            "dhtRecords": dhtRecords,
                            "relayReservations": relayReservations
                        })
    }

    function defaultConfigJson() {
        return JSON.stringify({
                                  "addrs": ["/ip4/127.0.0.1/tcp/0"],
                                  "transport": "tcp",
                                  "maxConnections": 50,
                                  "maxInConnections": 25,
                                  "maxOutConnections": 25,
                                  "maxConnsPerPeer": 1,
                                  "mountGossipsub": true,
                                  "mountKad": true,
                                  "mountServiceDiscovery": true
                              })
    }

    function logDebugInfo() {}
}

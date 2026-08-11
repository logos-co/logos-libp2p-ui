pragma Singleton

import QtQuick

QtObject {
    id: root

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
    property var inboundPeers: []
    property var outboundPeers: []
    property int knownPeers: 0
    property var metrics: ({})
    property var lastPingResult: ({})
    property var dhtLookupResults: []
    property var advertisedServices: []
    property var discoveryResults: []
    property var nodeConfig: defaultNodeConfig()
    readonly property string nodeConfigJson: JSON.stringify(nodeConfig, null, 2)
    readonly property bool settingsEditable: status === 0
    property int metricsRefreshIntervalMs: 5000
    property int metricsTick: 0
    property double mockBytesReceived: 1048576
    property double mockBytesSent: 524288
    property var metricHistory: []
    property double startedAtMs: 0
    property Timer metricsTimer: Timer {
        interval: root.metricsRefreshIntervalMs > 0 ? root.metricsRefreshIntervalMs : 5000
        repeat: true
        running: root.status === 2 && root.metricsRefreshIntervalMs > 0
        onTriggered: root.refreshMetrics()
    }

    signal initCompleted(bool success, string error)
    signal startCompleted
    signal startFailed(string error)
    signal stopCompleted
    signal overviewUpdated(var overview)
    signal gossipsubTopicSubscribed(string topic)
    signal gossipsubTopicUnsubscribed(string topic)
    signal gossipsubMessagePublished(string topic)
    signal peersUpdated
    signal peerConnected(string peerId)
    signal peerDisconnected(string peerId)
    signal pingCompleted(var result)
    signal dhtLookupCompleted(string peerId)
    signal serviceAdvertised(string serviceId)
    signal serviceStoppedAdvertising(string serviceId)
    signal serviceLookupCompleted(string serviceId)
    signal metricsUpdated(var metrics)
    signal nodeConfigApplied
    signal nodeConfigRestored
    signal metricsRefreshIntervalChanged(int intervalMs)
    signal error(string message)

    function init(configJson) {
        try {
            var config = JSON.parse(configJson)
            nodeConfig = canonicalNodeConfig(config)
            initCompleted(true, "")
        } catch (exception) {
            error("Invalid libp2p configuration: " + exception)
            initCompleted(false, "Invalid libp2p configuration")
        }
    }

    function start() {
        status = 2
        peerId = "16Uiu2HAmMockPeerIdForLogosNetworkConsole"
        listenAddress = "/ip4/127.0.0.1/tcp/39421"
        connectedPeers = 0
        inboundPeers = []
        outboundPeers = []
        knownPeers = 0
        metricsTick = 0
        metricHistory = []
        startedAtMs = Date.now()
        mockBytesReceived = 1048576
        mockBytesSent = 524288
        metrics = defaultMetrics()
        startCompleted()
        refreshPeers()
        refreshMetrics()
        refreshOverview()
    }

    function stop() {
        status = 0
        connectedPeers = 0
        gossipsubTopics = 0
        subscribedTopics = []
        inboundPeers = []
        outboundPeers = []
        knownPeers = 0
        metrics = ({})
        lastPingResult = ({})
        dhtLookupResults = []
        advertisedServices = []
        discoveryResults = []
        metricHistory = []
        startedAtMs = 0
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
        refreshMetrics()
    }

    function defaultMetrics() {
        var topics = []
        for (var topicIndex = 0; topicIndex < subscribedTopics.length; ++topicIndex) {
            topics.push({
                            "topic": subscribedTopics[topicIndex],
                            "published": metricsTick,
                            "received": metricsTick * 2,
                            "rebroadcasted": metricsTick,
                            "meshPeers": Math.min(6, connectedPeers),
                            "fanoutPeers": 0,
                            "gossipsubPeers": connectedPeers,
                            "queueDepth": 0,
                            "queueDrops": 0
                        })
        }
        return {
            "connectedPeersMetric": connectedPeers,
            "openStreams": activeStreams,
            "openInboundStreams": 0,
            "openOutboundStreams": activeStreams,
            "streamCapRejections": 0,
            "gossipsubPublished": 0,
            "gossipsubReceived": 0,
            "dhtRoutingPeers": 0,
            "dhtRoutingBuckets": 0,
            "dhtNetworkSizeEstimate": 0,
            "discoveryAdvertisements": advertisedServices.length,
            "discoveryServices": advertisedServices.length,
            "discoveryServicePeers": 0,
            "discoveryLookupRequests": 0,
            "discoveryPeersFound": 0,
            "trafficBytesReceived": mockBytesReceived,
            "trafficBytesSent": mockBytesSent,
            "trafficSessionBytesReceived": Math.max(0, mockBytesReceived - 1048576),
            "trafficSessionBytesSent": Math.max(0, mockBytesSent - 524288),
            "trafficReceiveRate": status === 2 && metricsTick > 0 ? 24576 : 0,
            "trafficSendRate": status === 2 && metricsTick > 0 ? 12288 : 0,
            "trafficPeakReceiveRate": metricsTick > 0 ? 24576 : 0,
            "trafficPeakSendRate": metricsTick > 0 ? 12288 : 0,
            "dialAttempts": Math.max(connectedPeers, 1),
            "dialSuccesses": connectedPeers,
            "dialFailures": connectedPeers > 0 ? 0 : 1,
            "dialSuccessRate": connectedPeers > 0 ? 100 : 0,
            "dialLatencyP50Ms": 100,
            "dialLatencyP95Ms": 500,
            "dialLatencyP99Ms": 1000,
            "dialLatencyAvailable": connectedPeers > 0,
            "failedUpgradesInbound": 0,
            "failedUpgradesOutbound": 0,
            "connectionManagerTrims": 0,
            "connectionManagerPrunedPeers": 0,
            "autonatReachability": nodeConfig.autonat ? "Reachable" : "Unknown",
            "autonatConfidence": nodeConfig.autonat ? 0.8 : 0,
            "autonatV2Reachability": nodeConfig.autonatV2 ? "Reachable" : "Unknown",
            "autonatV2Confidence": nodeConfig.autonatV2 ? 0.8 : 0,
            "relayReservationsActive": relayReservations,
            "relayCircuitsActive": 0,
            "relayBytesReceived": 0,
            "relayBytesSent": 0,
            "nodeUptimeSeconds": startedAtMs > 0 ? Math.floor((Date.now() - startedAtMs) / 1000) : 0,
            "lastMetricsUpdateMs": Date.now(),
            "availableMetrics": ["libp2p_network_bytes", "libp2p_module_gossipsub_queue_depth", "libp2p_module_gossipsub_queue_dropped_total"],
            "metricSeries": [],
            "trafficHistory": metricHistory,
            "trafficByProtocol": [],
            "trafficByAgent": [],
            "streamsByProtocol": activeStreams > 0 ? [{ "protocol": "/ipfs/ping/1.0.0", "inbound": 0, "outbound": activeStreams, "total": activeStreams, "rejections": 0 }] : [],
            "gossipsubByTopic": topics,
            "gossipsubDuplicates": 0,
            "gossipsubValidationFailures": 0,
            "gossipsubNoPeerTopics": topics.length > 0 && connectedPeers === 0 ? topics.length : 0,
            "gossipsubLowPeerTopics": 0,
            "gossipsubHealthyTopics": connectedPeers > 0 ? topics.length : 0,
            "gossipsubRateLimitHits": 0,
            "gossipsubQueueDepth": 0,
            "gossipsubQueueDrops": 0,
            "dhtMessagesByType": [],
            "dhtBucketSizes": [],
            "dhtRoutingInsertions": 0,
            "dhtRoutingReplacements": 0,
            "dhtRoutingEvictions": 0,
            "dhtLivenessSuccesses": 0,
            "dhtLivenessFailures": 0,
            "discoveryMessagesByType": [],
            "discoveryExpiredAdvertisements": 0,
            "discoveryServiceTables": 0,
            "discoveryPendingActions": 0,
            "discoveryActionsExecuted": 0
        }
    }

    function refreshPeers() {
        if (status !== 2) {
            inboundPeers = []
            outboundPeers = []
            knownPeers = 0
            connectedPeers = 0
        }
        peersUpdated()
    }

    function connectPeer(peerId, multiaddr) {
        peerId = peerId.trim()
        multiaddr = multiaddr.trim()
        if (status !== 2) {
            error("Cannot connect to a peer while the libp2p node is not running.")
            return
        }
        if (!peerId.length || !multiaddr.length) {
            error("A peer ID and multiaddress are required to connect.")
            return
        }
        if (outboundPeers.indexOf(peerId) !== -1) {
            error("Already connected to peer '" + peerId + "'.")
            return
        }
        outboundPeers = outboundPeers.concat([peerId])
        knownPeers = Math.max(knownPeers, outboundPeers.length + inboundPeers.length)
        connectedPeers = inboundPeers.length + outboundPeers.length
        refreshMetrics()
        peerConnected(peerId)
    }

    function disconnectPeer(peerId) {
        peerId = peerId.trim()
        if (status !== 2) {
            error("Cannot disconnect a peer while the libp2p node is not running.")
            return
        }
        var inboundIndex = inboundPeers.indexOf(peerId)
        var outboundIndex = outboundPeers.indexOf(peerId)
        if (inboundIndex === -1 && outboundIndex === -1) {
            error("Not connected to peer '" + peerId + "'.")
            return
        }
        if (inboundIndex !== -1) {
            var inbound = inboundPeers.slice()
            inbound.splice(inboundIndex, 1)
            inboundPeers = inbound
        }
        if (outboundIndex !== -1) {
            var outbound = outboundPeers.slice()
            outbound.splice(outboundIndex, 1)
            outboundPeers = outbound
        }
        connectedPeers = inboundPeers.length + outboundPeers.length
        refreshMetrics()
        peerDisconnected(peerId)
    }

    function refreshMetrics() {
        if (status === 2) {
            ++metricsTick
            mockBytesReceived += 24576 * Math.max(1, metricsRefreshIntervalMs / 1000)
            mockBytesSent += 12288 * Math.max(1, metricsRefreshIntervalMs / 1000)
            var history = metricHistory.slice()
            history.push({
                             "timestampMs": Date.now(),
                             "bytesReceived": mockBytesReceived,
                             "bytesSent": mockBytesSent,
                             "receiveRate": 24576,
                             "sendRate": 12288,
                             "peers": connectedPeers,
                             "streams": activeStreams
                         })
            while (history.length > 360)
                history.shift()
            metricHistory = history
        }
        var values = defaultMetrics()
        values.connectedPeersMetric = connectedPeers
        values.trafficHistory = metricHistory
        metrics = values
        metricsUpdated(values)
    }

    function pingPeer(peerId) {
        peerId = peerId.trim()
        if (status !== 2) {
            error("Cannot ping a peer while the libp2p node is not running.")
            return
        }
        if (inboundPeers.indexOf(peerId) === -1 && outboundPeers.indexOf(peerId) === -1) {
            error("Connect to peer '" + peerId + "' before pinging it.")
            return
        }
        lastPingResult = { "peerId": peerId, "latencyMs": 12, "success": true }
        pingCompleted(lastPingResult)
    }

    function dhtFindPeer(peerId) {
        peerId = peerId.trim()
        if (status !== 2) {
            error("Cannot look up a DHT peer while the libp2p node is not running.")
            return
        }
        if (!peerId.length) {
            error("A peer ID is required for DHT lookup.")
            return
        }
        dhtLookupResults = inboundPeers.concat(outboundPeers)
        dhtLookupCompleted(peerId)
    }

    function serviceDiscoveryAdvertise(serviceId, serviceData) {
        serviceId = serviceId.trim()
        if (status !== 2) {
            error("Cannot advertise a service while the libp2p node is not running.")
            return
        }
        if (!serviceId.length) {
            error("A service ID is required to advertise.")
            return
        }
        for (var i = 0; i < advertisedServices.length; ++i) {
            if (advertisedServices[i].serviceId === serviceId) {
                error("Already advertising service '" + serviceId + "'. Stop it before advertising it again.")
                return
            }
        }
        advertisedServices = advertisedServices.concat([{ "serviceId": serviceId, "serviceData": serviceData }])
        refreshMetrics()
        serviceAdvertised(serviceId)
    }

    function serviceDiscoveryStopAdvertising(serviceId) {
        serviceId = serviceId.trim()
        if (status !== 2) {
            error("Cannot stop advertising a service while the libp2p node is not running.")
            return
        }
        var services = advertisedServices.slice()
        for (var i = services.length - 1; i >= 0; --i) {
            if (services[i].serviceId === serviceId)
                services.splice(i, 1)
        }
        advertisedServices = services
        refreshMetrics()
        serviceStoppedAdvertising(serviceId)
    }

    function serviceDiscoveryLookup(serviceId, serviceData) {
        serviceId = serviceId.trim()
        if (status !== 2) {
            error("Cannot look up a service while the libp2p node is not running.")
            return
        }
        if (!serviceId.length) {
            error("A service ID is required for service discovery lookup.")
            return
        }
        var matches = []
        for (var i = 0; i < advertisedServices.length; ++i) {
            var service = advertisedServices[i]
            if (service.serviceId === serviceId && service.serviceData === serviceData) {
                matches.push({
                                 "peerId": peerId,
                                 "addrs": [listenAddress],
                                 "services": [{ "id": service.serviceId, "data": service.serviceData }]
                             })
            }
        }
        discoveryResults = matches
        var values = defaultMetrics()
        values.discoveryLookupRequests = metrics.discoveryLookupRequests + 1
        values.discoveryPeersFound = metrics.discoveryPeersFound + matches.length
        metrics = values
        metricsUpdated(values)
        serviceLookupCompleted(serviceId)
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
        return JSON.stringify(defaultNodeConfig(), null, 2)
    }

    function defaultNodeConfig() {
        return {
            "addrs": ["/ip4/127.0.0.1/tcp/0"],
            "transport": "tcp",
            "maxConnections": 50,
            "maxInConnections": 25,
            "maxOutConnections": 25,
            "maxConnsPerPeer": 1,
            "mountGossipsub": true,
            "mountKad": true,
            "mountServiceDiscovery": true,
            "bootstrapNodes": [],
            "autonat": false,
            "autonatV2": false,
            "autonatV2Server": false,
            "circuitRelay": false,
            "circuitRelayClient": false,
            "gossipsubTriggerSelf": true
        }
    }

    function canonicalNodeConfig(config) {
        var defaults = defaultNodeConfig()
        for (var key in config)
            defaults[key] = config[key]
        return defaults
    }

    function applyNodeConfig(config) {
        if (!settingsEditable) {
            error("Stop the libp2p node before changing its configuration.")
            return
        }
        if (!config.addrs || config.addrs.length === 0 || config.transport !== "tcp" && config.transport !== "quic") {
            error("Enter at least one listen address and select TCP or QUIC.")
            return
        }
        nodeConfig = canonicalNodeConfig(config)
        nodeConfigApplied()
    }

    function restoreDefaultNodeConfig() {
        if (!settingsEditable) {
            error("Stop the libp2p node before changing its configuration.")
            return
        }
        nodeConfig = defaultNodeConfig()
        nodeConfigRestored()
    }

    function setMetricsRefreshInterval(intervalMs) {
        if ([0, 5000, 10000, 30000].indexOf(intervalMs) === -1) {
            error("Metrics refresh interval must be Off, 5, 10, or 30 seconds.")
            return
        }
        metricsRefreshIntervalMs = intervalMs
        metricsRefreshIntervalChanged(intervalMs)
    }

    function logDebugInfo() {}
}

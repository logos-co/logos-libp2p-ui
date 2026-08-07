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
    property int dhtRecords: 0
    property int relayReservations: 0

    signal initCompleted(bool success, string error)
    signal startCompleted
    signal startFailed(string error)
    signal stopCompleted
    signal overviewUpdated(var overview)
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
        stopCompleted()
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

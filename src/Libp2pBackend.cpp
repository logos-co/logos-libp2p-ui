#include "Libp2pBackend.h"

#include <QByteArray>
#include <QDebug>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QMap>
#include <QSet>
#include <QStringList>
#include <QDateTime>
#include <QVariantMap>

#include <cmath>

#ifndef LIBP2P_UI_VERSION
#define LIBP2P_UI_VERSION "unknown"
#endif

namespace {
constexpr int kInboundDirection = 0;
constexpr int kOutboundDirection = 1;
constexpr int kDefaultMetricsRefreshIntervalMs = 5000;
constexpr qint64 kMetricHistoryRetentionMs = 30 * 60 * 1000;

const QString kConfigSettingsKey = QStringLiteral("libp2p-ui/nodeConfig");
const QString kMetricsIntervalSettingsKey = QStringLiteral("libp2p-ui/metricsRefreshIntervalMs");

bool normalizeStringArray(const QJsonValue& value, QJsonArray* output, const QString& field, QString* error) {
    if (!value.isArray()) {
        *error = QStringLiteral("%1 must be an array of strings.").arg(field);
        return false;
    }

    QJsonArray normalized;
    for (const QJsonValue& item : value.toArray()) {
        const QString text = item.toString().trimmed();
        if (!item.isString() || text.isEmpty()) {
            *error = QStringLiteral("%1 must contain only non-empty strings.").arg(field);
            return false;
        }
        normalized.append(text);
    }
    *output = normalized;
    return true;
}

bool isAllowedMetricsRefreshInterval(int intervalMs) {
    return intervalMs == 0 || intervalMs == 5000 || intervalMs == 10000 || intervalMs == 30000;
}

QJsonValue valueOrDefault(const QJsonObject& object, const QString& key, const QJsonObject& defaults) {
    return object.contains(key) ? object.value(key) : defaults.value(key);
}
} // namespace

Libp2pBackend::Libp2pBackend(LogosAPI* logosAPI, QObject* parent) : Libp2pBackendSimpleSource(parent) {
    setStatus(Stopped);
    setPeerId(QString());
    setListenAddress(QString());
    setUiVersion(LIBP2P_UI_VERSION);
    setConnectedPeers(0);
    setActiveStreams(0);
    setGossipsubTopics(0);
    setSubscribedTopics(QVariantList{});
    setDhtRecords(0);
    setRelayReservations(0);
    setInboundPeers(QVariantList{});
    setOutboundPeers(QVariantList{});
    setKnownPeers(0);
    setMetrics(QVariantMap{});
    setLastPingResult(QVariantMap{});
    setDhtLookupResults(QVariantList{});
    setAdvertisedServices(QVariantList{});
    setDiscoveryResults(QVariantList{});
    setNodeConfig(QVariantMap{});
    setNodeConfigJson(QString());
    setSettingsEditable(true);
    setMetricsRefreshIntervalMs(kDefaultMetricsRefreshIntervalMs);

    m_metricsTimer = new QTimer(this);
    m_metricsTimer->setTimerType(Qt::CoarseTimer);
    connect(m_metricsTimer, &QTimer::timeout, this, [this]() {
        refreshPeers();
        refreshMetrics();
    });

    m_config = defaultConfig();
    loadSettings();

    if (logosAPI) {
        m_logosAPI = logosAPI;
    } else {
        m_logosAPI = new LogosAPI("core", this);
    }

    m_logos = new LogosModules(m_logosAPI);
}

Libp2pBackend::~Libp2pBackend() {
    m_logosAPI = nullptr;
    m_logos = nullptr;
}

void Libp2pBackend::reportError(const QString& message) {
    qWarning() << "Libp2pBackend:" << message;
    emit error(message);
}

QJsonDocument Libp2pBackend::defaultConfig() {
    QJsonObject obj;
    obj["addrs"] = QJsonArray{QStringLiteral("/ip4/127.0.0.1/tcp/0")};
    obj["transport"] = QStringLiteral("tcp");
    obj["maxConnections"] = 50;
    obj["maxInConnections"] = 25;
    obj["maxOutConnections"] = 25;
    obj["maxConnsPerPeer"] = 1;
    obj["mountGossipsub"] = true;
    obj["mountKad"] = true;
    obj["mountServiceDiscovery"] = true;
    obj["bootstrapNodes"] = QJsonArray{};
    obj["autonat"] = false;
    obj["autonatV2"] = false;
    obj["autonatV2Server"] = false;
    obj["circuitRelay"] = false;
    obj["circuitRelayClient"] = false;
    obj["gossipsubTriggerSelf"] = true;
    return QJsonDocument(obj);
}

QString Libp2pBackend::defaultConfigJson() {
    return QString::fromUtf8(defaultConfig().toJson(QJsonDocument::Indented));
}

bool Libp2pBackend::canonicalizeConfig(const QVariantMap& input, QJsonDocument* config, QString* error) {
    return canonicalizeConfig(QJsonDocument(QJsonObject::fromVariantMap(input)), config, error);
}

bool Libp2pBackend::canonicalizeConfig(const QJsonDocument& input, QJsonDocument* config, QString* error) {
    if (!input.isObject()) {
        *error = QStringLiteral("Configuration must be a JSON object.");
        return false;
    }

    const QJsonObject source = input.object();
    QJsonObject normalized = defaultConfig().object();

    QJsonArray addrs = normalized.value(QStringLiteral("addrs")).toArray();
    if (source.contains(QStringLiteral("addrs"))
        && !normalizeStringArray(source.value(QStringLiteral("addrs")), &addrs, QStringLiteral("addrs"), error)) {
            return false;
    }
    if (addrs.isEmpty()) {
        *error = QStringLiteral("At least one listen multiaddress is required.");
        return false;
    }
    normalized["addrs"] = addrs;

    const QString transport = valueOrDefault(source, QStringLiteral("transport"), normalized).toString().trimmed();
    if (transport != QStringLiteral("tcp") && transport != QStringLiteral("quic")) {
        *error = QStringLiteral("transport must be either 'tcp' or 'quic'.");
        return false;
    }
    normalized["transport"] = transport;

    const QStringList limitKeys{
        QStringLiteral("maxConnections"),
        QStringLiteral("maxInConnections"),
        QStringLiteral("maxOutConnections"),
        QStringLiteral("maxConnsPerPeer")};
    for (const QString& key : limitKeys) {
        const QJsonValue value = valueOrDefault(source, key, normalized);
        if (!value.isDouble() || std::floor(value.toDouble()) != value.toDouble() || value.toInt() < 1) {
            *error = QStringLiteral("%1 must be an integer of at least one.").arg(key);
            return false;
        }
        normalized[key] = value.toInt();
    }

    const QStringList boolKeys{
        QStringLiteral("mountGossipsub"),
        QStringLiteral("mountKad"),
        QStringLiteral("mountServiceDiscovery"),
        QStringLiteral("gossipsubTriggerSelf"),
        QStringLiteral("autonat"),
        QStringLiteral("autonatV2"),
        QStringLiteral("autonatV2Server"),
        QStringLiteral("circuitRelay"),
        QStringLiteral("circuitRelayClient")};
    for (const QString& key : boolKeys) {
        const QJsonValue value = valueOrDefault(source, key, normalized);
        if (!value.isBool()) {
            *error = QStringLiteral("%1 must be true or false.").arg(key);
            return false;
        }
        normalized[key] = value.toBool();
    }

    const QJsonValue bootstrapValue = valueOrDefault(source, QStringLiteral("bootstrapNodes"), normalized);
    if (!bootstrapValue.isArray()) {
        *error = QStringLiteral("bootstrapNodes must be an array.");
        return false;
    }
    QJsonArray bootstrapNodes;
    QSet<QString> peerIds;
    for (const QJsonValue& entry : bootstrapValue.toArray()) {
        if (!entry.isObject()) {
            *error = QStringLiteral("Each bootstrap node must be an object.");
            return false;
        }
        const QJsonObject node = entry.toObject();
        const QString peerId = node.value(QStringLiteral("peerId")).toString().trimmed();
        if (peerId.isEmpty()) {
            *error = QStringLiteral("Each bootstrap node needs a peer ID.");
            return false;
        }
        if (peerIds.contains(peerId)) {
            *error = QStringLiteral("Bootstrap peer IDs must be unique.");
            return false;
        }
        QJsonArray nodeAddrs;
        if (!normalizeStringArray(node.value(QStringLiteral("addrs")), &nodeAddrs,
                                  QStringLiteral("Bootstrap node addresses"), error)
            || nodeAddrs.isEmpty()) {
            if (nodeAddrs.isEmpty() && error->isEmpty()) {
                *error = QStringLiteral("Each bootstrap node needs an address.");
            }
            return false;
        }
        peerIds.insert(peerId);
        bootstrapNodes.append(QJsonObject{{"peerId", peerId}, {"addrs", nodeAddrs}});
    }
    normalized["bootstrapNodes"] = bootstrapNodes;

    *config = QJsonDocument(normalized);
    return true;
}

void Libp2pBackend::setCurrentConfig(const QJsonDocument& config) {
    m_config = config;
    setNodeConfig(m_config.object().toVariantMap());
    setNodeConfigJson(QString::fromUtf8(m_config.toJson(QJsonDocument::Indented)));
}

void Libp2pBackend::persistConfig() {
    m_settings.setValue(kConfigSettingsKey, QString::fromUtf8(m_config.toJson(QJsonDocument::Compact)));
    m_settings.sync();
}

void Libp2pBackend::loadSettings() {
    QJsonDocument config = defaultConfig();
    const QString storedConfig = m_settings.value(kConfigSettingsKey).toString();
    if (!storedConfig.isEmpty()) {
        QJsonParseError parseError;
        const QJsonDocument parsed = QJsonDocument::fromJson(storedConfig.toUtf8(), &parseError);
        QJsonDocument normalized;
        QString error;
        if (parseError.error == QJsonParseError::NoError && canonicalizeConfig(parsed, &normalized, &error)) {
            config = normalized;
        } else {
            qWarning() << "Libp2pBackend: ignoring invalid persisted configuration:" << error;
        }
    }
    setCurrentConfig(config);

    const int intervalMs = m_settings.value(kMetricsIntervalSettingsKey, kDefaultMetricsRefreshIntervalMs).toInt();
    setMetricsRefreshIntervalMs(isAllowedMetricsRefreshInterval(intervalMs) ? intervalMs : kDefaultMetricsRefreshIntervalMs);
}

void Libp2pBackend::init(QString configJson) {
    if (status() == Running || status() == Starting || status() == Stopping) {
        const QString message = QStringLiteral("Cannot initialize libp2p while the node is active.");
        reportError(message);
        emit initCompleted(false, message);
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument parsed = QJsonDocument::fromJson(configJson.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !parsed.isObject()) {
        const QString message = QStringLiteral("Invalid libp2p configuration: %1").arg(parseError.errorString());
        reportError(message);
        emit initCompleted(false, message);
        return;
    }

    QJsonDocument config;
    QString error;
    if (!canonicalizeConfig(parsed, &config, &error) || !initializeConfig(config, false, &error)) {
        reportError(error);
        emit initCompleted(false, error);
        return;
    }
    emit initCompleted(true, QString());
}

bool Libp2pBackend::initializeConfig(const QJsonDocument& config, bool persist, QString* error) {
    if (status() != Stopped) {
        *error = QStringLiteral("Stop the libp2p node before changing its configuration.");
        return false;
    }
    if (m_initialized && config == m_config) {
        setCurrentConfig(config);
        if (persist) {
            persistConfig();
        }
        return true;
    }

    LogosResult result = m_logos->libp2p_module.createNode(QString::fromUtf8(config.toJson(QJsonDocument::Compact)));
    if (!result.success) {
        *error = QStringLiteral("Failed to initialize libp2p node: %1").arg(result.getError());
        return false;
    }

    setCurrentConfig(config);
    m_initialized = true;
    m_serviceDiscoveryStarted = false;
    clearRuntimeInfo();
    setSettingsEditable(true);
    if (persist) {
        persistConfig();
    }
    return true;
}

bool Libp2pBackend::ensureInitialized() {
    if (m_initialized) {
        return true;
    }

    bool completed = false;
    bool ok = false;
    QString err;

    QMetaObject::Connection connection =
        connect(this, &Libp2pBackend::initCompleted, this, [&](bool success, const QString& error) {
            completed = true;
            ok = success;
            err = error;
        });

    init(nodeConfigJson());
    disconnect(connection);

    if (!completed || !ok) {
        if (err.isEmpty()) {
            err = QStringLiteral("Failed to initialize libp2p node.");
        }
        emit startFailed(err);
        return false;
    }
    return true;
}

void Libp2pBackend::start() {
    if (status() == Running || status() == Starting) {
        return;
    }

    if (status() == Stopping) {
        const QString message = QStringLiteral("libp2p node is currently stopping.");
        reportError(message);
        emit startFailed(message);
        return;
    }

    if (!ensureInitialized()) {
        return;
    }

    setStatus(Starting);
    setSettingsEditable(false);
    LogosResult result = m_logos->libp2p_module.start();
    if (!result.success) {
        setStatus(Stopped);
        setSettingsEditable(true);
        const QString message = QStringLiteral("Failed to start libp2p node: %1").arg(result.getError());
        reportError(message);
        emit startFailed(message);
        return;
    }

    setStatus(Running);
    setSettingsEditable(false);
    resetMetricHistory();
    m_nodeUptime.start();
    updateMetricsTimer();
    refreshPeers();
    refreshMetrics();
    refreshOverview();
    emit startCompleted();
}

void Libp2pBackend::stop() {
    if (status() == Stopping) {
        return;
    }

    if (status() != Running && status() != Starting) {
        setStatus(Stopped);
        setSettingsEditable(true);
        clearRuntimeInfo();
        emit stopCompleted();
        return;
    }

    setStatus(Stopping);
    setSettingsEditable(false);
    if (m_serviceDiscoveryStarted) {
        LogosResult discoveryResult = m_logos->libp2p_module.discoStop();
        if (!discoveryResult.success) {
            qWarning() << "Libp2pBackend: failed to stop service discovery:" << discoveryResult.getError();
        }
        m_serviceDiscoveryStarted = false;
    }
    LogosResult result = m_logos->libp2p_module.stop();
    if (!result.success) {
        setStatus(Running);
        setSettingsEditable(false);
        reportError(QStringLiteral("Failed to stop libp2p node: %1").arg(result.getError()));
        return;
    }

    setStatus(Stopped);
    setSettingsEditable(true);
    updateMetricsTimer();
    clearRuntimeInfo();
    emit stopCompleted();
}

QString Libp2pBackend::firstListenAddress() const {
    LogosResult result = m_logos->libp2p_module.getNodeInfo(QStringLiteral("Multiaddrs"));
    if (!result.success) {
        qWarning() << "Libp2pBackend: failed to read multiaddrs:" << result.getError();
        return QString();
    }

    const QVariantList addrs = result.getList();
    if (addrs.isEmpty()) {
        return QString();
    }
    return addrs.first().toString();
}

int Libp2pBackend::connectedPeerCount() const {
    int count = 0;

    LogosResult inbound = m_logos->libp2p_module.connectedPeers(kInboundDirection);
    if (inbound.success) {
        count += inbound.getList().size();
    } else {
        qWarning() << "Libp2pBackend: failed to read inbound peers:" << inbound.getError();
    }

    LogosResult outbound = m_logos->libp2p_module.connectedPeers(kOutboundDirection);
    if (outbound.success) {
        count += outbound.getList().size();
    } else {
        qWarning() << "Libp2pBackend: failed to read outbound peers:" << outbound.getError();
    }

    return count;
}

bool Libp2pBackend::ensureRunning(const QString& operation) {
    if (status() == Running) {
        return true;
    }

    reportError(QStringLiteral("Cannot %1 while the libp2p node is not running.").arg(operation));
    return false;
}

bool Libp2pBackend::ensureServiceDiscoveryStarted() {
    if (m_serviceDiscoveryStarted) {
        return true;
    }

    LogosResult result = m_logos->libp2p_module.discoStart();
    if (!result.success) {
        reportError(QStringLiteral("Failed to start service discovery: %1").arg(result.getError()));
        return false;
    }

    m_serviceDiscoveryStarted = true;
    return true;
}

void Libp2pBackend::gossipsubSubscribe(QString topic) {
    topic = topic.trimmed();
    if (!ensureRunning(QStringLiteral("subscribe to a GossipSub topic"))) {
        return;
    }
    if (topic.isEmpty()) {
        reportError(QStringLiteral("A GossipSub topic is required."));
        return;
    }
    if (subscribedTopics().contains(topic)) {
        reportError(QStringLiteral("Already subscribed to GossipSub topic '%1'.").arg(topic));
        return;
    }

    LogosResult result = m_logos->libp2p_module.gossipsubSubscribe(topic);
    if (!result.success) {
        reportError(
            QStringLiteral("Failed to subscribe to GossipSub topic '%1': %2").arg(topic, result.getError()));
        return;
    }

    QVariantList topics = subscribedTopics();
    topics.append(topic);
    setSubscribedTopics(topics);
    setGossipsubTopics(topics.size());
    emit gossipsubTopicSubscribed(topic);
}

void Libp2pBackend::gossipsubUnsubscribe(QString topic) {
    topic = topic.trimmed();
    if (!ensureRunning(QStringLiteral("unsubscribe from a GossipSub topic"))) {
        return;
    }
    if (topic.isEmpty() || !subscribedTopics().contains(topic)) {
        reportError(QStringLiteral("Not subscribed to GossipSub topic '%1'.").arg(topic));
        return;
    }

    LogosResult result = m_logos->libp2p_module.gossipsubUnsubscribe(topic);
    if (!result.success) {
        reportError(QStringLiteral("Failed to unsubscribe from GossipSub topic '%1': %2")
                        .arg(topic, result.getError()));
        return;
    }

    QVariantList topics = subscribedTopics();
    topics.removeAll(topic);
    setSubscribedTopics(topics);
    setGossipsubTopics(topics.size());
    emit gossipsubTopicUnsubscribed(topic);
}

void Libp2pBackend::gossipsubPublish(QString topic, QString message) {
    topic = topic.trimmed();
    if (!ensureRunning(QStringLiteral("publish a GossipSub message"))) {
        return;
    }
    if (topic.isEmpty()) {
        reportError(QStringLiteral("A GossipSub topic is required."));
        return;
    }
    if (message.trimmed().isEmpty()) {
        reportError(QStringLiteral("A GossipSub message is required."));
        return;
    }

    LogosResult result = m_logos->libp2p_module.gossipsubPublish(topic, message);
    if (!result.success) {
        reportError(
            QStringLiteral("Failed to publish to GossipSub topic '%1': %2").arg(topic, result.getError()));
        return;
    }

    emit gossipsubMessagePublished(topic);
    refreshMetrics();
}

void Libp2pBackend::refreshPeers() {
    if (status() != Running) {
        setInboundPeers(QVariantList{});
        setOutboundPeers(QVariantList{});
        setKnownPeers(0);
        setConnectedPeers(0);
        emit peersUpdated();
        return;
    }

    QVariantList inboundPeers;
    QVariantList outboundPeers;
    LogosResult inbound = m_logos->libp2p_module.connectedPeers(kInboundDirection);
    if (inbound.success) {
        inboundPeers = inbound.getList();
    } else {
        qWarning() << "Libp2pBackend: failed to read inbound peers:" << inbound.getError();
    }
    LogosResult outbound = m_logos->libp2p_module.connectedPeers(kOutboundDirection);
    if (outbound.success) {
        outboundPeers = outbound.getList();
    } else {
        qWarning() << "Libp2pBackend: failed to read outbound peers:" << outbound.getError();
    }

    setInboundPeers(inboundPeers);
    setOutboundPeers(outboundPeers);
    setConnectedPeers(inboundPeers.size() + outboundPeers.size());

    LogosResult known = m_logos->libp2p_module.peerstoreGetPeers();
    setKnownPeers(known.success ? known.getList().size() : 0);
    if (!known.success) {
        qWarning() << "Libp2pBackend: failed to read peerstore:" << known.getError();
    }
    emit peersUpdated();
}

void Libp2pBackend::connectPeer(QString peerId, QString multiaddr) {
    peerId = peerId.trimmed();
    multiaddr = multiaddr.trimmed();
    if (!ensureRunning(QStringLiteral("connect to a peer"))) {
        return;
    }
    if (peerId.isEmpty() || multiaddr.isEmpty()) {
        reportError(QStringLiteral("A peer ID and multiaddress are required to connect."));
        return;
    }

    LogosResult result = m_logos->libp2p_module.connectPeer(peerId, QStringList{multiaddr}, 5000);
    if (!result.success) {
        reportError(QStringLiteral("Failed to connect to peer '%1': %2").arg(peerId, result.getError()));
        return;
    }

    refreshPeers();
    refreshMetrics();
    refreshOverview();
    emit peerConnected(peerId);
}

void Libp2pBackend::disconnectPeer(QString peerId) {
    peerId = peerId.trimmed();
    if (!ensureRunning(QStringLiteral("disconnect a peer"))) {
        return;
    }
    if (peerId.isEmpty()) {
        reportError(QStringLiteral("A peer ID is required to disconnect."));
        return;
    }

    LogosResult result = m_logos->libp2p_module.disconnectPeer(peerId);
    if (!result.success) {
        reportError(QStringLiteral("Failed to disconnect peer '%1': %2").arg(peerId, result.getError()));
        return;
    }

    refreshPeers();
    refreshMetrics();
    refreshOverview();
    emit peerDisconnected(peerId);
}

void Libp2pBackend::refreshMetrics() {
    QVariantMap values{{"connectedPeersMetric", 0},
                       {"openStreams", 0},
                       {"openInboundStreams", 0},
                       {"openOutboundStreams", 0},
                       {"streamCapRejections", 0},
                       {"streamsOpened", 0},
                       {"streamsClosed", 0},
                       {"streamResets", 0},
                       {"streamTimeouts", 0},
                       {"gossipsubPublished", 0},
                       {"gossipsubReceived", 0},
                       {"gossipsubDuplicates", 0},
                       {"gossipsubDuplicateRatio", 0},
                       {"gossipsubValidationSuccesses", 0},
                       {"gossipsubValidationFailures", 0},
                       {"gossipsubValidationIgnored", 0},
                       {"gossipsubSignatureFailures", 0},
                       {"gossipsubFailedPublishes", 0},
                       {"gossipsubNoPeerTopics", 0},
                       {"gossipsubLowPeerTopics", 0},
                       {"gossipsubHealthyTopics", 0},
                       {"gossipsubRateLimitHits", 0},
                       {"gossipsubQueueDepth", 0},
                       {"gossipsubQueueDrops", 0},
                       {"dhtRoutingPeers", 0},
                       {"dhtRoutingBuckets", 0},
                       {"dhtNetworkSizeEstimate", 0},
                       {"dhtRoutingInsertions", 0},
                       {"dhtRoutingReplacements", 0},
                       {"dhtRoutingEvictions", 0},
                       {"dhtLivenessSuccesses", 0},
                       {"dhtLivenessFailures", 0},
                       {"dhtLookupFollowups", 0},
                       {"dhtProviderRejections", 0},
                       {"dhtProviderSpillovers", 0},
                       {"dhtRepublishedRegions", 0},
                       {"dhtRepublishedKeys", 0},
                       {"discoveryAdvertisements", 0},
                       {"discoveryServices", 0},
                       {"discoveryServicePeers", 0},
                       {"discoveryLookupRequests", 0},
                       {"discoveryPeersFound", 0},
                       {"discoveryExpiredAdvertisements", 0},
                       {"discoveryServiceTables", 0},
                       {"discoveryTableInsertions", 0},
                       {"discoveryTrackedIps", 0},
                       {"discoveryPendingActions", 0},
                       {"discoveryActionsExecuted", 0},
                       {"discoveryServicesAdded", 0},
                       {"discoveryServicesRemoved", 0},
                       {"trafficBytesReceived", 0},
                       {"trafficBytesSent", 0},
                       {"trafficSessionBytesReceived", 0},
                       {"trafficSessionBytesSent", 0},
                       {"trafficReceiveRate", 0},
                       {"trafficSendRate", 0},
                       {"trafficPeakReceiveRate", m_peakReceiveRate},
                       {"trafficPeakSendRate", m_peakSendRate},
                       {"dialAttempts", 0},
                       {"dialSuccesses", 0},
                       {"dialFailures", 0},
                       {"dialSuccessRate", 0},
                       {"dialLatencyP50Ms", 0},
                       {"dialLatencyP95Ms", 0},
                       {"dialLatencyP99Ms", 0},
                       {"dialLatencyAvailable", false},
                       {"failedUpgradesInbound", 0},
                       {"failedUpgradesOutbound", 0},
                       {"connectionManagerTrims", 0},
                       {"connectionManagerPrunedPeers", 0},
                       {"connectionsOpened", 0},
                       {"connectionsClosed", 0},
                       {"autonatReachability", QStringLiteral("Unknown")},
                       {"autonatConfidence", 0},
                       {"autonatV2Reachability", QStringLiteral("Unknown")},
                       {"autonatV2Confidence", 0},
                       {"relayReservationsActive", 0},
                       {"relayCircuitsActive", 0},
                       {"relayBytesReceived", 0},
                       {"relayBytesSent", 0},
                       {"nodeUptimeSeconds", m_nodeUptime.isValid() ? m_nodeUptime.elapsed() / 1000 : 0},
                       {"lastMetricsUpdateMs", 0},
                       {"metricSeries", QVariantList{}},
                       {"availableMetrics", QVariantList{}},
                       {"trafficHistory", m_metricHistory},
                       {"trafficByProtocol", QVariantList{}},
                       {"trafficByAgent", QVariantList{}},
                       {"streamsByProtocol", QVariantList{}},
                       {"gossipsubByTopic", QVariantList{}},
                       {"dhtMessagesByType", QVariantList{}},
                       {"dhtBucketSizes", QVariantList{}},
                       {"discoveryMessagesByType", QVariantList{}}};

    if (status() != Running) {
        setMetrics(values);
        setActiveStreams(0);
        emit metricsUpdated(values);
        return;
    }

    const QVariantMap payload = m_logos->libp2p_module.collectMetrics();
    const QVariantList series = payload.value(QStringLiteral("metrics")).toList();
    QVariantList normalizedSeries;
    QSet<QString> available;
    QVariantMap protocolTraffic;
    QVariantMap agentTraffic;
    QVariantMap streamProtocols;
    QVariantMap gossipsubTopics;
    QVariantMap dhtMessageTypes;
    QVariantMap dhtBuckets;
    QVariantMap discoveryMessageTypes;
    QMap<double, double> successfulDialBuckets;

    auto metricMatches = [](const QString& actual, const char* base) {
        const QString expected = QString::fromLatin1(base);
        return actual == expected || actual == expected + QStringLiteral("_total");
    };
    auto seriesMap = [](QVariantMap& groups, const QString& key) {
        return groups.value(key).toMap();
    };
    auto storeSeriesMap = [](QVariantMap& groups, const QString& key, const QVariantMap& item) {
        groups.insert(key, item);
    };
    auto accumulateField = [](QVariantMap item, const QString& field, double value) {
        item[field] = item.value(field).toDouble() + value;
        return item;
    };

    for (const QVariant& item : series) {
        const QVariantMap metric = item.toMap();
        const QString name = metric.value(QStringLiteral("name")).toString();
        const QVariantMap labels = metric.value(QStringLiteral("labels")).toMap();
        const double value = metric.value(QStringLiteral("value")).toDouble();
        if (name.isEmpty())
            continue;
        normalizedSeries.append(metric);
        available.insert(name);
        auto add = [&](const char* key) { values[QString::fromLatin1(key)] = values.value(QString::fromLatin1(key)).toDouble() + value; };

        if (name == QStringLiteral("libp2p_peers"))
            values["connectedPeersMetric"] = value;
        else if (name == QStringLiteral("libp2p_protocol_streams_open")) {
            add("openStreams");
            if (labels.value("direction").toString() == QStringLiteral("in"))
                add("openInboundStreams");
            else if (labels.value("direction").toString() == QStringLiteral("out"))
                add("openOutboundStreams");
        } else if (name == QStringLiteral("libp2p_protocol_stream_cap_rejections")
                   || name == QStringLiteral("libp2p_protocol_stream_cap_rejections_total"))
            add("streamCapRejections");
        else if (name == QStringLiteral("libp2p_pubsub_messages_published")
                 || name == QStringLiteral("libp2p_pubsub_messages_published_total"))
            add("gossipsubPublished");
        else if (name == QStringLiteral("libp2p_pubsub_received_messages")
                 || name == QStringLiteral("libp2p_pubsub_received_messages_total"))
            add("gossipsubReceived");
        else if (name == QStringLiteral("kad_routing_table_peers"))
            values["dhtRoutingPeers"] = value;
        else if (name == QStringLiteral("kad_routing_table_buckets"))
            values["dhtRoutingBuckets"] = value;
        else if (name == QStringLiteral("kad_network_size_estimate"))
            values["dhtNetworkSizeEstimate"] = value;
        else if (name == QStringLiteral("cd_registrar_cache_ads"))
            values["discoveryAdvertisements"] = value;
        else if (name == QStringLiteral("cd_registrar_cache_services"))
            values["discoveryServices"] = value;
        else if (name == QStringLiteral("cd_service_table_peers"))
            values["discoveryServicePeers"] = value;
        else if (name == QStringLiteral("cd_lookup_requests") || name == QStringLiteral("cd_lookup_requests_total"))
            add("discoveryLookupRequests");
        else if (name == QStringLiteral("cd_lookup_peers_found") || name == QStringLiteral("cd_lookup_peers_found_total"))
            add("discoveryPeersFound");

        if (metricMatches(name, "libp2p_gossipsub_duplicate")) add("gossipsubDuplicates");
        else if (metricMatches(name, "libp2p_pubsub_validation_success")) add("gossipsubValidationSuccesses");
        else if (metricMatches(name, "libp2p_pubsub_validation_failure")) add("gossipsubValidationFailures");
        else if (metricMatches(name, "libp2p_pubsub_validation_ignore")) add("gossipsubValidationIgnored");
        else if (metricMatches(name, "libp2p_pubsub_sig_verify_failure")) add("gossipsubSignatureFailures");
        else if (metricMatches(name, "libp2p_gossipsub_failed_publish")) add("gossipsubFailedPublishes");
        else if (name == QStringLiteral("libp2p_gossipsub_no_peers_topics")) add("gossipsubNoPeerTopics");
        else if (name == QStringLiteral("libp2p_gossipsub_low_peers_topics")) add("gossipsubLowPeerTopics");
        else if (name == QStringLiteral("libp2p_gossipsub_healthy_peers_topics")) add("gossipsubHealthyTopics");
        else if (metricMatches(name, "libp2p_gossipsub_peers_rate_limit_hits")) add("gossipsubRateLimitHits");
        else if (name == QStringLiteral("libp2p_module_gossipsub_queue_depth")) add("gossipsubQueueDepth");
        else if (metricMatches(name, "libp2p_module_gossipsub_queue_dropped")) add("gossipsubQueueDrops");
        else if (metricMatches(name, "libp2p_pubsub_medium_priority_queue_drops")
                 || metricMatches(name, "libp2p_pubsub_low_priority_queue_drops")) add("gossipsubQueueDrops");

        if (metricMatches(name, "libp2p_streams_opened")) add("streamsOpened");
        else if (metricMatches(name, "libp2p_streams_closed")) add("streamsClosed");
        else if (metricMatches(name, "libp2p_stream_resets")) add("streamResets");
        else if (metricMatches(name, "libp2p_stream_timeouts")) add("streamTimeouts");
        if (metricMatches(name, "libp2p_connections_opened")) add("connectionsOpened");
        else if (metricMatches(name, "libp2p_connections_closed")) add("connectionsClosed");

        if (metricMatches(name, "kad_routing_table_insertions")) add("dhtRoutingInsertions");
        else if (metricMatches(name, "kad_routing_table_replacements")) add("dhtRoutingReplacements");
        else if (metricMatches(name, "kad_routing_table_evictions")) add("dhtRoutingEvictions");
        else if (metricMatches(name, "kad_routing_table_liveness_probes")) {
            if (labels.value(QStringLiteral("result")).toString().compare(QStringLiteral("success"), Qt::CaseInsensitive) == 0)
                add("dhtLivenessSuccesses");
            else
                add("dhtLivenessFailures");
        } else if (metricMatches(name, "kad_lookup_followups")) add("dhtLookupFollowups");
        else if (metricMatches(name, "kad_provider_rejections_sent")) add("dhtProviderRejections");
        else if (metricMatches(name, "kad_provider_spillover_rounds")) add("dhtProviderSpillovers");
        else if (metricMatches(name, "kad_provider_republish_regions")) add("dhtRepublishedRegions");
        else if (metricMatches(name, "kad_provider_republish_keys")) add("dhtRepublishedKeys");

        if (metricMatches(name, "cd_registrar_ads_expired")) add("discoveryExpiredAdvertisements");
        else if (name == QStringLiteral("cd_service_tables_count")) add("discoveryServiceTables");
        else if (metricMatches(name, "cd_service_table_insertions")) add("discoveryTableInsertions");
        else if (name == QStringLiteral("cd_iptree_total_ips")) add("discoveryTrackedIps");
        else if (name == QStringLiteral("cd_advertiser_pending_actions")) add("discoveryPendingActions");
        else if (metricMatches(name, "cd_advertiser_actions_executed")) add("discoveryActionsExecuted");
        else if (metricMatches(name, "cd_advertiser_services_added")) add("discoveryServicesAdded");
        else if (metricMatches(name, "cd_advertiser_services_removed")) add("discoveryServicesRemoved");

        if (metricMatches(name, "libp2p_network_bytes")) {
            if (labels.value(QStringLiteral("direction")).toString() == QStringLiteral("in"))
                add("trafficBytesReceived");
            else if (labels.value(QStringLiteral("direction")).toString() == QStringLiteral("out"))
                add("trafficBytesSent");
        } else if (metricMatches(name, "libp2p_protocols_bytes")) {
            const QString protocol = labels.value(QStringLiteral("protocol"), QStringLiteral("unknown")).toString();
            QVariantMap group = seriesMap(protocolTraffic, protocol);
            group["protocol"] = protocol;
            const QString field = labels.value(QStringLiteral("direction")).toString() == QStringLiteral("in")
                                      ? QStringLiteral("bytesReceived") : QStringLiteral("bytesSent");
            storeSeriesMap(protocolTraffic, protocol, accumulateField(group, field, value));
        } else if (metricMatches(name, "libp2p_peers_traffic_read") || metricMatches(name, "libp2p_peers_traffic_write")) {
            const QString agent = labels.value(QStringLiteral("agent"), QStringLiteral("unknown")).toString();
            QVariantMap group = seriesMap(agentTraffic, agent);
            group["agent"] = agent;
            const QString field = name.contains(QStringLiteral("read")) ? QStringLiteral("bytesReceived") : QStringLiteral("bytesSent");
            storeSeriesMap(agentTraffic, agent, accumulateField(group, field, value));
        } else if (metricMatches(name, "libp2p_total_dial_attempts")) {
            add("dialAttempts");
        } else if (metricMatches(name, "libp2p_successful_dials")) {
            add("dialSuccesses");
        } else if (metricMatches(name, "libp2p_failed_dials")) {
            add("dialFailures");
        } else if (name == QStringLiteral("libp2p_dial_duration_ms_bucket")
                   && labels.value(QStringLiteral("result")).toString() == QStringLiteral("success")) {
            bool isFiniteBucket = false;
            const double upperBound = labels.value(QStringLiteral("le")).toString().toDouble(&isFiniteBucket);
            if (isFiniteBucket)
                successfulDialBuckets[upperBound] += value;
        } else if (metricMatches(name, "libp2p_failed_upgrades_incoming")) {
            add("failedUpgradesInbound");
        } else if (metricMatches(name, "libp2p_failed_upgrades_outgoing")) {
            add("failedUpgradesOutbound");
        } else if (name == QStringLiteral("libp2p_connmgr_trim_total") || name == QStringLiteral("libp2p_connmgr_trim_total_total")) {
            add("connectionManagerTrims");
        } else if (name == QStringLiteral("libp2p_connmgr_pruned_peers_total") || name == QStringLiteral("libp2p_connmgr_pruned_peers_total_total")) {
            add("connectionManagerPrunedPeers");
        } else if (name == QStringLiteral("libp2p_autonat_reachability_confidence")
                   || name == QStringLiteral("libp2p_autonat_v2_reachability_confidence")) {
            const QString reachability = labels.value(QStringLiteral("reachability"), QStringLiteral("Unknown")).toString();
            const bool v2 = name.contains(QStringLiteral("_v2_"));
            const QString confidenceKey = v2 ? QStringLiteral("autonatV2Confidence") : QStringLiteral("autonatConfidence");
            const QString stateKey = v2 ? QStringLiteral("autonatV2Reachability") : QStringLiteral("autonatReachability");
            if (value >= values.value(confidenceKey).toDouble()) {
                values[confidenceKey] = value;
                values[stateKey] = reachability;
            }
        } else if (metricMatches(name, "libp2p_relay_reservations_active")) {
            add("relayReservationsActive");
        } else if (metricMatches(name, "libp2p_relay_circuits_active")) {
            add("relayCircuitsActive");
        } else if (metricMatches(name, "libp2p_relay_bytes")) {
            const QString field = labels.value(QStringLiteral("direction")).toString() == QStringLiteral("in")
                                      ? QStringLiteral("relayBytesReceived") : QStringLiteral("relayBytesSent");
            values[field] = values.value(field).toDouble() + value;
        }

        if (name == QStringLiteral("libp2p_protocol_streams_open")
            || name == QStringLiteral("libp2p_protocol_stream_cap_rejections")
            || name == QStringLiteral("libp2p_protocol_stream_cap_rejections_total")
            || metricMatches(name, "libp2p_streams_opened")
            || metricMatches(name, "libp2p_streams_closed")) {
            const QString protocol = labels.value(QStringLiteral("protocol"), QStringLiteral("unknown")).toString();
            QVariantMap group = seriesMap(streamProtocols, protocol);
            group["protocol"] = protocol;
            if (name == QStringLiteral("libp2p_protocol_streams_open")) {
                const QString field = labels.value(QStringLiteral("direction")).toString() == QStringLiteral("in")
                                          ? QStringLiteral("inbound") : QStringLiteral("outbound");
                group = accumulateField(group, field, value);
                group["total"] = group.value("inbound").toDouble() + group.value("outbound").toDouble();
            } else if (metricMatches(name, "libp2p_streams_opened")) {
                group = accumulateField(group, QStringLiteral("opened"), value);
            } else if (metricMatches(name, "libp2p_streams_closed")) {
                group = accumulateField(group, QStringLiteral("closed"), value);
            } else {
                group = accumulateField(group, QStringLiteral("rejections"), value);
                const QString scope = labels.value(QStringLiteral("scope")).toString();
                if (!scope.isEmpty())
                    group = accumulateField(group, scope == QStringLiteral("per_peer") ? QStringLiteral("perPeerRejections") : QStringLiteral("totalRejections"), value);
            }
            storeSeriesMap(streamProtocols, protocol, group);
        }

        if (name.startsWith(QStringLiteral("libp2p_pubsub_"))
            || name.startsWith(QStringLiteral("libp2p_gossipsub_"))
            || name.startsWith(QStringLiteral("libp2p_module_gossipsub_"))) {
            const QString topic = labels.value(QStringLiteral("topic")).toString();
            if (!topic.isEmpty()) {
                QVariantMap group = seriesMap(gossipsubTopics, topic);
                group["topic"] = topic;
                if (metricMatches(name, "libp2p_pubsub_messages_published"))
                    group = accumulateField(group, QStringLiteral("published"), value);
                else if (metricMatches(name, "libp2p_pubsub_received_messages"))
                    group = accumulateField(group, QStringLiteral("received"), value);
                else if (metricMatches(name, "libp2p_pubsub_messages_rebroadcasted"))
                    group = accumulateField(group, QStringLiteral("rebroadcasted"), value);
                else if (name == QStringLiteral("libp2p_gossipsub_peers_per_topic_mesh"))
                    group["meshPeers"] = value;
                else if (name == QStringLiteral("libp2p_gossipsub_peers_per_topic_fanout"))
                    group["fanoutPeers"] = value;
                else if (name == QStringLiteral("libp2p_gossipsub_peers_per_topic_gossipsub"))
                    group["gossipsubPeers"] = value;
                else if (name == QStringLiteral("libp2p_module_gossipsub_queue_depth"))
                    group["queueDepth"] = value;
                else if (metricMatches(name, "libp2p_module_gossipsub_queue_dropped"))
                    group["queueDrops"] = value;
                storeSeriesMap(gossipsubTopics, topic, group);
            }
        }

        if (name.startsWith(QStringLiteral("kad_message")) || name.startsWith(QStringLiteral("kad_messages"))) {
            const QString type = labels.value(QStringLiteral("type"), QStringLiteral("unknown")).toString();
            QVariantMap group = seriesMap(dhtMessageTypes, type);
            group["type"] = type;
            if (metricMatches(name, "kad_messages_sent")) group = accumulateField(group, QStringLiteral("messagesSent"), value);
            else if (metricMatches(name, "kad_messages_received")) group = accumulateField(group, QStringLiteral("messagesReceived"), value);
            else if (metricMatches(name, "kad_message_bytes_sent")) group = accumulateField(group, QStringLiteral("bytesSent"), value);
            else if (metricMatches(name, "kad_message_bytes_received")) group = accumulateField(group, QStringLiteral("bytesReceived"), value);
            storeSeriesMap(dhtMessageTypes, type, group);
        } else if (name == QStringLiteral("kad_routing_table_bucket_size")) {
            const QString bucket = labels.value(QStringLiteral("bucket"), QStringLiteral("unknown")).toString();
            dhtBuckets[bucket] = QVariantMap{{"bucket", bucket}, {"peers", value}};
        }

        if (name.startsWith(QStringLiteral("cd_message")) || name.startsWith(QStringLiteral("cd_messages"))) {
            const QString type = labels.value(QStringLiteral("type"), QStringLiteral("unknown")).toString();
            QVariantMap group = seriesMap(discoveryMessageTypes, type);
            group["type"] = type;
            if (metricMatches(name, "cd_messages_sent")) group = accumulateField(group, QStringLiteral("messagesSent"), value);
            else if (metricMatches(name, "cd_messages_received")) group = accumulateField(group, QStringLiteral("messagesReceived"), value);
            else if (metricMatches(name, "cd_message_bytes_sent")) group = accumulateField(group, QStringLiteral("bytesSent"), value);
            else if (metricMatches(name, "cd_message_bytes_received")) group = accumulateField(group, QStringLiteral("bytesReceived"), value);
            storeSeriesMap(discoveryMessageTypes, type, group);
        }
    }

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    auto updateCounterRate = [&](const QString& metricKey, const QString& rateKey) {
        const double current = values.value(metricKey).toDouble();
        if (!m_sessionBaselines.contains(metricKey))
            m_sessionBaselines[metricKey] = current;
        if (m_previousMetricsTimestampMs > 0 && m_previousCounters.contains(metricKey)) {
            const double previous = m_previousCounters.value(metricKey).toDouble();
            const double delta = current >= previous ? current - previous : current;
            const double seconds = (nowMs - m_previousMetricsTimestampMs) / 1000.0;
            values[rateKey] = seconds > 0 ? delta / seconds : 0;
        }
        m_previousCounters[metricKey] = current;
    };
    updateCounterRate(QStringLiteral("trafficBytesReceived"), QStringLiteral("trafficReceiveRate"));
    updateCounterRate(QStringLiteral("trafficBytesSent"), QStringLiteral("trafficSendRate"));
    values["trafficSessionBytesReceived"] = qMax(0.0, values.value("trafficBytesReceived").toDouble() - m_sessionBaselines.value("trafficBytesReceived").toDouble());
    values["trafficSessionBytesSent"] = qMax(0.0, values.value("trafficBytesSent").toDouble() - m_sessionBaselines.value("trafficBytesSent").toDouble());
    m_peakReceiveRate = qMax(m_peakReceiveRate, values.value("trafficReceiveRate").toDouble());
    m_peakSendRate = qMax(m_peakSendRate, values.value("trafficSendRate").toDouble());
    values["trafficPeakReceiveRate"] = m_peakReceiveRate;
    values["trafficPeakSendRate"] = m_peakSendRate;
    const double attempts = values.value("dialAttempts").toDouble();
    values["dialSuccessRate"] = attempts > 0 ? 100.0 * values.value("dialSuccesses").toDouble() / attempts : 0;
    if (!successfulDialBuckets.isEmpty() && successfulDialBuckets.last() > 0) {
        const double observations = successfulDialBuckets.last();
        auto histogramQuantile = [&](double quantile) {
            const double target = observations * quantile;
            for (auto bucket = successfulDialBuckets.cbegin(); bucket != successfulDialBuckets.cend(); ++bucket) {
                if (bucket.value() >= target)
                    return bucket.key();
            }
            return successfulDialBuckets.lastKey();
        };
        values["dialLatencyP50Ms"] = histogramQuantile(0.50);
        values["dialLatencyP95Ms"] = histogramQuantile(0.95);
        values["dialLatencyP99Ms"] = histogramQuantile(0.99);
        values["dialLatencyAvailable"] = true;
    }
    const double gossipReceived = values.value("gossipsubReceived").toDouble();
    const double gossipDuplicates = values.value("gossipsubDuplicates").toDouble();
    values["gossipsubDuplicateRatio"] = gossipReceived + gossipDuplicates > 0
        ? 100.0 * gossipDuplicates / (gossipReceived + gossipDuplicates) : 0;

    auto groupsToList = [](const QVariantMap& groups) {
        QVariantList list;
        for (auto it = groups.cbegin(); it != groups.cend(); ++it)
            list.append(it.value());
        return list;
    };
    QVariantList availability;
    QStringList names = available.values();
    names.sort();
    for (const QString& name : names) availability.append(name);
    values["metricSeries"] = normalizedSeries;
    values["availableMetrics"] = availability;
    values["trafficByProtocol"] = groupsToList(protocolTraffic);
    values["trafficByAgent"] = groupsToList(agentTraffic);
    values["streamsByProtocol"] = groupsToList(streamProtocols);
    values["gossipsubByTopic"] = groupsToList(gossipsubTopics);
    values["dhtMessagesByType"] = groupsToList(dhtMessageTypes);
    values["dhtBucketSizes"] = groupsToList(dhtBuckets);
    values["discoveryMessagesByType"] = groupsToList(discoveryMessageTypes);
    values["lastMetricsUpdateMs"] = nowMs;

    m_metricHistory.append(QVariantMap{{"timestampMs", nowMs},
                                       {"bytesReceived", values.value("trafficBytesReceived")},
                                       {"bytesSent", values.value("trafficBytesSent")},
                                       {"receiveRate", values.value("trafficReceiveRate")},
                                       {"sendRate", values.value("trafficSendRate")},
                                       {"peers", values.value("connectedPeersMetric")},
                                       {"streams", values.value("openStreams")}});
    while (!m_metricHistory.isEmpty()
           && nowMs - m_metricHistory.first().toMap().value("timestampMs").toLongLong() > kMetricHistoryRetentionMs)
        m_metricHistory.removeFirst();
    values["trafficHistory"] = m_metricHistory;
    m_previousMetricsTimestampMs = nowMs;

    setMetrics(values);
    setActiveStreams(qRound(values.value("openStreams").toDouble()));
    setRelayReservations(qRound(values.value("relayReservationsActive").toDouble()));
    emit metricsUpdated(values);
}

void Libp2pBackend::pingPeer(QString peerId) {
    peerId = peerId.trimmed();
    if (!ensureRunning(QStringLiteral("ping a peer"))) {
        return;
    }
    if (peerId.isEmpty()) {
        reportError(QStringLiteral("A peer ID is required to ping."));
        return;
    }

    const QString protocol = QStringLiteral("/ipfs/ping/1.0.0");
    const QByteArray payload("0123456789abcdefghijklmnopqrstuv");
    QElapsedTimer timer;
    timer.start();
    LogosResult dial = m_logos->libp2p_module.dial(peerId, protocol);
    if (!dial.success) {
        reportError(QStringLiteral("Failed to open ping stream to '%1': %2").arg(peerId, dial.getError()));
        return;
    }

    const qulonglong streamId = dial.getValue<qulonglong>();
    bool ok = false;
    QString failure;
    LogosResult write = m_logos->libp2p_module.streamWrite(streamId, QString::fromLatin1(payload));
    if (!write.success) {
        failure = QStringLiteral("Failed to send ping payload: %1").arg(write.getError());
    } else {
        LogosResult read = m_logos->libp2p_module.streamReadExactly(streamId, payload.size());
        if (!read.success) {
            failure = QStringLiteral("Failed to read ping response: %1").arg(read.getError());
        } else if (QByteArray::fromBase64(read.getString().toUtf8()) != payload) {
            failure = QStringLiteral("Ping response did not match the sent payload.");
        } else {
            ok = true;
        }
    }
    m_logos->libp2p_module.streamCloseWithEOF(streamId);
    m_logos->libp2p_module.streamRelease(streamId);

    if (!ok) {
        reportError(failure);
        refreshMetrics();
        return;
    }
    QVariantMap result{{"peerId", peerId}, {"latencyMs", timer.elapsed()}, {"success", true}};
    setLastPingResult(result);
    refreshMetrics();
    emit pingCompleted(result);
}

void Libp2pBackend::dhtFindPeer(QString peerId) {
    peerId = peerId.trimmed();
    if (!ensureRunning(QStringLiteral("look up a DHT peer"))) {
        return;
    }
    if (peerId.isEmpty()) {
        reportError(QStringLiteral("A peer ID is required for DHT lookup."));
        return;
    }

    LogosResult result = m_logos->libp2p_module.kadFindNode(peerId);
    if (!result.success) {
        reportError(QStringLiteral("DHT lookup failed for '%1': %2").arg(peerId, result.getError()));
        return;
    }
    setDhtLookupResults(result.getList());
    refreshMetrics();
    emit dhtLookupCompleted(peerId);
}

void Libp2pBackend::serviceDiscoveryAdvertise(QString serviceId, QString serviceData) {
    serviceId = serviceId.trimmed();
    if (!ensureRunning(QStringLiteral("advertise a service"))) {
        return;
    }
    if (serviceId.isEmpty()) {
        reportError(QStringLiteral("A service ID is required to advertise."));
        return;
    }
    if (!ensureServiceDiscoveryStarted()) {
        return;
    }
    for (const QVariant& item : advertisedServices()) {
        if (item.toMap().value("serviceId").toString() == serviceId) {
            reportError(QStringLiteral("Already advertising service '%1'. Stop it before advertising it again.").arg(serviceId));
            return;
        }
    }

    LogosResult result = m_logos->libp2p_module.discoStartAdvertising(serviceId, serviceData);
    if (!result.success) {
        reportError(QStringLiteral("Failed to advertise service '%1': %2").arg(serviceId, result.getError()));
        return;
    }
    QVariantList services = advertisedServices();
    services.append(QVariantMap{{"serviceId", serviceId}, {"serviceData", serviceData}});
    setAdvertisedServices(services);
    refreshMetrics();
    emit serviceAdvertised(serviceId);
}

void Libp2pBackend::serviceDiscoveryStopAdvertising(QString serviceId) {
    serviceId = serviceId.trimmed();
    if (!ensureRunning(QStringLiteral("stop advertising a service"))) {
        return;
    }
    if (serviceId.isEmpty()) {
        reportError(QStringLiteral("A service ID is required to stop advertising."));
        return;
    }
    if (!ensureServiceDiscoveryStarted()) {
        return;
    }
    LogosResult result = m_logos->libp2p_module.discoStopAdvertising(serviceId);
    if (!result.success) {
        reportError(QStringLiteral("Failed to stop advertising service '%1': %2").arg(serviceId, result.getError()));
        return;
    }
    QVariantList services = advertisedServices();
    for (int index = services.size() - 1; index >= 0; --index) {
        if (services.at(index).toMap().value("serviceId").toString() == serviceId)
            services.removeAt(index);
    }
    setAdvertisedServices(services);
    refreshMetrics();
    emit serviceStoppedAdvertising(serviceId);
}

void Libp2pBackend::serviceDiscoveryLookup(QString serviceId, QString serviceData) {
    serviceId = serviceId.trimmed();
    if (!ensureRunning(QStringLiteral("look up a service"))) {
        return;
    }
    if (serviceId.isEmpty()) {
        reportError(QStringLiteral("A service ID is required for service discovery lookup."));
        return;
    }
    if (!ensureServiceDiscoveryStarted()) {
        return;
    }
    LogosResult result = m_logos->libp2p_module.discoLookup(serviceId, serviceData);
    if (!result.success) {
        reportError(QStringLiteral("Service lookup failed for '%1': %2").arg(serviceId, result.getError()));
        return;
    }

    QVariantList records;
    for (const QVariant& item : result.getList()) {
        QVariantMap record = item.toMap();
        QVariantList services;
        for (const QVariant& serviceItem : record.value("services").toList()) {
            QVariantMap service = serviceItem.toMap();
            service["data"] = QString::fromUtf8(QByteArray::fromBase64(service.value("data").toString().toUtf8()));
            services.append(service);
        }
        record["services"] = services;
        records.append(record);
    }
    setDiscoveryResults(records);
    refreshMetrics();
    emit serviceLookupCompleted(serviceId);
}

void Libp2pBackend::applyNodeConfig(QVariantMap config) {
    QJsonDocument normalized;
    QString error;
    if (!canonicalizeConfig(config, &normalized, &error)) {
        reportError(QStringLiteral("Invalid node configuration: %1").arg(error));
        return;
    }
    if (!initializeConfig(normalized, true, &error)) {
        reportError(error);
        return;
    }
    emit nodeConfigApplied();
}

void Libp2pBackend::restoreDefaultNodeConfig() {
    QString error;
    if (!initializeConfig(defaultConfig(), true, &error)) {
        reportError(error);
        return;
    }
    emit nodeConfigRestored();
}

void Libp2pBackend::setMetricsRefreshInterval(int intervalMs) {
    if (!isAllowedMetricsRefreshInterval(intervalMs)) {
        reportError(QStringLiteral("Metrics refresh interval must be Off, 5, 10, or 30 seconds."));
        return;
    }
    if (metricsRefreshIntervalMs() == intervalMs) {
        return;
    }
    setMetricsRefreshIntervalMs(intervalMs);
    updateMetricsTimer();
    m_settings.setValue(kMetricsIntervalSettingsKey, intervalMs);
    m_settings.sync();
    emit metricsRefreshIntervalChanged(intervalMs);
}

void Libp2pBackend::updateMetricsTimer() {
    if (!m_metricsTimer)
        return;
    if (status() == Running && metricsRefreshIntervalMs() > 0) {
        m_metricsTimer->setInterval(metricsRefreshIntervalMs());
        m_metricsTimer->start();
    } else {
        m_metricsTimer->stop();
    }
}

void Libp2pBackend::resetMetricHistory() {
    m_metricHistory.clear();
    m_previousCounters.clear();
    m_sessionBaselines.clear();
    m_previousMetricsTimestampMs = 0;
    m_peakReceiveRate = 0;
    m_peakSendRate = 0;
}

void Libp2pBackend::clearRuntimeInfo() {
    updateMetricsTimer();
    resetMetricHistory();
    setPeerId(QString());
    setListenAddress(QString());
    setConnectedPeers(0);
    setActiveStreams(0);
    setGossipsubTopics(0);
    setSubscribedTopics(QVariantList{});
    setDhtRecords(0);
    setRelayReservations(0);
    setInboundPeers(QVariantList{});
    setOutboundPeers(QVariantList{});
    setKnownPeers(0);
    setMetrics(QVariantMap{});
    setLastPingResult(QVariantMap{});
    setDhtLookupResults(QVariantList{});
    setAdvertisedServices(QVariantList{});
    setDiscoveryResults(QVariantList{});
    m_serviceDiscoveryStarted = false;
}

void Libp2pBackend::refreshOverview() {
    if (status() != Running) {
        setConnectedPeers(0);
        return;
    }

    LogosResult peerResult = m_logos->libp2p_module.getNodeInfo(QStringLiteral("PeerId"));
    if (peerResult.success) {
        setPeerId(peerResult.getString());
    } else {
        qWarning() << "Libp2pBackend: failed to read peer id:" << peerResult.getError();
    }

    setListenAddress(firstListenAddress());
    refreshPeers();
    refreshMetrics();

    QVariantMap overview;
    overview["peerId"] = peerId();
    overview["listenAddress"] = listenAddress();
    overview["connectedPeers"] = connectedPeers();
    overview["activeStreams"] = activeStreams();
    overview["gossipsubTopics"] = gossipsubTopics();
    overview["dhtRecords"] = dhtRecords();
    overview["relayReservations"] = relayReservations();
    emit overviewUpdated(overview);
}

void Libp2pBackend::logDebugInfo() {
    qDebug() << "Libp2pBackend status:" << status();
    qDebug() << "Libp2pBackend peerId:" << peerId();
    qDebug() << "Libp2pBackend listenAddress:" << listenAddress();

    LogosResult version = m_logos->libp2p_module.getNodeInfo(QStringLiteral("Version"));
    if (version.success) {
        qDebug() << "Libp2p module version:" << version.getString();
    } else {
        qWarning() << "Libp2pBackend: failed to read module version:" << version.getError();
    }
}

#include "Libp2pBackend.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>

#ifndef LIBP2P_UI_VERSION
#define LIBP2P_UI_VERSION "unknown"
#endif

namespace {
constexpr int kInboundDirection = 0;
constexpr int kOutboundDirection = 1;
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

    m_config = defaultConfig();

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
    return QJsonDocument(obj);
}

QString Libp2pBackend::defaultConfigJson() {
    return QString::fromUtf8(defaultConfig().toJson(QJsonDocument::Indented));
}

void Libp2pBackend::init(QString configJson) {
    if (status() == Running || status() == Starting || status() == Stopping) {
        const QString message = QStringLiteral("Cannot initialize libp2p while the node is active.");
        reportError(message);
        emit initCompleted(false, message);
        return;
    }

    QJsonParseError parseError;
    QJsonDocument config = QJsonDocument::fromJson(configJson.toUtf8(), &parseError);
    if (!config.isObject()) {
        const QString message = QStringLiteral("Invalid libp2p configuration: %1").arg(parseError.errorString());
        reportError(message);
        emit initCompleted(false, message);
        return;
    }

    if (m_initialized && config == m_config) {
        emit initCompleted(true, QString());
        return;
    }

    if (m_initialized) {
        const QString message =
            QStringLiteral("libp2p node is already initialized. Restart the UI to apply a different config.");
        reportError(message);
        emit initCompleted(false, message);
        return;
    }

    const QString compactConfig = QString::fromUtf8(config.toJson(QJsonDocument::Compact));
    LogosResult result = m_logos->libp2p_module.createNode(compactConfig);
    if (!result.success) {
        const QString message = QStringLiteral("Failed to initialize libp2p node: %1").arg(result.getError());
        reportError(message);
        emit initCompleted(false, message);
        return;
    }

    m_config = config;
    m_initialized = true;
    setStatus(Stopped);
    clearRuntimeInfo();
    emit initCompleted(true, QString());
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

    init(defaultConfigJson());
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
    LogosResult result = m_logos->libp2p_module.start();
    if (!result.success) {
        setStatus(Stopped);
        const QString message = QStringLiteral("Failed to start libp2p node: %1").arg(result.getError());
        reportError(message);
        emit startFailed(message);
        return;
    }

    setStatus(Running);
    refreshOverview();
    emit startCompleted();
}

void Libp2pBackend::stop() {
    if (status() == Stopping) {
        return;
    }

    if (status() != Running && status() != Starting) {
        setStatus(Stopped);
        clearRuntimeInfo();
        emit stopCompleted();
        return;
    }

    setStatus(Stopping);
    LogosResult result = m_logos->libp2p_module.stop();
    if (!result.success) {
        setStatus(Running);
        reportError(QStringLiteral("Failed to stop libp2p node: %1").arg(result.getError()));
        return;
    }

    setStatus(Stopped);
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
}

void Libp2pBackend::clearRuntimeInfo() {
    setPeerId(QString());
    setListenAddress(QString());
    setConnectedPeers(0);
    setActiveStreams(0);
    setGossipsubTopics(0);
    setSubscribedTopics(QVariantList{});
    setDhtRecords(0);
    setRelayReservations(0);
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
    setConnectedPeers(connectedPeerCount());

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

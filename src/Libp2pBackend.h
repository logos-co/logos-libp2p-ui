#pragma once

#include "logos_api.h"
#include "logos_sdk.h"
#include "rep_Libp2pBackend_source.h"

#include <QJsonDocument>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class Libp2pBackend : public Libp2pBackendSimpleSource {
    Q_OBJECT

  public:
    explicit Libp2pBackend(LogosAPI* logosAPI = nullptr, QObject* parent = nullptr);
    ~Libp2pBackend() override;

  public slots:
    void init(QString configJson) override;
    void start() override;
    void stop() override;
    void refreshOverview() override;
    void gossipsubSubscribe(QString topic) override;
    void gossipsubUnsubscribe(QString topic) override;
    void gossipsubPublish(QString topic, QString message) override;
    void refreshPeers() override;
    void connectPeer(QString peerId, QString multiaddr) override;
    void disconnectPeer(QString peerId) override;
    void refreshMetrics() override;
    void pingPeer(QString peerId) override;
    void dhtFindPeer(QString peerId) override;
    void serviceDiscoveryAdvertise(QString serviceId, QString serviceData) override;
    void serviceDiscoveryStopAdvertising(QString serviceId) override;
    void serviceDiscoveryLookup(QString serviceId, QString serviceData) override;
    QString defaultConfigJson() override;
    void logDebugInfo() override;

  private:
    static QJsonDocument defaultConfig();

    void reportError(const QString& message);
    bool ensureInitialized();
    QString firstListenAddress() const;
    int connectedPeerCount() const;
    bool ensureRunning(const QString& operation);
    bool ensureServiceDiscoveryStarted();
    void clearRuntimeInfo();

    LogosAPI* m_logosAPI = nullptr;
    LogosModules* m_logos = nullptr;
    QJsonDocument m_config;
    bool m_initialized = false;
    bool m_serviceDiscoveryStarted = false;
};

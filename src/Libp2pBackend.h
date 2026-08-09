#pragma once

#include "logos_api.h"
#include "logos_sdk.h"
#include "rep_Libp2pBackend_source.h"

#include <QJsonDocument>
#include <QObject>
#include <QString>
#include <QVariantList>

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
    QString defaultConfigJson() override;
    void logDebugInfo() override;

  private:
    static QJsonDocument defaultConfig();

    void reportError(const QString& message);
    bool ensureInitialized();
    QString firstListenAddress() const;
    int connectedPeerCount() const;
    bool ensureRunning(const QString& operation);
    void clearRuntimeInfo();

    LogosAPI* m_logosAPI = nullptr;
    LogosModules* m_logos = nullptr;
    QJsonDocument m_config;
    bool m_initialized = false;
};

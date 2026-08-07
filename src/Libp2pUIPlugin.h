#ifndef LIBP2P_UI_PLUGIN_H
#define LIBP2P_UI_PLUGIN_H

#include "Libp2pInterface.h"
#include "LogosViewPluginBase.h"

#include <QObject>
#include <QString>
#include <QtPlugin>

class LogosAPI;
class Libp2pBackend;

class Libp2pUIPlugin : public QObject, public Libp2pInterface, public Libp2pBackendViewPluginBase {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID Libp2pInterface_iid FILE "../metadata.json")
    Q_INTERFACES(Libp2pInterface)

  public:
    explicit Libp2pUIPlugin(QObject* parent = nullptr);
    ~Libp2pUIPlugin() override;

    QString name() const override { return "libp2p_ui"; }
    QString version() const override;

    Q_INVOKABLE void initLogos(LogosAPI* api);

  private:
    Libp2pBackend* m_backend = nullptr;
};

#endif

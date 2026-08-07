#include "Libp2pUIPlugin.h"
#include "Libp2pBackend.h"

#include <QDebug>

using NodeStatus = Libp2pBackendSimpleSource::NodeStatus;

#ifndef LIBP2P_UI_VERSION
#error "LIBP2P_UI_VERSION must be defined from metadata.json"
#endif

Libp2pUIPlugin::Libp2pUIPlugin(QObject* parent) : QObject(parent) {}

Libp2pUIPlugin::~Libp2pUIPlugin() {
    Libp2pBackend* backend = m_backend;
    if (!backend) {
        return;
    }

    if (backend->status() == NodeStatus::Running || backend->status() == NodeStatus::Starting) {
        qDebug() << "Libp2pUIPlugin: stopping backend during teardown";
        backend->stop();
    }
}

QString Libp2pUIPlugin::version() const {
    return LIBP2P_UI_VERSION;
}

void Libp2pUIPlugin::initLogos(LogosAPI* api) {
    if (m_backend) {
        return;
    }

    m_backend = new Libp2pBackend(api, this);
    setBackend(m_backend);
    qDebug() << "Libp2pUIPlugin: backend initialized";
}

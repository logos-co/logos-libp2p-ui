#ifndef LIBP2P_INTERFACE_H
#define LIBP2P_INTERFACE_H

#include "interface.h"
#include <QtPlugin>

class Libp2pInterface : public PluginInterface {
  public:
    virtual ~Libp2pInterface() = default;
};

#define Libp2pInterface_iid "org.logos.Libp2pInterface"
Q_DECLARE_INTERFACE(Libp2pInterface, Libp2pInterface_iid)

#endif

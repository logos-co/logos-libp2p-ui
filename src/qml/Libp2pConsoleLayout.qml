import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    color: Theme.palette.background
    implicitWidth: 1200
    implicitHeight: 800

    property var backend: MockBackend
    property int selectedIndex: 0

    readonly property var screens: [
        { "title": "Overview", "icon": "assets/overview.svg" },
        { "title": "Peers", "icon": "assets/peers.svg" },
        { "title": "Traffic", "icon": "assets/network.svg" },
        { "title": "Streams", "icon": "assets/streams.svg" },
        { "title": "Gossipsub", "icon": "assets/gossipsub.svg" },
        { "title": "DHT", "icon": "assets/dht.svg" },
        { "title": "Service Discovery", "icon": "assets/discovery.svg" },
        { "title": "Connectivity", "icon": "assets/relay.svg" },
        { "title": "Settings", "icon": "assets/settings.svg" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sidebar

            Layout.preferredWidth: 286
            Layout.fillHeight: true
            color: Theme.palette.backgroundSecondary

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.large
                spacing: Theme.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacing.large
                    spacing: Theme.spacing.small

                    Image {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        source: Qt.resolvedUrl("assets/network.svg")
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                    }

                    LogosText {
                        Layout.fillWidth: true
                        text: "Logos Network Console"
                        font.pixelSize: Theme.typography.primaryText
                        font.weight: Font.DemiBold
                        color: Theme.palette.text
                        wrapMode: Text.Wrap
                    }
                }

                Repeater {
                    model: root.screens

                    SidebarItem {
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        title: modelData.title
                        iconSource: modelData.icon
                        selected: root.selectedIndex === index
                        onClicked: root.selectedIndex = index
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.palette.borderSecondary
                }

                LogosText {
                    Layout.fillWidth: true
                    text: "UI version " + (root.backend ? root.backend.uiVersion : "unknown")
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textTertiary
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.palette.borderSecondary
        }

        Item {
            id: content

            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                anchors.fill: parent
                sourceComponent: {
                    if (root.selectedIndex === 0)
                        return overviewComponent
                    if (root.selectedIndex === 4)
                        return gossipsubComponent
                    if (root.selectedIndex === 1)
                        return peersComponent
                    if (root.selectedIndex === 2)
                        return trafficComponent
                    if (root.selectedIndex === 3)
                        return streamsComponent
                    if (root.selectedIndex === 5)
                        return dhtComponent
                    if (root.selectedIndex === 6)
                        return serviceDiscoveryComponent
                    if (root.selectedIndex === 7)
                        return connectivityComponent
                    return settingsComponent
                }
            }
        }
    }

    Component {
        id: overviewComponent

        OverviewScreen {
            backend: root.backend
        }
    }

    Component { id: peersComponent; PeersScreen { backend: root.backend } }

    Component { id: trafficComponent; TrafficScreen { backend: root.backend } }

    Component { id: streamsComponent; StreamsScreen { backend: root.backend } }

    Component {
        id: gossipsubComponent

        GossipsubScreen {
            backend: root.backend
        }
    }

    Component { id: dhtComponent; DhtScreen { backend: root.backend } }

    Component { id: serviceDiscoveryComponent; ServiceDiscoveryScreen { backend: root.backend } }

    Component { id: connectivityComponent; ConnectivityScreen { backend: root.backend } }

    Component { id: settingsComponent; SettingsScreen { backend: root.backend } }
}

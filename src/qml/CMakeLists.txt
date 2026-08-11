cmake_minimum_required(VERSION 3.16)

project(qml VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appqml
    main.cpp
)

target_link_libraries(appqml PRIVATE
    Qt6::Quick
    Qt6::Qml
)

set_source_files_properties(MockBackend.qml PROPERTIES QML_SINGLETON TRUE)

qt_add_qml_module(appqml
    URI Libp2pBackend
    VERSION 1.0
    QML_FILES
        Main.qml
        Preview.qml
        Libp2pConsoleLayout.qml
        SidebarItem.qml
        OverviewScreen.qml
        PeersScreen.qml
        TrafficScreen.qml
        MetricLineChart.qml
        StreamsScreen.qml
        GossipsubScreen.qml
        DhtScreen.qml
        ServiceDiscoveryScreen.qml
        ConnectivityScreen.qml
        SettingsScreen.qml
        CopyField.qml
        StatCard.qml
        PlaceholderScreen.qml
        ErrorToast.qml
        MockBackend.qml

    RESOURCES
        assets/network.svg
        assets/overview.svg
        assets/peers.svg
        assets/streams.svg
        assets/gossipsub.svg
        assets/dht.svg
        assets/discovery.svg
        assets/settings.svg
        assets/relay.svg
        assets/run.svg
        assets/stop.svg
)

if(DEFINED ENV{LOGOS_DESIGN_SYSTEM_ROOT})
    set(LOGOS_DESIGN_SYSTEM_ROOT "$ENV{LOGOS_DESIGN_SYSTEM_ROOT}")
endif()

set(LOGOS_DESIGN_SYSTEM_QML_ROOT "")
foreach(_candidate
        "${LOGOS_DESIGN_SYSTEM_ROOT}/lib"
        "${LOGOS_DESIGN_SYSTEM_ROOT}/src/qml"
        "${LOGOS_DESIGN_SYSTEM_ROOT}/lib/qml")
    if(EXISTS "${_candidate}/Logos/Theme/qmldir")
        set(LOGOS_DESIGN_SYSTEM_QML_ROOT "${_candidate}")
        break()
    endif()
endforeach()

if(NOT LOGOS_DESIGN_SYSTEM_QML_ROOT)
    find_path(LOGOS_DESIGN_SYSTEM_QML_ROOT
        NAMES Logos/Theme/qmldir
        PATH_SUFFIXES lib src/qml lib/qml qml
    )
endif()

if(NOT LOGOS_DESIGN_SYSTEM_QML_ROOT)
    file(GLOB _design_qml_candidates
        "/nix/store/*logos-design-system-src/src/qml"
        "/nix/store/*-source/src/qml")
    foreach(_candidate ${_design_qml_candidates})
        if(EXISTS "${_candidate}/Logos/Theme/qmldir"
                AND EXISTS "${_candidate}/Logos/Controls/qmldir"
                AND EXISTS "${_candidate}/Logos/Icons/qmldir")
            set(LOGOS_DESIGN_SYSTEM_QML_ROOT "${_candidate}")
            break()
        endif()
    endforeach()
endif()

if(NOT LOGOS_DESIGN_SYSTEM_QML_ROOT)
    message(FATAL_ERROR "Logos design-system QML modules not found. Set LOGOS_DESIGN_SYSTEM_ROOT.")
endif()

set(QML_THEME_DIR ${CMAKE_CURRENT_BINARY_DIR}/qml/Logos/Theme)
set(QML_CONTROLS_DIR ${CMAKE_CURRENT_BINARY_DIR}/qml/Logos/Controls)
set(QML_ICONS_DIR ${CMAKE_CURRENT_BINARY_DIR}/qml/Logos/Icons)

add_custom_command(TARGET appqml POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${QML_THEME_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${LOGOS_DESIGN_SYSTEM_QML_ROOT}/Logos/Theme/ ${QML_THEME_DIR}/
    COMMAND ${CMAKE_COMMAND} -E make_directory ${QML_CONTROLS_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${LOGOS_DESIGN_SYSTEM_QML_ROOT}/Logos/Controls/ ${QML_CONTROLS_DIR}/
    COMMAND ${CMAKE_COMMAND} -E make_directory ${QML_ICONS_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${LOGOS_DESIGN_SYSTEM_QML_ROOT}/Logos/Icons/ ${QML_ICONS_DIR}/
    COMMENT "Setting up Logos QML modules for the app"
)

message(STATUS "Qt Quick libp2p UI preview configured successfully")

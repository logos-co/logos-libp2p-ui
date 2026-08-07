cmake_minimum_required(VERSION 3.14)
project(Libp2pUiPlugin LANGUAGES CXX)

if(DEFINED ENV{LOGOS_MODULE_BUILDER_ROOT})
    include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)
else()
    message(FATAL_ERROR "LogosModule.cmake not found. Set LOGOS_MODULE_BUILDER_ROOT.")
endif()

logos_module(
    NAME libp2p_ui
    REP_FILE src/Libp2pBackend.rep
    SOURCES
        src/Libp2pInterface.h
        src/Libp2pUIPlugin.h
        src/Libp2pUIPlugin.cpp
        src/Libp2pBackend.h
        src/Libp2pBackend.cpp
)

# Expose the UI version from metadata.json to Libp2pBackend at compile time.
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json" _ui_metadata)
string(REGEX MATCH "\"version\"[ \t]*:[ \t]*\"([^\"]+)\"" _ "${_ui_metadata}")
if(NOT CMAKE_MATCH_1)
    message(FATAL_ERROR "metadata.json must contain a string version field")
endif()
target_compile_definitions(libp2p_ui_module_plugin PRIVATE LIBP2P_UI_VERSION="${CMAKE_MATCH_1}")

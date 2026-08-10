# SPDX-FileCopyrightText: 2026 Yannic Kauffmann
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.16)

project(ttop-desk VERSION 0.1.12 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 5.90 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(KF5Plasma 5.90 REQUIRED)
find_package(Qt5 5.15 REQUIRED COMPONENTS Core Network Qml)

add_library(ttopbackendplugin MODULE
    native/backendplugin.cpp
    native/localsocketclient.cpp
    native/localsocketclient.h
)
target_link_libraries(ttopbackendplugin PRIVATE Qt5::Core Qt5::Network Qt5::Qml)
set_target_properties(ttopbackendplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/package/contents/ui/TTop/Backend"
)

plasma_install_package(package io.github.s3cb34r.ttopdesk)

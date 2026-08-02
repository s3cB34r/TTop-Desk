# SPDX-FileCopyrightText: 2026 Yannic Kauffmann
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.16)

project(ttop-desk VERSION 0.1.0 LANGUAGES NONE)

find_package(ECM 5.90 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(KF5Plasma 5.90 REQUIRED)

plasma_install_package(package io.github.s3cb34r.ttopdesk)

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    // Set to true while developing to log system-monitor sensor discovery.
    property bool debugMetrics: false

    readonly property bool showCpu: Plasmoid.configuration.showCpu
    readonly property bool showMemory: Plasmoid.configuration.showMemory
    readonly property bool showNetwork: Plasmoid.configuration.showNetwork
    readonly property bool showTemperature: Plasmoid.configuration.showTemperature
    readonly property bool showFilesystems: Plasmoid.configuration.showFilesystems
    readonly property bool showDiskIo: Plasmoid.configuration.showDiskIo
    readonly property bool showHeader: Plasmoid.configuration.showHeader
    readonly property bool showMetricIcons: Plasmoid.configuration.showMetricIcons
    readonly property bool compactModeDetails: Plasmoid.configuration.compactModeDetails

    readonly property int safeRefreshIntervalMs:
        validRefreshInterval(Plasmoid.configuration.refreshIntervalMs)
    readonly property int safeFilesystemRefreshIntervalMs:
        clampInteger(Plasmoid.configuration.filesystemRefreshIntervalMs, 5000, 60000, 15000)
    readonly property int safeMaximumFilesystemEntries:
        clampInteger(Plasmoid.configuration.maximumFilesystemEntries, 1, 10, 3)

    function validRefreshInterval(value) {
        var number = Number(value);
        var supported = [500, 1000, 2000, 5000];
        return supported.indexOf(number) !== -1 ? number : 1000;
    }

    function clampInteger(value, minimum, maximum, fallback) {
        var number = Number(value);
        if (!isFinite(number) || number <= 0) {
            return fallback;
        }
        return Math.max(minimum, Math.min(maximum, Math.round(number)));
    }

    // Keep undersized desktop containers in the compact view until the full
    // card has enough room for its default set of sections.
    Plasmoid.switchWidth: PlasmaCore.Units.gridUnit * 14
    Plasmoid.switchHeight: PlasmaCore.Units.gridUnit * 17
    Plasmoid.compactRepresentation: compactRepresentation
    Plasmoid.fullRepresentation: fullRepresentation

    MetricsProvider {
        id: metrics

        debugMetrics: root.debugMetrics
        refreshIntervalMs: root.safeRefreshIntervalMs
        filesystemRefreshIntervalMs: root.safeFilesystemRefreshIntervalMs
        maximumFilesystemEntries: root.safeMaximumFilesystemEntries
    }

    Component {
        id: compactRepresentation

        CompactRepresentation {
            metricsProvider: metrics
            showCpu: root.showCpu
            showMemory: root.showMemory
            showNetwork: root.showNetwork
            showTemperature: root.showTemperature
            showMetricIcons: root.showMetricIcons
            compactModeDetails: root.compactModeDetails
            formFactor: Plasmoid.formFactor
        }
    }

    Component {
        id: fullRepresentation

        FullRepresentation {
            metricsProvider: metrics
            showCpu: root.showCpu
            showMemory: root.showMemory
            showNetwork: root.showNetwork
            showTemperature: root.showTemperature
            showFilesystems: root.showFilesystems
            showDiskIo: root.showDiskIo
            showHeader: root.showHeader
            showMetricIcons: root.showMetricIcons
        }
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import "ConfigurationUtils.js" as Configuration

Item {
    id: root

    // Set to true while developing to log system-monitor sensor discovery.
    property bool debugMetrics: false
    property bool debugBackend: false

    readonly property string widgetTitle:
        Configuration.title(Plasmoid.configuration.widgetTitle)
    readonly property bool showCpu: Plasmoid.configuration.showCpu
    readonly property bool showMemory: Plasmoid.configuration.showMemory
    readonly property bool showNetwork: Plasmoid.configuration.showNetwork
    readonly property bool showTemperature: Plasmoid.configuration.showTemperature
    readonly property bool showFilesystems: Plasmoid.configuration.showFilesystems
    readonly property bool showDiskIo: Plasmoid.configuration.showDiskIo
    readonly property bool showProcesses: Plasmoid.configuration.showProcesses
    readonly property bool showGpu: Plasmoid.configuration.showGpu
    readonly property bool showHeader: Plasmoid.configuration.showHeader
    readonly property bool showMetricIcons: Plasmoid.configuration.showMetricIcons
    readonly property bool showSectionLabels: Plasmoid.configuration.showSectionLabels
    readonly property bool showCpuProgressBar: Plasmoid.configuration.showCpuProgressBar
    readonly property bool showMemoryProgressBar: Plasmoid.configuration.showMemoryProgressBar
    readonly property bool showFilesystemProgressBars:
        Plasmoid.configuration.showFilesystemProgressBars
    readonly property bool showProcessCpu: Plasmoid.configuration.showProcessCpu
    readonly property bool showProcessMemory: Plasmoid.configuration.showProcessMemory
    readonly property bool showGpuUtilization: Plasmoid.configuration.showGpuUtilization
    readonly property bool showGpuMemory: Plasmoid.configuration.showGpuMemory
    readonly property bool showGpuTemperature: Plasmoid.configuration.showGpuTemperature
    readonly property bool showGpuProgressBars: Plasmoid.configuration.showGpuProgressBars
    readonly property bool showNetworkRx: Plasmoid.configuration.showNetworkRx
    readonly property bool showNetworkTx: Plasmoid.configuration.showNetworkTx
    readonly property bool showDiskRead: Plasmoid.configuration.showDiskRead
    readonly property bool showDiskWrite: Plasmoid.configuration.showDiskWrite
    readonly property bool compactSpacing: Plasmoid.configuration.compactSpacing
    readonly property bool denseMode: Plasmoid.configuration.denseMode
    readonly property bool compactModeDetails: Plasmoid.configuration.compactModeDetails
    readonly property bool usePlasmaThemeBackground:
        Plasmoid.configuration.usePlasmaThemeBackground
    readonly property real safeBackgroundOpacity:
        Configuration.opacity(Plasmoid.configuration.backgroundOpacity)
    readonly property string safeCustomBackgroundColor:
        Configuration.color(Plasmoid.configuration.customBackgroundColor,
                            Configuration.DEFAULT_BACKGROUND_COLOR)

    readonly property int safeRefreshIntervalMs:
        validRefreshInterval(Plasmoid.configuration.refreshIntervalMs)
    readonly property int safeFilesystemRefreshIntervalMs:
        Configuration.allowedInteger(Plasmoid.configuration.filesystemRefreshIntervalMs,
                                     [5000, 10000, 15000, 30000, 60000], 15000)
    readonly property int safeMaximumFilesystemEntries:
        Configuration.allowedInteger(Plasmoid.configuration.maximumFilesystemEntries,
                                     [1, 2, 3, 4, 5], 3)
    readonly property int safeMaximumProcessEntries:
        Configuration.allowedInteger(Plasmoid.configuration.maximumProcessEntries,
                                     [3, 4, 5], 5)
    readonly property int safeProcessRefreshIntervalMs:
        Configuration.allowedInteger(Plasmoid.configuration.processRefreshIntervalMs,
                                     [1000, 2000, 5000], 2000)
    readonly property string safeProcessSortMode:
        Configuration.processSort(Plasmoid.configuration.processSortMode)
    readonly property int safeGpuRefreshIntervalMs:
        Configuration.allowedInteger(Plasmoid.configuration.gpuRefreshIntervalMs,
                                     [500, 1000, 2000, 5000], 1000)

    function validRefreshInterval(value) {
        return Configuration.allowedInteger(value, [500, 1000, 2000, 5000], 1000);
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

    BackendProvider {
        id: backend

        enabled: root.showProcesses || root.showGpu
        processesEnabled: root.showProcesses
        gpuEnabled: root.showGpu
        debugBackend: root.debugBackend
        refreshIntervalMs: root.safeProcessRefreshIntervalMs
        maximumProcessEntries: root.safeMaximumProcessEntries
        processSortMode: root.safeProcessSortMode
        gpuRefreshIntervalMs: root.safeGpuRefreshIntervalMs
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
            backendProvider: backend
            showGpu: root.showGpu
            widgetTitle: root.widgetTitle
            formFactor: Plasmoid.formFactor
        }
    }

    Component {
        id: fullRepresentation

        FullRepresentation {
            metricsProvider: metrics
            backendProvider: backend
            showCpu: root.showCpu
            showMemory: root.showMemory
            showNetwork: root.showNetwork
            showTemperature: root.showTemperature
            showFilesystems: root.showFilesystems
            showDiskIo: root.showDiskIo
            showProcesses: root.showProcesses
            showGpu: root.showGpu
            showHeader: root.showHeader
            showMetricIcons: root.showMetricIcons
            showSectionLabels: root.showSectionLabels
            showCpuProgressBar: root.showCpuProgressBar
            showMemoryProgressBar: root.showMemoryProgressBar
            showFilesystemProgressBars: root.showFilesystemProgressBars
            showProcessCpu: root.showProcessCpu
            showProcessMemory: root.showProcessMemory
            showGpuUtilization: root.showGpuUtilization
            showGpuMemory: root.showGpuMemory
            showGpuTemperature: root.showGpuTemperature
            showGpuProgressBars: root.showGpuProgressBars
            showNetworkRx: root.showNetworkRx
            showNetworkTx: root.showNetworkTx
            showDiskRead: root.showDiskRead
            showDiskWrite: root.showDiskWrite
            compactSpacing: root.compactSpacing
            denseMode: root.denseMode
            widgetTitle: root.widgetTitle
            backgroundOpacity: root.safeBackgroundOpacity
            usePlasmaThemeBackground: root.usePlasmaThemeBackground
            customBackgroundColor: root.safeCustomBackgroundColor
        }
    }
}

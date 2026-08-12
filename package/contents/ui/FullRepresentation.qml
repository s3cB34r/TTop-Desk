/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import "components" as Components

Rectangle {
    id: fullView
    objectName: "fullRepresentation"

    property var metricsProvider
    property var backendProvider
    property bool showCpu: true
    property bool showMemory: true
    property bool showNetwork: true
    property bool showTemperature: true
    property bool showFilesystems: true
    property bool showDiskIo: true
    property bool showProcesses: true
    property bool showGpu: true
    property bool showHeader: true
    property bool showMetricIcons: true
    property bool showSectionLabels: true
    property bool showCpuProgressBar: true
    property bool showMemoryProgressBar: true
    property bool showFilesystemProgressBars: true
    property bool showProcessCpu: true
    property bool showProcessMemory: true
    property bool showGpuUtilization: true
    property bool showGpuMemory: true
    property bool showGpuTemperature: true
    property bool showGpuProgressBars: true
    property bool showGraphs: true
    property bool showCpuGraph: true
    property bool showMemoryGraph: true
    property bool showGpuGraph: true
    property bool showNetworkGraph: true
    property int historySampleCount: 60
    property bool showNetworkRx: true
    property bool showNetworkTx: true
    property bool showDiskRead: true
    property bool showDiskWrite: true
    property bool compactSpacing: false
    property bool denseMode: false
    property string widgetTitle: "TTop Desk"
    property real backgroundOpacity: 1.0
    property bool usePlasmaThemeBackground: true
    property color customBackgroundColor: "#20252b"

    readonly property int contentMargin: PlasmaCore.Units.largeSpacing
    readonly property int sectionSpacing: denseMode ? 0
                                         : compactSpacing
                                           ? Math.max(1, Math.round(PlasmaCore.Units.smallSpacing / 2))
                                           : PlasmaCore.Units.smallSpacing
    readonly property int minimumCardWidth: PlasmaCore.Units.gridUnit * 12
    readonly property int preferredCardWidth: PlasmaCore.Units.gridUnit * 17
    readonly property color baseBackgroundColor: usePlasmaThemeBackground
                                                 ? PlasmaCore.Theme.backgroundColor
                                                 : customBackgroundColor

    implicitWidth: preferredCardWidth
    implicitHeight: content.implicitHeight + contentMargin * 2

    Layout.minimumWidth: minimumCardWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    color: Qt.rgba(baseBackgroundColor.r, baseBackgroundColor.g,
                   baseBackgroundColor.b, Math.max(0.35, Math.min(1, backgroundOpacity)))
    radius: PlasmaCore.Units.smallSpacing
    border.color: Qt.rgba(PlasmaCore.Theme.highlightColor.r,
                          PlasmaCore.Theme.highlightColor.g,
                          PlasmaCore.Theme.highlightColor.b, 0.35)
    border.width: 1

    MetricHistory {
        id: metricHistory
        metricsProvider: fullView.metricsProvider
        backendProvider: fullView.backendProvider
        maximumSamples: fullView.historySampleCount
        cpuEnabled: fullView.showGraphs && fullView.showCpu && fullView.showCpuGraph
        memoryEnabled: fullView.showGraphs && fullView.showMemory && fullView.showMemoryGraph
        gpuEnabled: fullView.showGraphs && fullView.showGpu && fullView.showGpuGraph
        networkEnabled: fullView.showGraphs && fullView.showNetwork
                        && fullView.showNetworkGraph
        networkRxEnabled: fullView.showNetworkRx
        networkTxEnabled: fullView.showNetworkTx
    }

    ColumnLayout {
        id: content
        objectName: "fullContent"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: fullView.contentMargin
        spacing: fullView.sectionSpacing

        RowLayout {
            objectName: "headerSection"
            visible: fullView.showHeader
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaCore.IconItem {
                objectName: "headerIcon"
                visible: fullView.showMetricIcons
                source: "utilities-system-monitor"
                Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                Layout.preferredHeight: width
            }

            PlasmaComponents.Label {
                objectName: "widgetTitleLabel"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: fullView.widgetTitle
                color: PlasmaCore.Theme.textColor
                font.bold: true
                font.pointSize: PlasmaCore.Theme.defaultFont.pointSize + 2
                elide: Text.ElideRight
            }
        }

        Rectangle {
            objectName: "headerSeparator"
            visible: fullView.showHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: PlasmaCore.Theme.highlightColor
            opacity: 0.35
        }

        Components.MetricRow {
            objectName: "cpuSection"
            visible: fullView.showCpu
            Layout.fillWidth: true
            metricLabel: qsTr("CPU")
            iconName: "cpu"
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            showProgressBar: fullView.showCpuProgressBar
            showGraph: fullView.showGraphs && fullView.showCpuGraph
            graphValues: metricHistory.cpuValues
            valueText: fullView.metricsProvider.cpuAvailable
                       ? fullView.metricsProvider.cpuPercent.toFixed(1) + "%" : ""
            progressValue: fullView.metricsProvider.cpuPercent
            availabilityState: fullView.metricsProvider.cpuState
        }

        Components.MetricRow {
            objectName: "memorySection"
            visible: fullView.showMemory
            Layout.fillWidth: true
            metricLabel: qsTr("RAM")
            iconName: "memory"
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            showProgressBar: fullView.showMemoryProgressBar
            showGraph: fullView.showGraphs && fullView.showMemoryGraph
            graphValues: metricHistory.memoryValues
            valueText: fullView.metricsProvider.memoryDisplayText
            progressValue: fullView.metricsProvider.memoryPercent
            availabilityState: fullView.metricsProvider.memoryState
        }

        Components.TemperatureRow {
            objectName: "temperatureSection"
            visible: fullView.showTemperature
            Layout.fillWidth: true
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            valueText: fullView.metricsProvider.temperatureDisplayText
            availabilityState: fullView.metricsProvider.temperatureState
            severity: fullView.metricsProvider.temperatureSeverity
        }

        Components.GpuSection {
            objectName: "gpuSection"
            visible: fullView.showGpu
            Layout.fillWidth: true
            backendProvider: fullView.backendProvider
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            showUtilization: fullView.showGpuUtilization
            showMemory: fullView.showGpuMemory
            showTemperature: fullView.showGpuTemperature
            showProgressBars: fullView.showGpuProgressBars
            showGraph: fullView.showGraphs && fullView.showGpuGraph
            graphValues: metricHistory.gpuValues
            denseMode: fullView.denseMode
        }

        Components.NetworkRow {
            objectName: "networkSection"
            visible: fullView.showNetwork
            Layout.fillWidth: true
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            showRx: fullView.showNetworkRx
            showTx: fullView.showNetworkTx
            showGraph: fullView.showGraphs && fullView.showNetworkGraph
            rxHistory: metricHistory.networkRxValues
            txHistory: metricHistory.networkTxValues
            rxText: fullView.metricsProvider.networkRxDisplayText
            txText: fullView.metricsProvider.networkTxDisplayText
            availabilityState: fullView.metricsProvider.networkState
        }

        Components.DiskIoRow {
            objectName: "diskIoSection"
            visible: fullView.showDiskIo
            Layout.fillWidth: true
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            showRead: fullView.showDiskRead
            showWrite: fullView.showDiskWrite
            readText: fullView.metricsProvider.diskReadDisplayText
            writeText: fullView.metricsProvider.diskWriteDisplayText
            availabilityState: fullView.metricsProvider.diskIoState
        }

        ColumnLayout {
            objectName: "filesystemSection"
            visible: fullView.showFilesystems
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            Components.SectionHeader {
                Layout.fillWidth: true
                title: qsTr("FILESYSTEMS")
                iconName: "drive-harddisk"
                showIcon: fullView.showMetricIcons
                showLabel: fullView.showSectionLabels
                statusText: fullView.metricsProvider.filesystemAvailable
                            ? ""
                            : fullView.metricsProvider.filesystemState === "unavailable"
                              ? qsTr("Unavailable") : qsTr("Detecting…")
            }

            Repeater {
                model: fullView.metricsProvider.filesystemEntries

                delegate: Components.FilesystemRow {
                    Layout.fillWidth: true
                    mountPath: model.mountPath
                    capacityText: model.displayText
                    percent: model.percent
                    showProgressBar: fullView.showFilesystemProgressBars
                }
            }
        }

        Components.ProcessList {
            objectName: "processSection"
            visible: fullView.showProcesses
            Layout.fillWidth: true
            backendProvider: fullView.backendProvider
            showIcon: fullView.showMetricIcons
            showLabel: fullView.showSectionLabels
            showCpu: fullView.showProcessCpu
            showMemory: fullView.showProcessMemory
            denseMode: fullView.denseMode
        }
    }
}

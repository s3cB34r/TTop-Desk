/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import "TTop/Runtime"
import "components" as Components

Item {
    id: compactView

    property string languageMode: "en"
    property var metricsProvider
    property var backendProvider
    property var historyProvider: null
    property bool showCpu: true
    property bool showMemory: true
    property bool showNetwork: true
    property bool showTemperature: true
    property bool showGpu: true
    property bool showMetricIcons: true
    property bool compactModeDetails: false
    property bool showCompactGraphs: false
    property string compactGraphMetric: "cpu"
    property int historySampleCount: 60
    property int metricRefreshIntervalMs: 1000
    property int gpuRefreshIntervalMs: 1000
    property string widgetTitle: "TTop Desk"
    property int formFactor: PlasmaCore.Types.Planar

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    readonly property bool vertical: formFactor === PlasmaCore.Types.Vertical
    readonly property string effectiveCompactGraphMetric:
        ["cpu", "memory", "gpu", "network"].indexOf(compactGraphMetric) !== -1
        ? compactGraphMetric : "cpu"
    readonly property int visibleMetricCount:
        (showCpu ? 1 : 0) + (showMemory ? 1 : 0)
        + (compactModeDetails && showNetwork ? 1 : 0)
        + (compactModeDetails && showTemperature ? 1 : 0)
        + (compactModeDetails && showGpu ? 1 : 0)
    readonly property bool selectedGraphSectionEnabled:
        effectiveCompactGraphMetric === "cpu" ? showCpu
        : effectiveCompactGraphMetric === "memory" ? showMemory
        : effectiveCompactGraphMetric === "gpu" ? showGpu
        : effectiveCompactGraphMetric === "network" ? showNetwork : false
    readonly property bool selectedGraphAvailable:
        effectiveCompactGraphMetric === "cpu" ? metricsProvider.cpuState === "available"
        : effectiveCompactGraphMetric === "memory" ? metricsProvider.memoryState === "available"
        : effectiveCompactGraphMetric === "gpu" ? backendProvider !== null
                                         && backendProvider.gpuState === "available"
        : effectiveCompactGraphMetric === "network" ? metricsProvider.networkState === "available"
        : false
    readonly property var compactPrimaryValues:
        historyProvider === null ? []
        : effectiveCompactGraphMetric === "cpu" ? historyProvider.cpuValues
        : effectiveCompactGraphMetric === "memory" ? historyProvider.memoryValues
        : effectiveCompactGraphMetric === "gpu" ? historyProvider.gpuValues
        : historyProvider.networkRxValues
    readonly property var compactSecondaryValues:
        historyProvider !== null && effectiveCompactGraphMetric === "network"
        ? historyProvider.networkTxValues : []
    readonly property bool compactGraphVisible:
        showCompactGraphs && selectedGraphSectionEnabled && selectedGraphAvailable
        && (compactPrimaryValues.length > 0 || compactSecondaryValues.length > 0)
        && width >= PlasmaCore.Units.gridUnit * 4
        && height >= PlasmaCore.Units.gridUnit * 2
    readonly property int compactGraphHeight: 12
    readonly property string compactGraphName:
        effectiveCompactGraphMetric === "cpu" ? ttopTr("CPU history")
        : effectiveCompactGraphMetric === "memory" ? ttopTr("Memory usage history")
        : effectiveCompactGraphMetric === "gpu" ? ttopTr("GPU utilization history")
        : ttopTr("Network receive and transmit history")
    readonly property int compactGraphIntervalMs:
        effectiveCompactGraphMetric === "gpu" ? gpuRefreshIntervalMs
                                               : metricRefreshIntervalMs
    readonly property int compactGraphSeconds:
        Math.max(1, Math.round(historySampleCount * compactGraphIntervalMs / 1000))
    readonly property string compactGraphAccessibleName:
        effectiveCompactGraphMetric === "cpu"
        ? ttopTr("CPU history, approximately %1 seconds", [compactGraphSeconds])
        : effectiveCompactGraphMetric === "memory"
          ? ttopTr("Memory usage history, approximately %1 seconds", [compactGraphSeconds])
          : effectiveCompactGraphMetric === "gpu"
            ? ttopTr("GPU utilization history, approximately %1 seconds", [compactGraphSeconds])
            : ttopTr("Network receive and transmit history, approximately %1 seconds",
                     [compactGraphSeconds])

    Layout.preferredWidth: vertical
                           ? PlasmaCore.Units.gridUnit * 5
                           : PlasmaCore.Units.gridUnit * Math.max(6,
                               (showCpu ? 4 : 0) + (showMemory ? 4 : 0)
                               + (compactModeDetails && showNetwork ? 8 : 0)
                               + (compactModeDetails && showTemperature ? 5 : 0)
                               + (compactModeDetails && showGpu ? 5 : 0))
    Layout.preferredHeight: vertical
                            ? PlasmaCore.Units.gridUnit
                              * Math.max(2, visibleMetricCount * 1.6)
                            : PlasmaCore.Units.gridUnit * 2
    implicitWidth: Layout.preferredWidth
    implicitHeight: Layout.preferredHeight

    GridLayout {
        anchors.fill: parent
        anchors.leftMargin: PlasmaCore.Units.smallSpacing
        anchors.rightMargin: PlasmaCore.Units.smallSpacing
        anchors.topMargin: PlasmaCore.Units.smallSpacing
        anchors.bottomMargin: compactView.compactGraphVisible
                              ? PlasmaCore.Units.smallSpacing
                                + compactView.compactGraphHeight
                              : PlasmaCore.Units.smallSpacing
        columns: compactView.vertical ? 1 : Math.max(1, compactView.visibleMetricCount)
        rowSpacing: PlasmaCore.Units.smallSpacing
        columnSpacing: PlasmaCore.Units.largeSpacing

        PlasmaCore.ToolTipArea {
            visible: compactView.showCpu
            Layout.fillWidth: compactView.vertical
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 4
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            mainText: compactView.ttopTr("CPU usage")
            subText: compactView.metricsProvider.cpuState === "available"
                     ? compactView.metricsProvider.cpuPercent.toFixed(1) + "%"
                     : compactView.metricsProvider.cpuState === "unavailable"
                       ? compactView.ttopTr("Unavailable") : compactView.ttopTr("Detecting…")

            RowLayout {
                anchors.fill: parent
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    visible: compactView.showMetricIcons
                    source: "cpu"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    text: compactView.ttopTr("CPU")
                    color: PlasmaCore.Theme.textColor
                    font.bold: true
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: compactView.metricsProvider.cpuState === "available"
                          ? compactView.metricsProvider.cpuPercent.toFixed(0) + "%"
                          : compactView.metricsProvider.cpuState === "unavailable" ? "—" : "…"
                    color: compactView.metricsProvider.cpuState === "available"
                           ? PlasmaCore.Theme.highlightColor
                           : PlasmaCore.Theme.disabledTextColor
                    font.family: "monospace"
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }
        }

        PlasmaCore.ToolTipArea {
            visible: compactView.showMemory
            Layout.fillWidth: compactView.vertical
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 4
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            mainText: compactView.ttopTr("Memory usage")
            subText: compactView.metricsProvider.memoryState === "available"
                     ? compactView.metricsProvider.memoryDisplayText
                     : compactView.metricsProvider.memoryState === "unavailable"
                       ? compactView.ttopTr("Unavailable") : compactView.ttopTr("Detecting…")

            RowLayout {
                anchors.fill: parent
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    visible: compactView.showMetricIcons
                    source: "memory"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    text: compactView.ttopTr("RAM")
                    color: PlasmaCore.Theme.textColor
                    font.bold: true
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: compactView.metricsProvider.memoryState === "available"
                          ? compactView.metricsProvider.memoryPercent.toFixed(0) + "%"
                          : compactView.metricsProvider.memoryState === "unavailable" ? "—" : "…"
                    color: compactView.metricsProvider.memoryState === "available"
                           ? PlasmaCore.Theme.highlightColor
                           : PlasmaCore.Theme.disabledTextColor
                    font.family: "monospace"
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }
        }

        PlasmaCore.ToolTipArea {
            visible: compactView.compactModeDetails && compactView.showNetwork
            Layout.fillWidth: compactView.vertical
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 8
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            mainText: compactView.ttopTr("Network throughput")
            subText: compactView.metricsProvider.networkState === "available"
                     ? compactView.ttopTr("Receive: %1\nTransmit: %2",
                                          [compactView.metricsProvider.networkRxDisplayText,
                                           compactView.metricsProvider.networkTxDisplayText])
                     : compactView.metricsProvider.networkState === "unavailable"
                       ? compactView.ttopTr("Unavailable") : compactView.ttopTr("Detecting…")

            RowLayout {
                anchors.fill: parent
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    visible: compactView.showMetricIcons
                    source: "network-wired"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: compactView.metricsProvider.networkState === "available"
                          ? "↓ " + compactView.metricsProvider.networkRxDisplayText
                            + "  ↑ " + compactView.metricsProvider.networkTxDisplayText
                          : compactView.metricsProvider.networkState === "unavailable" ? "NET —" : "NET …"
                    color: compactView.metricsProvider.networkState === "available"
                           ? PlasmaCore.Theme.highlightColor
                           : PlasmaCore.Theme.disabledTextColor
                    font.family: "monospace"
                    horizontalAlignment: compactView.vertical ? Text.AlignLeft : Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }

        PlasmaCore.ToolTipArea {
            visible: compactView.compactModeDetails && compactView.showTemperature
            Layout.fillWidth: compactView.vertical
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 5
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            mainText: compactView.ttopTr("CPU temperature")
            subText: compactView.metricsProvider.temperatureState === "available"
                     ? compactView.metricsProvider.temperatureDisplayText
                     : compactView.metricsProvider.temperatureState === "unavailable"
                       ? compactView.ttopTr("Unavailable") : compactView.ttopTr("Detecting…")

            RowLayout {
                anchors.fill: parent
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    visible: compactView.showMetricIcons
                    source: "temperature-normal"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    text: compactView.ttopTr("TEMP")
                    color: PlasmaCore.Theme.textColor
                    font.bold: true
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: compactView.metricsProvider.temperatureState === "available"
                          ? compactView.metricsProvider.temperatureDisplayText
                          : compactView.metricsProvider.temperatureState === "unavailable" ? "—" : "…"
                    color: compactView.metricsProvider.temperatureState === "available"
                           ? PlasmaCore.Theme.highlightColor
                           : PlasmaCore.Theme.disabledTextColor
                    font.family: "monospace"
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }
        }

        PlasmaCore.ToolTipArea {
            visible: compactView.compactModeDetails && compactView.showGpu
            Layout.fillWidth: compactView.vertical
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 5
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            mainText: compactView.backendProvider.gpuName !== ""
                      ? compactView.backendProvider.gpuName : compactView.ttopTr("GPU utilization")
            subText: compactView.backendProvider.gpuState === "available"
                     && isFinite(compactView.backendProvider.gpuUtilizationPercent)
                     ? compactView.backendProvider.gpuUtilizationPercent.toFixed(1) + "%"
                     : compactView.backendProvider.backendState === "unavailable"
                       ? compactView.ttopTr("Backend unavailable")
                       : compactView.backendProvider.gpuState === "unavailable"
                         ? compactView.ttopTr("GPU unavailable") : compactView.ttopTr("Detecting…")

            RowLayout {
                anchors.fill: parent
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    visible: compactView.showMetricIcons
                    source: "video-display"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    text: compactView.ttopTr("GPU")
                    color: PlasmaCore.Theme.textColor
                    font.bold: true
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: compactView.backendProvider.gpuState === "available"
                          && isFinite(compactView.backendProvider.gpuUtilizationPercent)
                          ? compactView.backendProvider.gpuUtilizationPercent.toFixed(0) + "%"
                          : compactView.backendProvider.gpuState === "detecting" ? "…" : "—"
                    color: compactView.backendProvider.gpuState === "available"
                           ? PlasmaCore.Theme.highlightColor
                           : PlasmaCore.Theme.disabledTextColor
                    font.family: "monospace"
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        RowLayout {
            visible: compactView.visibleMetricCount === 0
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 6
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaCore.IconItem {
                source: "utilities-system-monitor"
                Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                Layout.preferredHeight: width
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: compactView.widgetTitle
                color: PlasmaCore.Theme.textColor
                elide: Text.ElideRight
            }
        }
    }

    Components.Sparkline {
        languageMode: compactView.languageMode
        id: compactGraph
        objectName: "compactSparkline"
        visible: compactView.compactGraphVisible
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: PlasmaCore.Units.smallSpacing
        anchors.rightMargin: PlasmaCore.Units.smallSpacing
        anchors.bottomMargin: 1
        height: compactView.compactGraphHeight
        values: compactView.compactPrimaryValues
        secondaryValues: compactView.compactSecondaryValues
        showSecondary: compactView.effectiveCompactGraphMetric === "network"
        dynamicScale: compactView.effectiveCompactGraphMetric === "network"
        dynamicMinimumMaximum: 1024
        minimumValue: 0
        maximumValue: 100
        secondaryDashed: true
        accessibleName: compactView.compactGraphAccessibleName
        accessibleDescription: compactView.effectiveCompactGraphMetric === "network"
                               ? compactView.ttopTr("Receive is solid and transmit is dashed; numeric values remain authoritative")
                               : compactView.ttopTr("Supplementary history graph; numeric values remain authoritative")
        tooltipText: compactView.effectiveCompactGraphMetric === "network"
                     ? compactView.ttopTr("Receive is solid, transmit is dashed; approximately %1 seconds",
                                          [compactView.compactGraphSeconds])
                     : compactView.ttopTr("Approximately %1 seconds",
                                          [compactView.compactGraphSeconds])
        backgroundColor: PlasmaCore.Theme.backgroundColor
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

Item {
    id: compactView

    property var metricsProvider
    property bool showCpu: true
    property bool showMemory: true
    property bool showNetwork: true
    property bool showTemperature: true
    property bool showMetricIcons: true
    property bool compactModeDetails: false
    property string widgetTitle: "TTop Desk"
    property int formFactor: PlasmaCore.Types.Planar

    readonly property bool vertical: formFactor === PlasmaCore.Types.Vertical
    readonly property int visibleMetricCount:
        (showCpu ? 1 : 0) + (showMemory ? 1 : 0)
        + (compactModeDetails && showNetwork ? 1 : 0)
        + (compactModeDetails && showTemperature ? 1 : 0)

    Layout.preferredWidth: vertical
                           ? PlasmaCore.Units.gridUnit * 5
                           : PlasmaCore.Units.gridUnit * Math.max(6,
                               (showCpu ? 4 : 0) + (showMemory ? 4 : 0)
                               + (compactModeDetails && showNetwork ? 8 : 0)
                               + (compactModeDetails && showTemperature ? 5 : 0))
    Layout.preferredHeight: vertical
                            ? PlasmaCore.Units.gridUnit
                              * Math.max(2, visibleMetricCount * 1.6)
                            : PlasmaCore.Units.gridUnit * 2
    implicitWidth: Layout.preferredWidth
    implicitHeight: Layout.preferredHeight

    GridLayout {
        anchors.fill: parent
        anchors.margins: PlasmaCore.Units.smallSpacing
        columns: compactView.vertical ? 1 : Math.max(1, compactView.visibleMetricCount)
        rowSpacing: PlasmaCore.Units.smallSpacing
        columnSpacing: PlasmaCore.Units.largeSpacing

        PlasmaCore.ToolTipArea {
            visible: compactView.showCpu
            Layout.fillWidth: compactView.vertical
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 4
            Layout.preferredHeight: PlasmaCore.Units.gridUnit
            mainText: qsTr("CPU usage")
            subText: compactView.metricsProvider.cpuState === "available"
                     ? compactView.metricsProvider.cpuPercent.toFixed(1) + "%"
                     : compactView.metricsProvider.cpuState === "unavailable"
                       ? qsTr("Unavailable") : qsTr("Detecting…")

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
                    text: qsTr("CPU")
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
            mainText: qsTr("Memory usage")
            subText: compactView.metricsProvider.memoryState === "available"
                     ? compactView.metricsProvider.memoryDisplayText
                     : compactView.metricsProvider.memoryState === "unavailable"
                       ? qsTr("Unavailable") : qsTr("Detecting…")

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
                    text: qsTr("RAM")
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
            mainText: qsTr("Network throughput")
            subText: compactView.metricsProvider.networkState === "available"
                     ? qsTr("Receive: %1\nTransmit: %2")
                       .arg(compactView.metricsProvider.networkRxDisplayText)
                       .arg(compactView.metricsProvider.networkTxDisplayText)
                     : compactView.metricsProvider.networkState === "unavailable"
                       ? qsTr("Unavailable") : qsTr("Detecting…")

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
            mainText: qsTr("CPU temperature")
            subText: compactView.metricsProvider.temperatureState === "available"
                     ? compactView.metricsProvider.temperatureDisplayText
                     : compactView.metricsProvider.temperatureState === "unavailable"
                       ? qsTr("Unavailable") : qsTr("Detecting…")

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
                    text: qsTr("TEMP")
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
}

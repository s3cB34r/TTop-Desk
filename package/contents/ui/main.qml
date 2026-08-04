/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import "components" as Components

Item {
    id: root

    // Set to true while developing to log system-monitor sensor discovery.
    property bool debugMetrics: false

    Plasmoid.switchWidth: PlasmaCore.Units.gridUnit * 12
    Plasmoid.switchHeight: PlasmaCore.Units.gridUnit * 9
    Plasmoid.compactRepresentation: compactRepresentation
    Plasmoid.fullRepresentation: fullRepresentation

    MetricsProvider {
        id: metrics
        debugMetrics: root.debugMetrics
    }

    Component {
        id: compactRepresentation

        Item {
            implicitWidth: PlasmaCore.Units.gridUnit * 7
            implicitHeight: PlasmaCore.Units.gridUnit * 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: PlasmaCore.Units.smallSpacing
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    source: "utilities-system-monitor"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: "TTop Desk"
                    elide: Text.ElideRight
                }
            }
        }
    }

    Component {
        id: fullRepresentation

        Rectangle {
            id: card

            Layout.minimumWidth: PlasmaCore.Units.gridUnit * 12
            Layout.minimumHeight: PlasmaCore.Units.gridUnit * 17
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 17
            Layout.preferredHeight: PlasmaCore.Units.gridUnit * 23
            implicitWidth: Layout.preferredWidth
            implicitHeight: Layout.preferredHeight

            color: "#25282d"
            radius: PlasmaCore.Units.smallSpacing
            border.color: Qt.rgba(PlasmaCore.Theme.highlightColor.r,
                                  PlasmaCore.Theme.highlightColor.g,
                                  PlasmaCore.Theme.highlightColor.b, 0.45)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: PlasmaCore.Units.largeSpacing
                spacing: PlasmaCore.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: PlasmaCore.Units.smallSpacing

                    PlasmaCore.IconItem {
                        source: "utilities-system-monitor"
                        Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                        Layout.preferredHeight: width
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: "TTop Desk"
                        color: "#f5f5f5"
                        font.bold: true
                        font.pointSize: PlasmaCore.Theme.defaultFont.pointSize + 2
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: PlasmaCore.Theme.highlightColor
                    opacity: 0.45
                }

                Components.MetricRow {
                    Layout.fillWidth: true
                    metricLabel: "CPU"
                    valueText: metrics.cpuAvailable
                               ? metrics.cpuPercent.toFixed(1) + "%"
                               : ""
                    progressValue: metrics.cpuPercent
                    availabilityState: metrics.cpuState
                }

                Components.MetricRow {
                    Layout.fillWidth: true
                    metricLabel: "RAM"
                    valueText: metrics.memoryDisplayText
                    progressValue: metrics.memoryPercent
                    availabilityState: metrics.memoryState
                }

                Components.TemperatureRow {
                    Layout.fillWidth: true
                    valueText: metrics.temperatureDisplayText
                    availabilityState: metrics.temperatureState
                    severity: metrics.temperatureSeverity
                }

                Components.NetworkRow {
                    Layout.fillWidth: true
                    rxText: metrics.networkRxDisplayText
                    txText: metrics.networkTxDisplayText
                    availabilityState: metrics.networkState
                }

                Components.DiskIoRow {
                    Layout.fillWidth: true
                    readText: metrics.diskReadDisplayText
                    writeText: metrics.diskWriteDisplayText
                    availabilityState: metrics.diskIoState
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: PlasmaCore.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: "FILESYSTEMS"
                        color: "#f5f5f5"
                        font.bold: true
                    }

                    PlasmaComponents.Label {
                        visible: !metrics.filesystemAvailable
                        text: metrics.filesystemState === "unavailable"
                              ? "Unavailable" : "Detecting…"
                        color: "#b8bcc2"
                        font.family: "monospace"
                    }
                }

                Repeater {
                    model: metrics.filesystemEntries

                    delegate: Components.FilesystemRow {
                        Layout.fillWidth: true
                        mountPath: model.mountPath
                        capacityText: model.displayText
                        percent: model.percent
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}

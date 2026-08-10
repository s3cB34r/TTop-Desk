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
    property bool showHeader: true
    property bool showMetricIcons: true

    readonly property int contentMargin: PlasmaCore.Units.largeSpacing
    readonly property int minimumCardWidth: PlasmaCore.Units.gridUnit * 12
    readonly property int preferredCardWidth: PlasmaCore.Units.gridUnit * 17

    implicitWidth: preferredCardWidth
    implicitHeight: content.implicitHeight + contentMargin * 2

    Layout.minimumWidth: minimumCardWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    color: PlasmaCore.Theme.backgroundColor
    radius: PlasmaCore.Units.smallSpacing
    border.color: Qt.rgba(PlasmaCore.Theme.highlightColor.r,
                          PlasmaCore.Theme.highlightColor.g,
                          PlasmaCore.Theme.highlightColor.b, 0.35)
    border.width: 1

    ColumnLayout {
        id: content
        objectName: "fullContent"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: fullView.contentMargin
        spacing: PlasmaCore.Units.smallSpacing

        RowLayout {
            visible: fullView.showHeader
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaCore.IconItem {
                source: "utilities-system-monitor"
                Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                Layout.preferredHeight: width
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: qsTr("TTop Desk")
                color: PlasmaCore.Theme.textColor
                font.bold: true
                font.pointSize: PlasmaCore.Theme.defaultFont.pointSize + 2
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: fullView.showHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: PlasmaCore.Theme.highlightColor
            opacity: 0.35
        }

        Components.MetricRow {
            visible: fullView.showCpu
            Layout.fillWidth: true
            metricLabel: qsTr("CPU")
            iconName: "cpu"
            showIcon: fullView.showMetricIcons
            valueText: fullView.metricsProvider.cpuAvailable
                       ? fullView.metricsProvider.cpuPercent.toFixed(1) + "%" : ""
            progressValue: fullView.metricsProvider.cpuPercent
            availabilityState: fullView.metricsProvider.cpuState
        }

        Components.MetricRow {
            visible: fullView.showMemory
            Layout.fillWidth: true
            metricLabel: qsTr("RAM")
            iconName: "memory"
            showIcon: fullView.showMetricIcons
            valueText: fullView.metricsProvider.memoryDisplayText
            progressValue: fullView.metricsProvider.memoryPercent
            availabilityState: fullView.metricsProvider.memoryState
        }

        Components.TemperatureRow {
            visible: fullView.showTemperature
            Layout.fillWidth: true
            showIcon: fullView.showMetricIcons
            valueText: fullView.metricsProvider.temperatureDisplayText
            availabilityState: fullView.metricsProvider.temperatureState
            severity: fullView.metricsProvider.temperatureSeverity
        }

        Components.NetworkRow {
            visible: fullView.showNetwork
            Layout.fillWidth: true
            showIcon: fullView.showMetricIcons
            rxText: fullView.metricsProvider.networkRxDisplayText
            txText: fullView.metricsProvider.networkTxDisplayText
            availabilityState: fullView.metricsProvider.networkState
        }

        Components.DiskIoRow {
            visible: fullView.showDiskIo
            Layout.fillWidth: true
            showIcon: fullView.showMetricIcons
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
                }
            }
        }

        Components.ProcessList {
            objectName: "processSection"
            visible: fullView.showProcesses
            Layout.fillWidth: true
            backendProvider: fullView.backendProvider
            showIcon: fullView.showMetricIcons
        }

        PlasmaComponents.Label {
            visible: !fullView.showCpu && !fullView.showMemory
                     && !fullView.showNetwork && !fullView.showTemperature
                     && !fullView.showFilesystems && !fullView.showDiskIo
                     && !fullView.showProcesses
            Layout.fillWidth: true
            text: qsTr("All metric sections are hidden. Open the widget settings to choose what to display.")
            color: PlasmaCore.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}

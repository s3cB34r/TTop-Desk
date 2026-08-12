/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import "../TTop/Runtime"

ColumnLayout {
    id: section

    Layout.minimumWidth: 0

    property string languageMode: "en"
    property var backendProvider
    property bool showIcon: true
    property bool showLabel: true
    property bool showUtilization: true
    property bool showMemory: true
    property bool showTemperature: true
    property bool showProgressBars: true
    property bool showGraph: false
    property var graphValues: []
    property string graphAccessibleName: ttopTr("GPU utilization history")
    property string graphDescription: ""
    property string graphTooltip: ""
    property color graphBackgroundColor: PlasmaCore.Theme.backgroundColor
    property bool denseMode: false

    readonly property bool available: backendProvider !== null
                                      && backendProvider.gpuState === "available"
    spacing: denseMode ? 0 : PlasmaCore.Units.smallSpacing

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    function statusText() {
        if (backendProvider === null) return ttopTr("Backend unavailable");
        if (backendProvider.backendState === "unavailable"
                || backendProvider.backendState === "error") {
            return ttopTr("Backend unavailable");
        }
        if (backendProvider.gpuState === "detecting") return ttopTr("Detecting…");
        if (backendProvider.gpuState === "unavailable") return ttopTr("GPU unavailable");
        if (backendProvider.gpuState === "error") return ttopTr("GPU error");
        return "";
    }

    SectionHeader {
        Layout.fillWidth: true
        title: section.ttopTr("GPU")
        iconName: "video-display"
        showIcon: section.showIcon
        showLabel: section.showLabel
        statusText: section.statusText()
    }

    PlasmaComponents.Label {
        objectName: "gpuName"
        visible: section.available
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: section.backendProvider.gpuName
        color: PlasmaCore.Theme.disabledTextColor
        font.pointSize: PlasmaCore.Theme.smallestFont.pointSize
        elide: Text.ElideRight
        Accessible.name: section.ttopTr("GPU model %1", [text])
    }

    RowLayout {
        visible: section.available && section.showUtilization
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            visible: section.showLabel
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: section.ttopTr("UTILIZATION")
            color: PlasmaCore.Theme.textColor
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 0
            text: isFinite(section.backendProvider.gpuUtilizationPercent)
                  ? section.backendProvider.gpuUtilizationPercent.toFixed(1) + "%"
                  : section.ttopTr("Unavailable")
            color: isFinite(section.backendProvider.gpuUtilizationPercent)
                   ? PlasmaCore.Theme.highlightColor : PlasmaCore.Theme.disabledTextColor
            font.family: "monospace"
        }
    }

    PlasmaComponents.ProgressBar {
        objectName: "gpuUtilizationProgressBar"
        visible: section.available && section.showUtilization && section.showProgressBars
                 && isFinite(section.backendProvider.gpuUtilizationPercent)
        Layout.fillWidth: true
        minimumValue: 0
        maximumValue: 100
        value: isFinite(section.backendProvider.gpuUtilizationPercent)
               ? Math.max(0, Math.min(100,
                                     section.backendProvider.gpuUtilizationPercent)) : 0
    }

    Sparkline {
        languageMode: section.languageMode
        objectName: "gpuSparkline"
        visible: section.available && section.showGraph
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        values: section.graphValues
        minimumValue: 0
        maximumValue: 100
        accessibleName: section.graphAccessibleName
        accessibleDescription: section.graphDescription
        tooltipText: section.graphTooltip
        backgroundColor: section.graphBackgroundColor
    }

    RowLayout {
        visible: section.available && section.showMemory
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            visible: section.showLabel
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: section.ttopTr("VRAM")
            color: PlasmaCore.Theme.textColor
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 0
            Layout.maximumWidth: section.width * 0.8
            text: section.backendProvider.gpuMemoryDisplayText !== ""
                  ? section.backendProvider.gpuMemoryDisplayText : section.ttopTr("Unavailable")
            color: section.backendProvider.gpuMemoryDisplayText !== ""
                   ? PlasmaCore.Theme.highlightColor : PlasmaCore.Theme.disabledTextColor
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }

    PlasmaComponents.ProgressBar {
        objectName: "gpuMemoryProgressBar"
        visible: section.available && section.showMemory && section.showProgressBars
                 && isFinite(section.backendProvider.gpuMemoryPercent)
        Layout.fillWidth: true
        minimumValue: 0
        maximumValue: 100
        value: isFinite(section.backendProvider.gpuMemoryPercent)
               ? Math.max(0, Math.min(100,
                                     section.backendProvider.gpuMemoryPercent)) : 0
    }

    RowLayout {
        visible: section.available && section.showTemperature
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            visible: section.showLabel
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: section.ttopTr("GPU TEMP")
            color: PlasmaCore.Theme.textColor
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 0
            text: section.backendProvider.gpuTemperatureDisplayText !== ""
                  ? section.backendProvider.gpuTemperatureDisplayText : section.ttopTr("Unavailable")
            color: section.backendProvider.gpuTemperatureDisplayText !== ""
                   ? PlasmaCore.Theme.highlightColor : PlasmaCore.Theme.disabledTextColor
            font.family: "monospace"
        }
    }
}

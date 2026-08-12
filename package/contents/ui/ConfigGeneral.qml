/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.15 as QtControls
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "ConfigurationUtils.js" as Configuration

Kirigami.FormLayout {
    id: configPage

    property alias cfg_widgetTitle: titleField.text
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_showMetricIcons: showMetricIcons.checked
    property alias cfg_showSectionLabels: showSectionLabels.checked
    property alias cfg_compactSpacing: compactSpacing.checked
    property alias cfg_denseMode: denseMode.checked
    property alias cfg_compactModeDetails: compactDetails.checked
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showMemory: showMemory.checked
    property alias cfg_showTemperature: showTemperature.checked
    property alias cfg_showNetwork: showNetwork.checked
    property alias cfg_showDiskIo: showDiskIo.checked
    property alias cfg_showFilesystems: showFilesystems.checked
    property alias cfg_showCpuProgressBar: cpuBar.checked
    property alias cfg_showMemoryProgressBar: memoryBar.checked
    property alias cfg_showFilesystemProgressBars: filesystemBars.checked
    property alias cfg_showNetworkRx: networkRx.checked
    property alias cfg_showNetworkTx: networkTx.checked
    property alias cfg_showDiskRead: diskRead.checked
    property alias cfg_showDiskWrite: diskWrite.checked
    property alias cfg_showProcesses: showProcesses.checked
    property alias cfg_showGpu: showGpu.checked
    property string cfg_processSortMode: "cpu"
    property int cfg_maximumProcessEntries: 5
    property int cfg_processRefreshIntervalMs: 2000
    property alias cfg_showProcessCpu: showProcessCpu.checked
    property alias cfg_showProcessMemory: showProcessMemory.checked
    property alias cfg_showGpuUtilization: showGpuUtilization.checked
    property alias cfg_showGpuMemory: showGpuMemory.checked
    property alias cfg_showGpuTemperature: showGpuTemperature.checked
    property alias cfg_showGpuProgressBars: showGpuProgressBars.checked
    property alias cfg_showGraphs: showGraphs.checked
    property alias cfg_showCpuGraph: showCpuGraph.checked
    property alias cfg_showMemoryGraph: showMemoryGraph.checked
    property alias cfg_showGpuGraph: showGpuGraph.checked
    property alias cfg_showNetworkGraph: showNetworkGraph.checked
    property alias cfg_showCompactGraphs: showCompactGraphs.checked
    property string cfg_compactGraphMetric: "cpu"
    property int cfg_historySampleCount: 60
    property int cfg_gpuRefreshIntervalMs: 1000
    property int cfg_refreshIntervalMs: 1000
    property int cfg_filesystemRefreshIntervalMs: 15000
    property int cfg_maximumFilesystemEntries: 3
    property alias cfg_usePlasmaThemeBackground: themeBackground.checked
    property real cfg_backgroundOpacity: 1.0
    property alias cfg_customBackgroundColor: customColor.text

    function optionIndex(value, options, fallbackIndex) {
        var index = options.indexOf(value);
        return index >= 0 ? index : fallbackIndex;
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("General")
    }

    QtControls.TextField {
        id: titleField
        Kirigami.FormData.label: qsTr("Widget title:")
        maximumLength: 40
        placeholderText: Configuration.DEFAULT_TITLE
        selectByMouse: true
        onEditingFinished: text = Configuration.title(text)
        Accessible.name: qsTr("Visible widget title")
    }

    QtControls.CheckBox {
        id: showHeader
        text: qsTr("Show widget header")
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Display")
    }

    QtControls.CheckBox { id: showMetricIcons; text: qsTr("Show metric icons") }
    QtControls.CheckBox { id: showSectionLabels; text: qsTr("Show section labels") }
    QtControls.CheckBox { id: compactSpacing; text: qsTr("Use compact section spacing") }
    QtControls.CheckBox { id: denseMode; text: qsTr("Use dense row spacing") }
    QtControls.CheckBox {
        id: compactDetails
        text: qsTr("Show network and temperature details in compact view")
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Metrics")
    }

    QtControls.CheckBox { id: showCpu; text: qsTr("Show CPU") }
    QtControls.CheckBox { id: cpuBar; text: qsTr("Show CPU progress bar"); enabled: showCpu.checked }
    QtControls.CheckBox { id: showMemory; text: qsTr("Show memory") }
    QtControls.CheckBox { id: memoryBar; text: qsTr("Show memory progress bar"); enabled: showMemory.checked }
    QtControls.CheckBox { id: showTemperature; text: qsTr("Show temperature") }
    QtControls.CheckBox { id: showNetwork; text: qsTr("Show network") }
    QtControls.CheckBox { id: networkRx; text: qsTr("Show network receive rate"); enabled: showNetwork.checked }
    QtControls.CheckBox { id: networkTx; text: qsTr("Show network transmit rate"); enabled: showNetwork.checked }
    QtControls.CheckBox { id: showDiskIo; text: qsTr("Show disk I/O") }
    QtControls.CheckBox { id: diskRead; text: qsTr("Show disk read rate"); enabled: showDiskIo.checked }
    QtControls.CheckBox { id: diskWrite; text: qsTr("Show disk write rate"); enabled: showDiskIo.checked }
    QtControls.CheckBox { id: showFilesystems; text: qsTr("Show filesystems") }
    QtControls.CheckBox {
        id: filesystemBars
        text: qsTr("Show filesystem progress bars")
        enabled: showFilesystems.checked
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 4
        text: qsTr("GPU")
    }

    QtControls.CheckBox { id: showGpu; text: qsTr("Show GPU") }
    QtControls.CheckBox {
        id: showGpuUtilization
        text: qsTr("Show GPU utilization")
        enabled: showGpu.checked
    }
    QtControls.CheckBox {
        id: showGpuMemory
        text: qsTr("Show GPU memory")
        enabled: showGpu.checked
    }
    QtControls.CheckBox {
        id: showGpuTemperature
        text: qsTr("Show GPU temperature")
        enabled: showGpu.checked
    }
    QtControls.CheckBox {
        id: showGpuProgressBars
        text: qsTr("Show GPU progress bars")
        enabled: showGpu.checked
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("GPU update:")
        enabled: showGpu.checked
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": qsTr("500 ms"), "milliseconds": 500 },
            { "label": qsTr("1 second"), "milliseconds": 1000 },
            { "label": qsTr("2 seconds"), "milliseconds": 2000 },
            { "label": qsTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_gpuRefreshIntervalMs,
                                             [500, 1000, 2000, 5000], 1)
        onActivated: configPage.cfg_gpuRefreshIntervalMs = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Graphs")
    }

    QtControls.CheckBox { id: showGraphs; text: qsTr("Show graphs") }
    QtControls.CheckBox {
        id: showCpuGraph
        text: qsTr("Show CPU graph")
        enabled: showGraphs.checked && showCpu.checked
    }
    QtControls.CheckBox {
        id: showMemoryGraph
        text: qsTr("Show memory graph")
        enabled: showGraphs.checked && showMemory.checked
    }
    QtControls.CheckBox {
        id: showGpuGraph
        text: qsTr("Show GPU graph")
        enabled: showGraphs.checked && showGpu.checked
    }
    QtControls.CheckBox {
        id: showNetworkGraph
        text: qsTr("Show network graph")
        enabled: showGraphs.checked && showNetwork.checked
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("History length:")
        enabled: showGraphs.checked
        textRole: "label"
        valueRole: "count"
        model: [
            { "label": qsTr("30 samples"), "count": 30 },
            { "label": qsTr("60 samples"), "count": 60 },
            { "label": qsTr("120 samples"), "count": 120 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_historySampleCount,
                                             [30, 60, 120], 1)
        onActivated: configPage.cfg_historySampleCount = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 4
        text: qsTr("Compact")
    }

    QtControls.CheckBox {
        id: showCompactGraphs
        text: qsTr("Show graphs in compact view")
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Compact graph metric:")
        enabled: showCompactGraphs.checked
        textRole: "label"
        valueRole: "metric"
        model: [
            { "label": qsTr("CPU usage"), "metric": "cpu" },
            { "label": qsTr("Memory usage"), "metric": "memory" },
            { "label": qsTr("GPU utilization"), "metric": "gpu" },
            { "label": qsTr("Network RX/TX"), "metric": "network" }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_compactGraphMetric,
                                             ["cpu", "memory", "gpu", "network"], 0)
        onActivated: configPage.cfg_compactGraphMetric = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Processes")
    }

    QtControls.CheckBox { id: showProcesses; text: qsTr("Show Top Processes") }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Process sorting:")
        enabled: showProcesses.checked
        textRole: "label"
        valueRole: "mode"
        model: [
            { "label": qsTr("CPU usage"), "mode": "cpu" },
            { "label": qsTr("Resident memory"), "mode": "memory" }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_processSortMode,
                                             ["cpu", "memory"], 0)
        onActivated: configPage.cfg_processSortMode = currentValue
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Process rows:")
        enabled: showProcesses.checked
        textRole: "label"
        valueRole: "count"
        model: [
            { "label": "3", "count": 3 },
            { "label": "4", "count": 4 },
            { "label": "5", "count": 5 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_maximumProcessEntries,
                                             [3, 4, 5], 2)
        onActivated: configPage.cfg_maximumProcessEntries = currentValue
    }

    QtControls.CheckBox {
        id: showProcessCpu
        text: qsTr("Show process CPU column")
        enabled: showProcesses.checked
    }

    QtControls.CheckBox {
        id: showProcessMemory
        text: qsTr("Show process memory column")
        enabled: showProcesses.checked
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Process update:")
        enabled: showProcesses.checked
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": qsTr("1 second"), "milliseconds": 1000 },
            { "label": qsTr("2 seconds"), "milliseconds": 2000 },
            { "label": qsTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_processRefreshIntervalMs,
                                             [1000, 2000, 5000], 1)
        onActivated: configPage.cfg_processRefreshIntervalMs = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Refresh")
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Live metrics:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": qsTr("500 ms"), "milliseconds": 500 },
            { "label": qsTr("1 second"), "milliseconds": 1000 },
            { "label": qsTr("2 seconds"), "milliseconds": 2000 },
            { "label": qsTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_refreshIntervalMs,
                                             [500, 1000, 2000, 5000], 1)
        onActivated: configPage.cfg_refreshIntervalMs = currentValue
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Filesystems:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": qsTr("5 seconds"), "milliseconds": 5000 },
            { "label": qsTr("10 seconds"), "milliseconds": 10000 },
            { "label": qsTr("15 seconds"), "milliseconds": 15000 },
            { "label": qsTr("30 seconds"), "milliseconds": 30000 },
            { "label": qsTr("60 seconds"), "milliseconds": 60000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_filesystemRefreshIntervalMs,
                                             [5000, 10000, 15000, 30000, 60000], 2)
        onActivated: configPage.cfg_filesystemRefreshIntervalMs = currentValue
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: qsTr("Filesystem rows:")
        textRole: "label"
        valueRole: "count"
        model: [
            { "label": "1", "count": 1 },
            { "label": "2", "count": 2 },
            { "label": "3", "count": 3 },
            { "label": "4", "count": 4 },
            { "label": "5", "count": 5 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_maximumFilesystemEntries,
                                             [1, 2, 3, 4, 5], 2)
        onActivated: configPage.cfg_maximumFilesystemEntries = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Appearance")
    }

    QtControls.CheckBox {
        id: themeBackground
        text: qsTr("Use Plasma theme background")
    }

    QtControls.SpinBox {
        Kirigami.FormData.label: qsTr("Background opacity:")
        from: 35
        to: 100
        stepSize: 5
        value: Math.round(Configuration.opacity(configPage.cfg_backgroundOpacity) * 100)
        textFromValue: function(value) { return value + "%"; }
        valueFromText: function(text) {
            var number = parseInt(text, 10);
            return isFinite(number) ? number : 100;
        }
        onValueModified: configPage.cfg_backgroundOpacity = value / 100
    }

    QtControls.TextField {
        id: customColor
        Kirigami.FormData.label: qsTr("Custom background:")
        enabled: !themeBackground.checked
        maximumLength: 9
        placeholderText: Configuration.DEFAULT_BACKGROUND_COLOR
        selectByMouse: true
        onEditingFinished: text = Configuration.color(text,
                                                       Configuration.DEFAULT_BACKGROUND_COLOR)
        Accessible.name: qsTr("Custom background color in hexadecimal notation")
    }
}

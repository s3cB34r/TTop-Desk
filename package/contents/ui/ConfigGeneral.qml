/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.15 as QtControls
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core 2.0 as PlasmaCore
import "TTop/Runtime"
import "ConfigurationUtils.js" as Configuration

Kirigami.FormLayout {
    id: configPage

    property string cfg_languageMode: "en"
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

    readonly property string effectiveLanguageMode:
        Configuration.languageMode(cfg_languageMode)

    function ttopTr(source, values) {
        return ttopTranslations.text(effectiveLanguageMode, source, values || []);
    }

    function optionIndex(value, options, fallbackIndex) {
        var index = options.indexOf(value);
        return index >= 0 ? index : fallbackIndex;
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: configPage.ttopTr("General")
    }

    QtControls.ComboBox {
        id: languageSelector
        Kirigami.FormData.label: configPage.ttopTr("Language:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        textRole: "label"
        valueRole: "mode"
        model: [
            { "label": configPage.ttopTr("English"), "mode": "en" },
            { "label": configPage.ttopTr("Deutsch"), "mode": "de" },
            { "label": configPage.ttopTr("System default"), "mode": "system" }
        ]
        currentIndex: configPage.optionIndex(configPage.effectiveLanguageMode,
                                             ["en", "de", "system"], 0)
        onActivated: configPage.cfg_languageMode = currentValue
    }

    QtControls.TextField {
        id: titleField
        Kirigami.FormData.label: configPage.ttopTr("Widget title:")
        maximumLength: 40
        placeholderText: Configuration.DEFAULT_TITLE
        selectByMouse: true
        onEditingFinished: text = Configuration.title(text)
        Accessible.name: configPage.ttopTr("Visible widget title")
    }

    QtControls.CheckBox {
        id: showHeader
        text: configPage.ttopTr("Show widget header")
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: configPage.ttopTr("Display")
    }

    QtControls.CheckBox { id: showMetricIcons; text: configPage.ttopTr("Show metric icons") }
    QtControls.CheckBox { id: showSectionLabels; text: configPage.ttopTr("Show section labels") }
    QtControls.CheckBox { id: compactSpacing; text: configPage.ttopTr("Use compact section spacing") }
    QtControls.CheckBox { id: denseMode; text: configPage.ttopTr("Use dense row spacing") }
    QtControls.CheckBox {
        id: compactDetails
        text: configPage.ttopTr("Show network and temperature details in compact view")
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: configPage.ttopTr("Metrics")
    }

    QtControls.CheckBox { id: showCpu; text: configPage.ttopTr("Show CPU") }
    QtControls.CheckBox { id: cpuBar; text: configPage.ttopTr("Show CPU progress bar"); enabled: showCpu.checked }
    QtControls.CheckBox { id: showMemory; text: configPage.ttopTr("Show memory") }
    QtControls.CheckBox { id: memoryBar; text: configPage.ttopTr("Show memory progress bar"); enabled: showMemory.checked }
    QtControls.CheckBox { id: showTemperature; text: configPage.ttopTr("Show temperature") }
    QtControls.CheckBox { id: showNetwork; text: configPage.ttopTr("Show network") }
    QtControls.CheckBox { id: networkRx; text: configPage.ttopTr("Show network receive rate"); enabled: showNetwork.checked }
    QtControls.CheckBox { id: networkTx; text: configPage.ttopTr("Show network transmit rate"); enabled: showNetwork.checked }
    QtControls.CheckBox { id: showDiskIo; text: configPage.ttopTr("Show disk I/O") }
    QtControls.CheckBox { id: diskRead; text: configPage.ttopTr("Show disk read rate"); enabled: showDiskIo.checked }
    QtControls.CheckBox { id: diskWrite; text: configPage.ttopTr("Show disk write rate"); enabled: showDiskIo.checked }
    QtControls.CheckBox { id: showFilesystems; text: configPage.ttopTr("Show filesystems") }
    QtControls.CheckBox {
        id: filesystemBars
        text: configPage.ttopTr("Show filesystem progress bars")
        enabled: showFilesystems.checked
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 4
        text: configPage.ttopTr("GPU")
    }

    QtControls.CheckBox { id: showGpu; text: configPage.ttopTr("Show GPU") }
    QtControls.CheckBox {
        id: showGpuUtilization
        text: configPage.ttopTr("Show GPU utilization")
        enabled: showGpu.checked
    }
    QtControls.CheckBox {
        id: showGpuMemory
        text: configPage.ttopTr("Show GPU memory")
        enabled: showGpu.checked
    }
    QtControls.CheckBox {
        id: showGpuTemperature
        text: configPage.ttopTr("Show GPU temperature")
        enabled: showGpu.checked
    }
    QtControls.CheckBox {
        id: showGpuProgressBars
        text: configPage.ttopTr("Show GPU progress bars")
        enabled: showGpu.checked
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("GPU update:")
        enabled: showGpu.checked
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": configPage.ttopTr("500 ms"), "milliseconds": 500 },
            { "label": configPage.ttopTr("1 second"), "milliseconds": 1000 },
            { "label": configPage.ttopTr("2 seconds"), "milliseconds": 2000 },
            { "label": configPage.ttopTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_gpuRefreshIntervalMs,
                                             [500, 1000, 2000, 5000], 1)
        onActivated: configPage.cfg_gpuRefreshIntervalMs = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: configPage.ttopTr("Graphs")
    }

    QtControls.CheckBox { id: showGraphs; text: configPage.ttopTr("Show graphs") }
    QtControls.CheckBox {
        id: showCpuGraph
        text: configPage.ttopTr("Show CPU graph")
        enabled: showGraphs.checked && showCpu.checked
    }
    QtControls.CheckBox {
        id: showMemoryGraph
        text: configPage.ttopTr("Show memory graph")
        enabled: showGraphs.checked && showMemory.checked
    }
    QtControls.CheckBox {
        id: showGpuGraph
        text: configPage.ttopTr("Show GPU graph")
        enabled: showGraphs.checked && showGpu.checked
    }
    QtControls.CheckBox {
        id: showNetworkGraph
        text: configPage.ttopTr("Show network graph")
        enabled: showGraphs.checked && showNetwork.checked
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("History length:")
        enabled: showGraphs.checked
        textRole: "label"
        valueRole: "count"
        model: [
            { "label": configPage.ttopTr("30 samples"), "count": 30 },
            { "label": configPage.ttopTr("60 samples"), "count": 60 },
            { "label": configPage.ttopTr("120 samples"), "count": 120 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_historySampleCount,
                                             [30, 60, 120], 1)
        onActivated: configPage.cfg_historySampleCount = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 4
        text: configPage.ttopTr("Compact")
    }

    QtControls.CheckBox {
        id: showCompactGraphs
        text: configPage.ttopTr("Show graphs in compact view")
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Compact graph metric:")
        enabled: showCompactGraphs.checked
        textRole: "label"
        valueRole: "metric"
        model: [
            { "label": configPage.ttopTr("CPU usage"), "metric": "cpu" },
            { "label": configPage.ttopTr("Memory usage"), "metric": "memory" },
            { "label": configPage.ttopTr("GPU utilization"), "metric": "gpu" },
            { "label": configPage.ttopTr("Network RX/TX"), "metric": "network" }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_compactGraphMetric,
                                             ["cpu", "memory", "gpu", "network"], 0)
        onActivated: configPage.cfg_compactGraphMetric = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: configPage.ttopTr("Processes")
    }

    QtControls.CheckBox { id: showProcesses; text: configPage.ttopTr("Show Top Processes") }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Process sorting:")
        enabled: showProcesses.checked
        textRole: "label"
        valueRole: "mode"
        model: [
            { "label": configPage.ttopTr("CPU usage"), "mode": "cpu" },
            { "label": configPage.ttopTr("Resident memory"), "mode": "memory" }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_processSortMode,
                                             ["cpu", "memory"], 0)
        onActivated: configPage.cfg_processSortMode = currentValue
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Process rows:")
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
        text: configPage.ttopTr("Show process CPU column")
        enabled: showProcesses.checked
    }

    QtControls.CheckBox {
        id: showProcessMemory
        text: configPage.ttopTr("Show process memory column")
        enabled: showProcesses.checked
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Process update:")
        enabled: showProcesses.checked
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": configPage.ttopTr("1 second"), "milliseconds": 1000 },
            { "label": configPage.ttopTr("2 seconds"), "milliseconds": 2000 },
            { "label": configPage.ttopTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_processRefreshIntervalMs,
                                             [1000, 2000, 5000], 1)
        onActivated: configPage.cfg_processRefreshIntervalMs = currentValue
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: configPage.ttopTr("Refresh")
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Live metrics:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": configPage.ttopTr("500 ms"), "milliseconds": 500 },
            { "label": configPage.ttopTr("1 second"), "milliseconds": 1000 },
            { "label": configPage.ttopTr("2 seconds"), "milliseconds": 2000 },
            { "label": configPage.ttopTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_refreshIntervalMs,
                                             [500, 1000, 2000, 5000], 1)
        onActivated: configPage.cfg_refreshIntervalMs = currentValue
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Filesystems:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": configPage.ttopTr("5 seconds"), "milliseconds": 5000 },
            { "label": configPage.ttopTr("10 seconds"), "milliseconds": 10000 },
            { "label": configPage.ttopTr("15 seconds"), "milliseconds": 15000 },
            { "label": configPage.ttopTr("30 seconds"), "milliseconds": 30000 },
            { "label": configPage.ttopTr("60 seconds"), "milliseconds": 60000 }
        ]
        currentIndex: configPage.optionIndex(configPage.cfg_filesystemRefreshIntervalMs,
                                             [5000, 10000, 15000, 30000, 60000], 2)
        onActivated: configPage.cfg_filesystemRefreshIntervalMs = currentValue
    }

    QtControls.ComboBox {
        Kirigami.FormData.label: configPage.ttopTr("Filesystem rows:")
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
        text: configPage.ttopTr("Appearance")
    }

    QtControls.CheckBox {
        id: themeBackground
        text: configPage.ttopTr("Use Plasma theme background")
    }

    QtControls.SpinBox {
        Kirigami.FormData.label: configPage.ttopTr("Background opacity:")
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
        Kirigami.FormData.label: configPage.ttopTr("Custom background:")
        enabled: !themeBackground.checked
        maximumLength: 9
        placeholderText: Configuration.DEFAULT_BACKGROUND_COLOR
        selectByMouse: true
        onEditingFinished: text = Configuration.color(text,
                                                       Configuration.DEFAULT_BACKGROUND_COLOR)
        Accessible.name: configPage.ttopTr("Custom background color in hexadecimal notation")
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    id: probe
    width: 900
    height: 1000

    property var cases: [
        "all", "systemTitle", "longTitle", "onlyCpu", "onlyProcesses", "cpuRam",
        "headerOnly", "headerDisabled", "noProcesses", "noFilesystems",
        "iconsDisabled", "progressDisabled", "processNameOnly",
        "subElements", "labelsDisabled", "dense", "gpuDisabled", "onlyGpu",
        "gpuUtilizationOnly", "gpuMemoryOnly", "gpuTemperatureOnly", "gpuNoBars",
        "processesGpu", "filesystemsGpu", "allHidden", "appearance",
        "graphsDisabled", "cpuGraphOnly", "networkGraphOnly",
        "history30", "history60", "history120"
    ]
    property int caseIndex: 0
    property real allHeight: 0
    property real allWidth: 0

    function fail(message) {
        console.error("TTop Desk configuration layout probe: FAIL ["
                      + cases[caseIndex] + "]: " + message);
        Qt.exit(1);
    }

    function findByObjectName(item, name) {
        if (item.objectName === name) return item;
        for (var index = 0; index < item.children.length; ++index) {
            var match = findByObjectName(item.children[index], name);
            if (match !== null) return match;
        }
        return null;
    }

    function visibleObjectCount(item, name) {
        var count = item.objectName === name && item.visible ? 1 : 0;
        for (var index = 0; index < item.children.length; ++index) {
            count += visibleObjectCount(item.children[index], name);
        }
        return count;
    }

    function bottomInsideCard(item) {
        var bottom = item.mapToItem(card, 0, item.height);
        return bottom.y <= card.height - card.contentMargin + 0.5;
    }

    function setSections(value) {
        card.showCpu = value;
        card.showMemory = value;
        card.showTemperature = value;
        card.showNetwork = value;
        card.showDiskIo = value;
        card.showFilesystems = value;
        card.showProcesses = value;
        card.showGpu = value;
    }

    function resetPresentation() {
        card.showHeader = true;
        setSections(true);
        card.showMetricIcons = true;
        card.showSectionLabels = true;
        card.showCpuProgressBar = true;
        card.showMemoryProgressBar = true;
        card.showFilesystemProgressBars = true;
        card.showProcessCpu = true;
        card.showProcessMemory = true;
        card.showGpuUtilization = true;
        card.showGpuMemory = true;
        card.showGpuTemperature = true;
        card.showGpuProgressBars = true;
        card.showGraphs = true;
        card.showCpuGraph = true;
        card.showMemoryGraph = true;
        card.showGpuGraph = true;
        card.showNetworkGraph = true;
        card.historySampleCount = 60;
        card.showNetworkRx = true;
        card.showNetworkTx = true;
        card.showDiskRead = true;
        card.showDiskWrite = true;
        card.compactSpacing = false;
        card.denseMode = false;
        card.widgetTitle = "TTop Desk";
        card.backgroundOpacity = 1.0;
        card.usePlasmaThemeBackground = true;
    }

    function configure(name) {
        resetPresentation();
        if (name === "systemTitle") {
            card.widgetTitle = "System Monitor";
        } else if (name === "longTitle") {
            card.widgetTitle = "A very long custom system monitor title that must never resize the card";
        } else if (name === "onlyCpu") {
            setSections(false); card.showHeader = false; card.showCpu = true;
        } else if (name === "onlyProcesses") {
            setSections(false); card.showHeader = false; card.showProcesses = true;
        } else if (name === "cpuRam") {
            setSections(false); card.showHeader = false; card.showCpu = true; card.showMemory = true;
        } else if (name === "headerOnly") {
            setSections(false);
        } else if (name === "headerDisabled") {
            card.showHeader = false;
        } else if (name === "noProcesses") {
            card.showProcesses = false;
        } else if (name === "noFilesystems") {
            card.showFilesystems = false;
        } else if (name === "iconsDisabled") {
            card.showMetricIcons = false;
        } else if (name === "progressDisabled") {
            card.showCpuProgressBar = false;
            card.showMemoryProgressBar = false;
            card.showFilesystemProgressBars = false;
            card.showGpuProgressBars = false;
        } else if (name === "processNameOnly") {
            card.showProcessCpu = false;
            card.showProcessMemory = false;
        } else if (name === "subElements") {
            card.showNetworkRx = false;
            card.showNetworkTx = true;
            card.showDiskRead = false;
            card.showDiskWrite = true;
            card.showProcessCpu = true;
            card.showProcessMemory = false;
        } else if (name === "labelsDisabled") {
            card.showSectionLabels = false;
        } else if (name === "dense") {
            card.compactSpacing = true;
            card.denseMode = true;
        } else if (name === "gpuDisabled") {
            card.showGpu = false;
        } else if (name === "onlyGpu") {
            setSections(false); card.showHeader = false; card.showGpu = true;
        } else if (name === "gpuUtilizationOnly") {
            setSections(false); card.showHeader = false; card.showGpu = true;
            card.showGpuMemory = false; card.showGpuTemperature = false;
        } else if (name === "gpuMemoryOnly") {
            setSections(false); card.showHeader = false; card.showGpu = true;
            card.showGpuUtilization = false; card.showGpuTemperature = false;
        } else if (name === "gpuTemperatureOnly") {
            setSections(false); card.showHeader = false; card.showGpu = true;
            card.showGpuUtilization = false; card.showGpuMemory = false;
        } else if (name === "gpuNoBars") {
            setSections(false); card.showHeader = false; card.showGpu = true;
            card.showGpuProgressBars = false;
        } else if (name === "processesGpu") {
            setSections(false); card.showHeader = false;
            card.showProcesses = true; card.showGpu = true;
        } else if (name === "filesystemsGpu") {
            setSections(false); card.showHeader = false;
            card.showFilesystems = true; card.showGpu = true;
        } else if (name === "allHidden") {
            setSections(false); card.showHeader = false;
        } else if (name === "appearance") {
            card.usePlasmaThemeBackground = false;
            card.customBackgroundColor = "#123456";
            card.backgroundOpacity = 0.5;
        } else if (name === "graphsDisabled") {
            card.showGraphs = false;
        } else if (name === "cpuGraphOnly") {
            setSections(false); card.showHeader = false; card.showCpu = true;
            card.showMemoryGraph = false; card.showGpuGraph = false;
            card.showNetworkGraph = false;
        } else if (name === "networkGraphOnly") {
            setSections(false); card.showHeader = false; card.showNetwork = true;
            card.showCpuGraph = false; card.showMemoryGraph = false;
            card.showGpuGraph = false;
        } else if (name === "history30") {
            card.historySampleCount = 30;
        } else if (name === "history60") {
            card.historySampleCount = 60;
        } else if (name === "history120") {
            card.historySampleCount = 120;
        }
    }

    function check(name) {
        var cpu = findByObjectName(card, "cpuSection");
        var memory = findByObjectName(card, "memorySection");
        var filesystem = findByObjectName(card, "filesystemSection");
        var processes = findByObjectName(card, "processSection");
        var gpu = findByObjectName(card, "gpuSection");
        var header = findByObjectName(card, "headerSection");
        if (name === "all") {
            allHeight = card.implicitHeight;
            allWidth = card.implicitWidth;
            if (!cpu.visible || !memory.visible || !filesystem.visible
                    || !processes.visible || !gpu.visible) {
                fail("default sections are not all visible");
            }
            if (!bottomInsideCard(filesystem) || !bottomInsideCard(processes)
                    || !bottomInsideCard(gpu)) {
                fail("default rows exceed card bounds");
            }
            if (findByObjectName(card, "gpuName").width > gpu.width) {
                fail("long GPU name exceeded section width");
            }
        } else if (name === "systemTitle") {
            if (findByObjectName(card, "widgetTitleLabel").text !== "System Monitor") {
                fail("live widget title did not update");
            }
        } else if (name === "longTitle") {
            if (card.implicitWidth !== allWidth) fail("long title expanded card width");
            var title = findByObjectName(card, "widgetTitleLabel");
            if (title.width > card.width) fail("title exceeded card width");
        } else if (name === "onlyCpu") {
            if (!cpu.visible || memory.visible || filesystem.visible || processes.visible) {
                fail("only-CPU visibility is incorrect");
            }
            if (card.implicitHeight >= allHeight) fail("only-CPU card did not shrink");
        } else if (name === "onlyProcesses") {
            if (!processes.visible || cpu.visible || filesystem.visible) {
                fail("only-processes visibility is incorrect");
            }
            if (!bottomInsideCard(processes)) fail("process-only rows exceed card");
        } else if (name === "cpuRam") {
            if (!cpu.visible || !memory.visible || processes.visible || filesystem.visible) {
                fail("CPU + RAM visibility is incorrect");
            }
        } else if (name === "headerOnly") {
            if (!header.visible || cpu.visible || processes.visible) fail("header-only state is incorrect");
            if (card.implicitHeight >= allHeight) fail("header-only card did not shrink");
        } else if (name === "headerDisabled") {
            if (header.visible || findByObjectName(card, "headerSeparator").visible) {
                fail("hidden header left content behind");
            }
            if (card.implicitHeight >= allHeight) fail("hidden header retained layout height");
        } else if (name === "noProcesses") {
            if (processes.visible || card.implicitHeight >= allHeight) fail("process section retained height");
        } else if (name === "noFilesystems") {
            if (filesystem.visible || card.implicitHeight >= allHeight) fail("filesystem section retained height");
            if (!bottomInsideCard(processes)) fail("process rows exceed card without filesystems");
        } else if (name === "iconsDisabled") {
            if (findByObjectName(card, "headerIcon").visible) fail("header icon remained visible");
        } else if (name === "progressDisabled") {
            if (visibleObjectCount(card, "metricProgressBar") !== 0
                    || visibleObjectCount(card, "filesystemProgressBar") !== 0) {
                fail("disabled progress bar remained visible");
            }
            if (!bottomInsideCard(filesystem)) fail("filesystem rows exceed card without bars");
        } else if (name === "processNameOnly") {
            if (visibleObjectCount(card, "processCpu") !== 0
                    || visibleObjectCount(card, "processMemory") !== 0
                    || visibleObjectCount(card, "processName") === 0) {
                fail("process name-only layout is incorrect");
            }
        } else if (name === "subElements") {
            if (findByObjectName(card, "networkSection").showRx
                    || !findByObjectName(card, "networkSection").showTx
                    || findByObjectName(card, "diskIoSection").showRead
                    || !findByObjectName(card, "diskIoSection").showWrite) {
                fail("throughput detail visibility is incorrect");
            }
        } else if (name === "labelsDisabled") {
            if (cpu.showLabel || findByObjectName(card, "networkSection").showLabel) {
                fail("section labels remained enabled");
            }
        } else if (name === "dense") {
            if (card.implicitHeight > allHeight) fail("dense spacing increased card height");
        } else if (name === "gpuDisabled") {
            if (gpu.visible || card.implicitHeight >= allHeight) fail("GPU section retained height");
        } else if (name === "onlyGpu") {
            if (!gpu.visible || cpu.visible || processes.visible || filesystem.visible) {
                fail("only-GPU visibility is incorrect");
            }
            if (!bottomInsideCard(gpu)) fail("GPU-only content exceeds card");
        } else if (name === "gpuUtilizationOnly") {
            if (!gpu.showUtilization || gpu.showMemory || gpu.showTemperature) {
                fail("GPU utilization-only layout is incorrect");
            }
        } else if (name === "gpuMemoryOnly") {
            if (gpu.showUtilization || !gpu.showMemory || gpu.showTemperature) {
                fail("GPU memory-only layout is incorrect");
            }
        } else if (name === "gpuTemperatureOnly") {
            if (gpu.showUtilization || gpu.showMemory || !gpu.showTemperature) {
                fail("GPU temperature-only layout is incorrect");
            }
        } else if (name === "gpuNoBars") {
            if (visibleObjectCount(card, "gpuUtilizationProgressBar") !== 0
                    || visibleObjectCount(card, "gpuMemoryProgressBar") !== 0) {
                fail("disabled GPU progress bars remained visible");
            }
        } else if (name === "processesGpu") {
            if (!processes.visible || !gpu.visible || !bottomInsideCard(processes)) {
                fail("processes + GPU layout is incorrect");
            }
        } else if (name === "filesystemsGpu") {
            if (!filesystem.visible || !gpu.visible || !bottomInsideCard(filesystem)) {
                fail("filesystems + GPU layout is incorrect");
            }
        } else if (name === "allHidden") {
            var content = findByObjectName(card, "fullContent");
            if (content.implicitHeight !== 0) fail("hidden sections retained content height");
            if (card.implicitHeight !== card.contentMargin * 2) fail("empty card height is not margin-only");
        } else if (name === "appearance") {
            if (Math.abs(card.color.a - 0.5) > 0.01) fail("background opacity was not applied");
        } else if (name === "graphsDisabled") {
            if (visibleObjectCount(card, "metricSparkline") !== 0
                    || visibleObjectCount(card, "gpuSparkline") !== 0
                    || visibleObjectCount(card, "networkSparkline") !== 0) {
                fail("disabled graphs retained visible canvas height");
            }
            if (card.implicitHeight >= allHeight) fail("disabled graphs did not shrink card");
        } else if (name === "cpuGraphOnly") {
            if (visibleObjectCount(card, "metricSparkline") !== 1
                    || !bottomInsideCard(cpu)) {
                fail("CPU-only graph layout is incorrect");
            }
        } else if (name === "networkGraphOnly") {
            var network = findByObjectName(card, "networkSection");
            if (visibleObjectCount(card, "networkSparkline") !== 1
                    || !bottomInsideCard(network)) {
                fail("network-only graph layout is incorrect");
            }
        } else if (name === "history30" || name === "history60"
                   || name === "history120") {
            var expectedHistory = Number(name.replace("history", ""));
            if (card.historySampleCount !== expectedHistory) {
                fail("history length did not update live");
            }
        }
        if (card.implicitWidth !== allWidth) fail("configuration changed stable card width");
    }

    ListModel {
        id: filesystemModel
        ListElement { mountPath: "/"; displayText: "20 GiB / 100 GiB  ·  20.0%"; percent: 20 }
        ListElement { mountPath: "/data"; displayText: "100 GiB / 200 GiB  ·  50.0%"; percent: 50 }
    }

    QtObject {
        id: metrics
        property bool cpuAvailable: true
        property real cpuPercent: 20
        property string cpuState: "available"
        property string memoryDisplayText: "40.0%  ·  6.4 GiB / 16.0 GiB"
        property real memoryPercent: 40
        property string memoryState: "available"
        property string temperatureDisplayText: "55.0 °C"
        property string temperatureState: "available"
        property string temperatureSeverity: "normal"
        property string networkRxDisplayText: "1.0 MiB/s"
        property string networkTxDisplayText: "512 KiB/s"
        property real networkRxBytesPerSecond: 1048576
        property real networkTxBytesPerSecond: 524288
        property string networkState: "available"
        property string diskReadDisplayText: "2.0 MiB/s"
        property string diskWriteDisplayText: "1.0 MiB/s"
        property string diskIoState: "available"
        property bool filesystemAvailable: true
        property string filesystemState: "available"
        property var filesystemEntries: filesystemModel
    }

    QtObject {
        id: backend
        property string backendState: "connected"
        property string gpuState: "available"
        property string gpuName: "NVIDIA GeForce Extremely Long Model Name That Must Elide Safely"
        property real gpuUtilizationPercent: 8
        property real gpuMemoryPercent: 25
        property string gpuMemoryDisplayText: "2.0 GiB / 8.0 GiB  ·  25.0%"
        property string gpuTemperatureDisplayText: "47.0 °C"
        property int processCount: processEntries.length
        property var processEntries: [
            { "pid": 1, "name": "very-long-process-name-that-must-elide", "cpuPercent": 12.3, "memoryBytes": 500000000 },
            { "pid": 2, "name": "plasmashell", "cpuPercent": 5.0, "memoryBytes": 300000000 },
            { "pid": 3, "name": "codex", "cpuPercent": 2.0, "memoryBytes": 200000000 }
        ]
    }

    Ui.FullRepresentation {
        id: card
        metricsProvider: metrics
        backendProvider: backend
        historyProvider: history
        width: implicitWidth
        height: implicitHeight
    }

    QtObject {
        id: history
        property var cpuValues: [10, 15, 20]
        property var memoryValues: [35, 38, 40]
        property var gpuValues: [3, 5, 8]
        property var networkRxValues: [524288, 786432, 1048576]
        property var networkTxValues: [262144, 393216, 524288]
    }

    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            probe.check(probe.cases[probe.caseIndex]);
            ++probe.caseIndex;
            if (probe.caseIndex >= probe.cases.length) {
                stop();
                console.log("TTop Desk configuration layout probe: PASS; "
                            + probe.cases.length + " configurations; width="
                            + card.implicitWidth + " allHeight=" + probe.allHeight);
                Qt.quit();
                return;
            }
            probe.configure(probe.cases[probe.caseIndex]);
        }
    }

    Component.onCompleted: configure(cases[0])
}

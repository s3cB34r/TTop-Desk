/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Window 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import "../../package/contents/ui" as Ui

Rectangle {
    id: harness

    property string scenarioName: "full-default"
    property string outputPath: "capture.png"
    property real representationWidthOverride: 0
    readonly property bool compactScenario: scenarioName.indexOf("compact-") === 0
    readonly property int captureMargin: PlasmaCore.Units.smallSpacing
    readonly property Item representation: representationLoader.item

    width: representation !== null
           ? Math.ceil(Math.max(representation.implicitWidth, representationWidthOverride))
             + captureMargin * 2 : 320
    height: representation !== null ? Math.ceil(representation.implicitHeight) + captureMargin * 2 : 640
    color: PlasmaCore.Theme.backgroundColor

    function fail(message) {
        console.error("TTop Desk visual capture: FAIL: " + message);
        Qt.exit(1);
    }

    function isKnownScenario(name) {
        return ["full-default", "minimal", "process-focused", "graphs-off",
                "compact-default", "compact-graph", "backend-unavailable",
                "gpu-unavailable"].indexOf(name) !== -1;
    }

    Component.onCompleted: {
        if (!isKnownScenario(scenarioName)) fail("unknown scenario " + scenarioName);
    }

    ListModel {
        id: filesystemModel
        ListElement { mountPath: "/"; displayText: "28.0 GiB / 120.0 GiB"; percent: 23.3 }
        ListElement { mountPath: "/home"; displayText: "310.0 GiB / 800.0 GiB"; percent: 38.8 }
        ListElement { mountPath: "/data"; displayText: "1.2 TiB / 2.0 TiB"; percent: 60.0 }
    }

    QtObject {
        id: metrics
        property bool cpuAvailable: true
        property real cpuPercent: 24.7
        property string cpuState: "available"
        property string memoryDisplayText: "41.2%  ·  6.6 GiB / 16.0 GiB"
        property real memoryPercent: 41.2
        property string memoryState: "available"
        property string temperatureDisplayText: "54.0 °C"
        property string temperatureState: "available"
        property string temperatureSeverity: "normal"
        property string networkRxDisplayText: "1.8 MiB/s"
        property string networkTxDisplayText: "420 KiB/s"
        property real networkRxBytesPerSecond: 1887436.8
        property real networkTxBytesPerSecond: 430080
        property string networkState: "available"
        property string diskReadDisplayText: "3.2 MiB/s"
        property string diskWriteDisplayText: "1.1 MiB/s"
        property string diskIoState: "available"
        property bool filesystemAvailable: true
        property string filesystemState: "available"
        property var filesystemEntries: filesystemModel
    }

    QtObject {
        id: backend
        property string backendState: harness.scenarioName === "backend-unavailable"
                                      ? "unavailable" : "connected"
        property string gpuState: harness.scenarioName === "gpu-unavailable"
                                  ? "unavailable"
                                  : harness.scenarioName === "backend-unavailable"
                                    ? "detecting" : "available"
        property string gpuName: "NVIDIA GeForce RTX 4070"
        property real gpuUtilizationPercent: gpuState === "available" ? 36.4 : NaN
        property real gpuMemoryPercent: gpuState === "available" ? 28.6 : NaN
        property string gpuMemoryDisplayText: gpuState === "available"
                                               ? "3.4 GiB / 12.0 GiB  ·  28.6%" : ""
        property string gpuTemperatureDisplayText: gpuState === "available" ? "49.0 °C" : ""
        property var processEntries: backendState === "connected" ? fixedProcesses : []
        property int processCount: processEntries.length
        readonly property var fixedProcesses: [
            { "pid": 1842, "name": "plasmashell", "cpuPercent": 8.2, "memoryBytes": 482344960 },
            { "pid": 2217, "name": "systemsettings", "cpuPercent": 5.7, "memoryBytes": 1673527296 },
            { "pid": 913, "name": "kwin_x11", "cpuPercent": 3.1, "memoryBytes": 301989888 },
            { "pid": 2740, "name": "konsole", "cpuPercent": 1.8, "memoryBytes": 356515840 },
            { "pid": 1, "name": "systemd", "cpuPercent": 0.2, "memoryBytes": 25165824 }
        ]
    }

    QtObject {
        id: history
        property var cpuValues: [18, 21, 19, 27, 31, 29, 24.7]
        property var memoryValues: [38, 38.4, 39, 39.7, 40.1, 40.8, 41.2]
        property var gpuValues: [12, 17, 28, 25, 31, 42, 36.4]
        property var networkRxValues: [420000, 890000, 1200000, 780000, 1500000, 2100000, 1887436]
        property var networkTxValues: [140000, 190000, 260000, 220000, 350000, 390000, 430080]
    }

    Loader {
        id: representationLoader
        anchors.centerIn: parent
        sourceComponent: harness.compactScenario ? compactComponent : fullComponent
    }

    Component {
        id: fullComponent

        Ui.FullRepresentation {
            metricsProvider: metrics
            backendProvider: backend
            historyProvider: history
            width: harness.representationWidthOverride > 0
                   ? harness.representationWidthOverride : implicitWidth
            height: implicitHeight
            showCpu: true
            showMemory: true
            showTemperature: harness.scenarioName !== "minimal"
                             && harness.scenarioName !== "process-focused"
            showNetwork: harness.scenarioName !== "minimal"
                         && harness.scenarioName !== "process-focused"
            showDiskIo: harness.scenarioName !== "minimal"
                        && harness.scenarioName !== "process-focused"
            showFilesystems: harness.scenarioName !== "minimal"
                             && harness.scenarioName !== "process-focused"
            showProcesses: harness.scenarioName !== "minimal"
            showGpu: harness.scenarioName !== "minimal"
                     && harness.scenarioName !== "process-focused"
            showGraphs: harness.scenarioName !== "graphs-off"
            widgetTitle: "TTop Desk"
        }
    }

    Component {
        id: compactComponent

        Ui.CompactRepresentation {
            width: implicitWidth
            height: implicitHeight
            metricsProvider: metrics
            backendProvider: backend
            historyProvider: history
            showCpu: true
            showMemory: true
            showNetwork: true
            showTemperature: true
            showGpu: true
            showCompactGraphs: harness.scenarioName === "compact-graph"
            compactGraphMetric: "cpu"
            formFactor: PlasmaCore.Types.Horizontal
        }
    }

    Timer {
        interval: 350
        running: harness.outputPath !== "" && harness.representation !== null
        repeat: false
        onTriggered: {
            harness.grabToImage(function(result) {
                if (!result.saveToFile(harness.outputPath)) {
                    harness.fail("could not save " + harness.outputPath);
                    return;
                }
                console.log("TTop Desk visual capture: PASS: " + harness.scenarioName
                            + " logical=" + harness.width + "x" + harness.height
                            + " DPR=" + Math.max(1, Screen.devicePixelRatio || 1));
                Qt.quit();
            });
        }
    }
}

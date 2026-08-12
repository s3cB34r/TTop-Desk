/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import "../package/contents/ui" as Ui

Item {
    id: probe
    width: 800
    height: 500

    function fail(message) {
        console.error("TTop Desk compact graph probe: FAIL: " + message);
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

    QtObject {
        id: metrics
        property string cpuState: "available"
        property real cpuPercent: 25
        property string memoryState: "available"
        property real memoryPercent: 40
        property string memoryDisplayText: "40%"
        property string networkState: "available"
        property string networkRxDisplayText: "1 MiB/s"
        property string networkTxDisplayText: "512 KiB/s"
        property string temperatureState: "available"
        property string temperatureDisplayText: "45 °C"
    }

    QtObject {
        id: backend
        property string backendState: "connected"
        property string gpuState: "available"
        property string gpuName: "NVIDIA Test GPU"
        property real gpuUtilizationPercent: 10
    }

    QtObject {
        id: history
        property var cpuValues: [10, 20, 25]
        property var memoryValues: [35, 38, 40]
        property var gpuValues: [4, 8, 10]
        property var networkRxValues: [100, 200, 300]
        property var networkTxValues: [300, 200, 100]
    }

    Ui.CompactRepresentation {
        id: compact
        width: implicitWidth
        height: implicitHeight
        metricsProvider: metrics
        backendProvider: backend
        historyProvider: history
        formFactor: PlasmaCore.Types.Planar
    }

    function runProbe() {
        var graph = findByObjectName(compact, "compactSparkline");
        var baselineWidth = compact.implicitWidth;
        var baselineHeight = compact.implicitHeight;
        if (graph.visible) {
            fail("compact graph changed the default compact view");
            return;
        }
        compact.showCompactGraphs = true;
        for (var index = 0; index < 4; ++index) {
            compact.compactGraphMetric = ["cpu", "memory", "gpu", "network"][index];
            if (!graph.visible || graph.height < 12 || graph.height > 20
                    || compact.implicitWidth !== baselineWidth
                    || compact.implicitHeight !== baselineHeight) {
                fail("compact graph metric changed panel dimensions or failed to display");
                return;
            }
        }
        compact.showGpu = false;
        compact.compactGraphMetric = "gpu";
        if (graph.visible || compact.effectiveCompactGraphMetric !== "gpu") {
            fail("disabled GPU did not hide while retaining selection");
            return;
        }
        compact.showGpu = true;
        backend.gpuState = "unavailable";
        if (graph.visible) {
            fail("unavailable GPU displayed stale compact history");
            return;
        }
        compact.compactGraphMetric = "invalid";
        if (compact.effectiveCompactGraphMetric !== "cpu" || !graph.visible) {
            fail("invalid compact metric did not fall back to CPU");
            return;
        }
        compact.width = PlasmaCore.Units.gridUnit * 3;
        if (graph.visible) {
            fail("compact graph did not hide at insufficient width");
            return;
        }
        console.log("TTop Desk compact graph probe: PASS; width="
                    + baselineWidth + " height=" + baselineHeight);
        Qt.quit();
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: runProbe()
    }
}

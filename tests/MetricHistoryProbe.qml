/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    function fail(message) {
        console.error("TTop Desk metric history probe: FAIL: " + message);
        Qt.exit(1);
    }

    QtObject {
        id: metrics
        property bool cpuAvailable: true
        property real cpuPercent: 10
        property string memoryState: "available"
        property real memoryPercent: 20
        property string networkState: "available"
        property real networkRxBytesPerSecond: 1000
        property real networkTxBytesPerSecond: 2000
    }

    QtObject {
        id: backend
        property string gpuState: "available"
        property real gpuUtilizationPercent: 30
    }

    Ui.MetricHistory {
        id: history
        metricsProvider: metrics
        backendProvider: backend
        maximumSamples: 30
    }

    function runProbe() {
        if (history.cpuValues.length !== 1 || history.memoryValues.length !== 1
                || history.gpuValues.length !== 1
                || history.networkRxValues.length !== 1
                || history.networkTxValues.length !== 1) {
            fail("initial normalized values were not sampled once");
            return;
        }
        metrics.cpuPercent = 11;
        metrics.memoryPercent = 21;
        metrics.networkRxBytesPerSecond = 3000;
        metrics.networkTxBytesPerSecond = 4000;
        backend.gpuUtilizationPercent = 31;
        if (history.cpuValues.length !== 2 || history.memoryValues.length !== 2
                || history.gpuValues.length !== 2
                || history.networkRxValues.length !== 2
                || history.networkTxValues.length !== 2) {
            fail("metric property updates did not append exactly once");
            return;
        }
        var nativeCount = history.cpuValues.length;
        backend.gpuState = "unavailable";
        backend.gpuUtilizationPercent = NaN;
        if (history.gpuValues.length !== 0 || history.cpuValues.length !== nativeCount) {
            fail("backend loss did not isolate GPU history from native history");
            return;
        }
        history.networkRxEnabled = false;
        if (history.networkRxValues.length !== 0
                || history.networkTxValues.length !== 2) {
            fail("RX visibility clearing affected the TX series");
            return;
        }
        console.log("TTop Desk metric history probe: PASS");
        Qt.quit();
    }

    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: runProbe()
    }
}

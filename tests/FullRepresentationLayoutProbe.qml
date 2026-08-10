/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    id: probe
    width: 800
    height: 900

    property real heightWithProcesses: 0
    property real widthWithLongName: 0

    function fail(message) {
        console.error("TTop Desk layout probe: FAIL: " + message);
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

    function bottomInsideCard(item) {
        var bottom = item.mapToItem(card, 0, item.height);
        return bottom.y <= card.height - card.contentMargin + 0.5;
    }

    ListModel {
        id: filesystemModel
        ListElement {
            mountPath: "/data"
            displayText: "100 GiB / 200 GiB  ·  50.0%"
            percent: 50
        }
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
        property string gpuState: "unavailable"
        property string gpuName: ""
        property real gpuUtilizationPercent: NaN
        property real gpuMemoryPercent: NaN
        property string gpuMemoryDisplayText: ""
        property string gpuTemperatureDisplayText: ""
        property int processCount: processEntries.length
        property var processEntries: [
            { "pid": 1, "name": "an-intentionally-extremely-long-process-name-that-must-be-elided", "cpuPercent": 135.6, "memoryBytes": 1825361101 },
            { "pid": 2, "name": "plasmashell", "cpuPercent": 12.4, "memoryBytes": 440401920 },
            { "pid": 3, "name": "codex", "cpuPercent": 3.1, "memoryBytes": 325058560 },
            { "pid": 4, "name": "python3", "cpuPercent": 1.8, "memoryBytes": 125829120 },
            { "pid": 5, "name": "kwin_wayland", "cpuPercent": 0.7, "memoryBytes": 220200960 }
        ]
    }

    Ui.FullRepresentation {
        id: card
        metricsProvider: metrics
        backendProvider: backend
        width: implicitWidth
        height: implicitHeight
        showProcesses: true
        showGpu: false
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            var processSection = probe.findByObjectName(card, "processSection");
            var filesystemSection = probe.findByObjectName(card, "filesystemSection");
            if (processSection === null) probe.fail("process section not found");
            if (filesystemSection === null) probe.fail("filesystem section not found");
            if (!probe.bottomInsideCard(processSection)) probe.fail("process rows exceed card");
            if (!probe.bottomInsideCard(filesystemSection)) probe.fail("/data row exceeds card");
            probe.heightWithProcesses = card.implicitHeight;
            probe.widthWithLongName = card.implicitWidth;
            card.showProcesses = false;
            hiddenCheck.start();
        }
    }

    Timer {
        id: hiddenCheck
        interval: 100
        repeat: false
        onTriggered: {
            var processSection = probe.findByObjectName(card, "processSection");
            if (card.implicitHeight >= probe.heightWithProcesses) {
                probe.fail("hidden process section did not release height");
            }
            if (card.implicitWidth !== probe.widthWithLongName) {
                probe.fail("long process name changed card width");
            }
            if (processSection.visible) probe.fail("process section remained visible");
            card.showProcesses = true;
            visibleCheck.start();
        }
    }

    Timer {
        id: visibleCheck
        interval: 100
        repeat: false
        onTriggered: {
            var processSection = probe.findByObjectName(card, "processSection");
            if (card.implicitHeight !== probe.heightWithProcesses) {
                probe.fail("process height was not restored deterministically");
            }
            if (!probe.bottomInsideCard(processSection)) probe.fail("restored rows exceed card");
            console.log("TTop Desk layout probe: PASS; width=" + card.implicitWidth
                        + " height=" + card.implicitHeight);
            Qt.quit();
        }
    }
}

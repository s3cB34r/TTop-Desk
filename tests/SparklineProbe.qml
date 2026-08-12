/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui/components" as Components

Item {
    width: 200
    height: 100

    function fail(message) {
        console.error("TTop Desk sparkline probe: FAIL: " + message);
        Qt.exit(1);
    }

    Components.Sparkline {
        id: graph
        width: 160
        height: 24
        values: []
        secondaryValues: []
        showSecondary: true
        accessibleName: "Network history"
        accessibleDescription: "Receive solid, transmit dashed"
    }

    function runProbe() {
        if (graph.implicitHeight !== 24
                || graph.backingStoreSize.width !== Math.ceil(graph.width)
                || graph.backingStoreSize.height !== Math.ceil(graph.height)
                || graph.accessibleName !== "Network history") {
            fail("logical Canvas size or accessibility metadata is incorrect");
            return;
        }
        graph.values = [50];
        graph.secondaryValues = [25];
        graph.values = [50, 50, 50];
        graph.secondaryValues = [10, 20, 30];
        graph.width = 120;
        if (graph.backingStoreSize.width !== 120 || !graph.secondaryDashed) {
            fail("resize or dashed-series state is incorrect");
            return;
        }
        graph.backgroundColor = "#ffffff";
        graph.lineColor = "#ffffff";
        if (graph.contrastRatio(graph.effectiveLineColor,
                                graph.backgroundColor) < 2.5) {
            fail("light-background contrast fallback is insufficient");
            return;
        }
        graph.backgroundColor = "#000000";
        graph.lineColor = "#000000";
        if (graph.contrastRatio(graph.effectiveLineColor,
                                graph.backgroundColor) < 2.5) {
            fail("dark-background contrast fallback is insufficient");
            return;
        }
        console.log("TTop Desk sparkline probe: PASS; DPR="
                    + graph.devicePixelRatio + " backing="
                    + graph.backingStoreSize.width + "x" + graph.backingStoreSize.height);
        Qt.quit();
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: runProbe()
    }
}

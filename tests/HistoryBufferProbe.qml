/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    function fail(message) {
        console.error("TTop Desk history buffer probe: FAIL: " + message);
        Qt.exit(1);
    }

    Ui.HistoryBuffer { id: buffer; maximumSamples: 30 }

    function runProbe() {
        if (buffer.append(null) || buffer.append(undefined)
                || buffer.append(NaN) || buffer.append(Infinity)
                || buffer.append("12") || buffer.sampleCount !== 0) {
            fail("malformed samples were accepted");
            return;
        }
        for (var index = 0; index < 35; ++index) buffer.append(index);
        if (buffer.sampleCount !== 30 || buffer.values[0] !== 5
                || buffer.values[29] !== 34) {
            fail("oldest samples were not discarded at the bound");
            return;
        }
        buffer.maximumSamples = 120;
        for (index = 35; index < 130; ++index) buffer.append(index);
        if (buffer.sampleCount !== 120 || buffer.values[0] !== 10) {
            fail("120-sample bound is incorrect");
            return;
        }
        buffer.maximumSamples = 7;
        if (buffer.effectiveMaximumSamples !== 60 || buffer.sampleCount !== 60
                || buffer.values[0] !== 70) {
            fail("invalid maximum did not fall back and trim to 60");
            return;
        }
        buffer.clear();
        if (buffer.sampleCount !== 0) {
            fail("clear did not release samples");
            return;
        }
        console.log("TTop Desk history buffer probe: PASS");
        Qt.quit();
    }

    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: runProbe()
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui/ConfigurationUtils.js" as Configuration

Item {
    function fail(message) {
        console.error("TTop Desk configuration utils probe: FAIL: " + message);
        Qt.exit(1);
    }

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            if (Configuration.title("") !== "TTop Desk") fail("empty title fallback");
            if (Configuration.title("  System Monitor  ") !== "System Monitor") fail("title trim");
            if (Configuration.title("123456789012345678901234567890123456789012345").length !== 40) {
                fail("title maximum length");
            }
            if (Configuration.allowedInteger(-1, [500, 1000], 1000) !== 1000
                    || Configuration.allowedInteger(500, [500, 1000], 1000) !== 500) {
                fail("allowed integer validation");
            }
            if (Configuration.processSort("pid") !== "cpu"
                    || Configuration.processSort("memory") !== "memory") {
                fail("process sort validation");
            }
            if (Configuration.opacity(-5) !== 0.35
                    || Configuration.opacity(8) !== 1.0
                    || Configuration.opacity("broken") !== 1.0) {
                fail("opacity validation");
            }
            if (Configuration.color("invalid", "#abcdef") !== "#abcdef"
                    || Configuration.color(" #123456 ", "#abcdef") !== "#123456") {
                fail("color validation");
            }
            console.log("TTop Desk configuration utils probe: PASS");
            Qt.quit();
        }
    }
}

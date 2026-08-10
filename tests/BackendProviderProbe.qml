/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    function fail(message) {
        console.error("TTop Desk backend provider probe: FAIL: " + message);
        Qt.exit(1);
    }

    Ui.BackendProvider {
        id: provider
        enabled: false
        maximumProcessEntries: 3
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            provider.handleResponse(JSON.stringify({
                "version": 1,
                "timestamp": 1720000000.0,
                "processes": [
                    { "pid": 9, "name": "zeta", "cpuPercent": 135.6, "memoryBytes": 1073741824, "username": "private", "cmdline": ["never", "copy"] },
                    { "pid": 5, "name": "alpha", "cpuPercent": 10, "memoryBytes": 50 },
                    { "pid": 2, "name": "alpha", "cpuPercent": 10, "memoryBytes": 20 },
                    { "pid": 3, "name": "beta", "cpuPercent": 1, "memoryBytes": 10 },
                    { "pid": 4, "name": "warming-up", "memoryBytes": 10 }
                ],
                "gpu": null
            }));
            if (provider.backendState !== "connected") fail("response was not accepted");
            if (provider.processCount !== 3) fail("display limit was not enforced");
            if (provider.processEntries[0].pid !== 9
                    || provider.processEntries[1].pid !== 2
                    || provider.processEntries[2].pid !== 5) {
                fail("CPU/name/PID deterministic ordering is incorrect");
            }
            if (provider.processEntries[0].cpuPercent !== 135.6) {
                fail("CPU above 100 percent was changed");
            }
            if (provider.processEntries[0].username !== undefined
                    || provider.processEntries[0].cmdline !== undefined) {
                fail("private or unapproved fields crossed the provider boundary");
            }
            console.log("TTop Desk backend provider probe: PASS");
            Qt.quit();
        }
    }
}


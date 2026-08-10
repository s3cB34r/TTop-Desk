/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    function fail(message) {
        console.error("TTop Desk metrics configuration probe: FAIL: " + message);
        Qt.exit(1);
    }

    Ui.MetricsProvider {
        id: metrics
        refreshIntervalMs: -1
        filesystemRefreshIntervalMs: 123
        maximumFilesystemEntries: 99
    }

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            if (metrics.effectiveRefreshIntervalMs !== 1000
                    || metrics.effectiveFilesystemRefreshIntervalMs !== 15000
                    || metrics.effectiveMaximumFilesystemEntries !== 3) {
                fail("invalid values did not fall back to defaults");
            }
            metrics.refreshIntervalMs = 500;
            metrics.filesystemRefreshIntervalMs = 60000;
            metrics.maximumFilesystemEntries = 5;
            if (metrics.effectiveRefreshIntervalMs !== 500
                    || metrics.effectiveFilesystemRefreshIntervalMs !== 60000
                    || metrics.effectiveMaximumFilesystemEntries !== 5) {
                fail("allowed values did not apply live");
            }
            console.log("TTop Desk metrics configuration probe: PASS");
            Qt.quit();
        }
    }
}

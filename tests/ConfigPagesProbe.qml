/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15

Item {
    id: probe
    width: 800
    height: 800

    property var pages: [
        "../package/contents/ui/ConfigGeneral.qml"
    ]
    property int loadedPages: 0

    Repeater {
        model: probe.pages

        delegate: Loader {
            width: probe.width
            height: probe.height
            visible: false
            source: ""
            Component.onCompleted: setSource(Qt.resolvedUrl(modelData), {
                "cfg_widgetTitle": "TTop Desk",
                "cfg_showCpu": true
            })
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("TTop Desk config pages probe: FAIL loading " + source);
                    Qt.exit(1);
                }
                if (status === Loader.Ready) {
                    ++probe.loadedPages;
                    if (probe.loadedPages === probe.pages.length) {
                        console.log("TTop Desk config page probe: PASS");
                        quitTimer.start();
                    }
                }
            }
        }
    }

    Timer {
        id: quitTimer
        interval: 1
        onTriggered: Qt.quit()
    }
}

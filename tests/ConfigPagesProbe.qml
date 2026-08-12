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
        { "source": "../package/contents/ui/ConfigGeneral.qml",
          "mode": "en", "expected": "Show memory" },
        { "source": "../package/contents/ui/ConfigGeneral.qml",
          "mode": "de", "expected": "Arbeitsspeicher anzeigen" }
    ]
    property int loadedPages: 0

    function textExists(item, expected) {
        if (typeof item.text !== "undefined" && item.text === expected) return true;
        for (var index = 0; index < item.children.length; ++index) {
            if (textExists(item.children[index], expected)) return true;
        }
        return false;
    }

    Repeater {
        model: probe.pages

        delegate: Loader {
            width: probe.width
            height: probe.height
            visible: false
            source: ""
            Component.onCompleted: setSource(Qt.resolvedUrl(modelData.source), {
                "cfg_languageMode": modelData.mode,
                "cfg_widgetTitle": "TTop Desk",
                "cfg_showCpu": true
            })
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("TTop Desk config pages probe: FAIL loading " + source);
                    Qt.exit(1);
                }
                if (status === Loader.Ready) {
                    if (!probe.textExists(item, modelData.expected)) {
                        console.error("TTop Desk config pages probe: FAIL language "
                                      + modelData.mode);
                        Qt.exit(1);
                        return;
                    }
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

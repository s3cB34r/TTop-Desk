/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import org.kde.plasma.components 2.0 as PlasmaComponents
import "../../../../package/contents/ui" as Production

Item {
    width: 520
    height: 180

    property bool examplesLogged: false

    function logExamples() {
        if (examplesLogged || !processes.processAvailable) return;
        examplesLogged = true;
        console.log("TTop Desk process probe: state=" + processes.processState
                    + ", source=" + processes.selectedProcessSource
                    + ", structure=" + processes.selectedProcessStructure
                    + ", count=" + processes.processCount);
        var limit = Math.min(5, processes.processEntries.length);
        for (var index = 0; index < limit; ++index) {
            console.log("TTop Desk process probe: example " + index + " "
                        + JSON.stringify(processes.processEntries[index]));
        }
    }

    Production.ProcessProvider {
        id: processes
        debugProcesses: true
        onProcessStateChanged: logExamples()
        onProcessCountChanged: logExamples()
    }

    PlasmaComponents.Label {
        anchors.fill: parent
        anchors.margins: 16
        wrapMode: Text.WordWrap
        text: "ProcessProvider development probe\n\nState: " + processes.processState
              + "\nSource: " + (processes.selectedProcessSource || "none")
              + "\nStructure: " + (processes.selectedProcessStructure || "unknown")
              + "\nNormalized processes: " + processes.processCount
              + (processes.lastError ? "\nResult: " + processes.lastError : "")
    }
}

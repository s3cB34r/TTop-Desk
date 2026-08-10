/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

RowLayout {
    id: row

    property int processPid: 0
    property string processName: ""
    property real cpuPercent: NaN
    property real memoryBytes: NaN

    spacing: PlasmaCore.Units.smallSpacing

    function memoryText(bytes) {
        if (!isFinite(bytes) || bytes < 0) return "—";
        var gibibyte = 1024 * 1024 * 1024;
        if (bytes >= gibibyte) return (bytes / gibibyte).toFixed(1) + " GiB";
        return Math.round(bytes / (1024 * 1024)) + " MiB";
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: row.processName
        color: PlasmaCore.Theme.textColor
        elide: Text.ElideRight
        Accessible.name: qsTr("Process %1").arg(row.processName)
    }

    PlasmaComponents.Label {
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 3.5
        Layout.maximumWidth: Layout.preferredWidth
        horizontalAlignment: Text.AlignRight
        text: isFinite(row.cpuPercent) ? row.cpuPercent.toFixed(1) + " %" : "—"
        color: PlasmaCore.Theme.highlightColor
        font.family: "monospace"
        elide: Text.ElideLeft
    }

    PlasmaComponents.Label {
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 4.2
        Layout.maximumWidth: Layout.preferredWidth
        horizontalAlignment: Text.AlignRight
        text: row.memoryText(row.memoryBytes)
        color: PlasmaCore.Theme.disabledTextColor
        font.family: "monospace"
        elide: Text.ElideLeft
    }
}


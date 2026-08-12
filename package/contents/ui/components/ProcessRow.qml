/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import "../TTop/Runtime"

RowLayout {
    id: row

    Layout.minimumWidth: 0

    property string languageMode: "en"
    property int processPid: 0
    property string processName: ""
    property real cpuPercent: NaN
    property real memoryBytes: NaN
    property bool showCpu: true
    property bool showMemory: true

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    spacing: PlasmaCore.Units.smallSpacing

    function memoryText(bytes) {
        if (!isFinite(bytes) || bytes < 0) return "—";
        var gibibyte = 1024 * 1024 * 1024;
        if (bytes >= gibibyte) return (bytes / gibibyte).toFixed(1) + " GiB";
        return Math.round(bytes / (1024 * 1024)) + " MiB";
    }

    PlasmaComponents.Label {
        objectName: "processName"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: row.processName
        color: PlasmaCore.Theme.textColor
        elide: Text.ElideRight
        Accessible.name: row.ttopTr("Process %1", [row.processName])
    }

    PlasmaComponents.Label {
        objectName: "processCpu"
        visible: row.showCpu
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 3.5
        Layout.maximumWidth: Layout.preferredWidth
        horizontalAlignment: Text.AlignRight
        text: isFinite(row.cpuPercent) ? row.cpuPercent.toFixed(1) + " %" : "—"
        color: PlasmaCore.Theme.highlightColor
        font.family: "monospace"
        elide: Text.ElideLeft
    }

    PlasmaComponents.Label {
        objectName: "processMemory"
        visible: row.showMemory
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 4.2
        Layout.maximumWidth: Layout.preferredWidth
        horizontalAlignment: Text.AlignRight
        text: row.memoryText(row.memoryBytes)
        color: PlasmaCore.Theme.disabledTextColor
        font.family: "monospace"
        elide: Text.ElideLeft
    }
}

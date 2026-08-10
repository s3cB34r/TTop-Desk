/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore

ColumnLayout {
    id: processList

    property var backendProvider
    property bool showIcon: true

    spacing: PlasmaCore.Units.smallSpacing

    function statusText() {
        if (backendProvider.backendState === "detecting") return qsTr("Detecting…");
        if (backendProvider.backendState === "unavailable") return qsTr("Backend unavailable");
        if (backendProvider.backendState === "error") return qsTr("Backend error");
        return backendProvider.processCount === 0 ? qsTr("No process data") : "";
    }

    SectionHeader {
        Layout.fillWidth: true
        title: qsTr("TOP PROCESSES")
        iconName: "view-process-all"
        showIcon: processList.showIcon
        statusText: processList.statusText()
    }

    Repeater {
        model: processList.backendProvider.processEntries

        delegate: ProcessRow {
            Layout.fillWidth: true
            processPid: modelData.pid
            processName: modelData.name
            cpuPercent: modelData.cpuPercent
            memoryBytes: modelData.memoryBytes === undefined ? NaN : modelData.memoryBytes
        }
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import "../TTop/Runtime"

ColumnLayout {
    id: processList

    Layout.minimumWidth: 0

    property string languageMode: "en"
    property var backendProvider
    property bool showIcon: true
    property bool showLabel: true
    property bool showCpu: true
    property bool showMemory: true
    property bool denseMode: false

    spacing: denseMode ? 0 : PlasmaCore.Units.smallSpacing

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    function statusText() {
        if (backendProvider.backendState === "detecting") return ttopTr("Detecting…");
        if (backendProvider.backendState === "unavailable") return ttopTr("Backend unavailable");
        if (backendProvider.backendState === "error") return ttopTr("Backend error");
        return backendProvider.processCount === 0 ? ttopTr("No process data") : "";
    }

    SectionHeader {
        Layout.fillWidth: true
        title: processList.ttopTr("TOP PROCESSES")
        iconName: "view-process-all"
        showIcon: processList.showIcon
        showLabel: processList.showLabel
        statusText: processList.statusText()
    }

    Repeater {
        model: processList.backendProvider.processEntries

        delegate: ProcessRow {
            languageMode: processList.languageMode
            Layout.fillWidth: true
            processPid: modelData.pid
            processName: modelData.name
            cpuPercent: modelData.cpuPercent === undefined ? NaN : modelData.cpuPercent
            memoryBytes: modelData.memoryBytes === undefined ? NaN : modelData.memoryBytes
            showCpu: processList.showCpu
            showMemory: processList.showMemory
        }
    }
}

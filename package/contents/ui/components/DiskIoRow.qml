/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import "../TTop/Runtime"

ColumnLayout {
    id: row

    Layout.minimumWidth: 0

    property string languageMode: "en"
    property string readText: ""
    property string writeText: ""
    property string availabilityState: "loading"
    property bool showIcon: true
    property bool showLabel: true
    property bool showRead: true
    property bool showWrite: true

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    readonly property bool available: availabilityState === "available"
    readonly property string statusText: availabilityState === "unavailable"
                                                   ? row.ttopTr("Unavailable")
                                                   : availabilityState === "loading"
                                                     ? row.ttopTr("Detecting…") : ""

    spacing: 0

    SectionHeader {
        Layout.fillWidth: true
        title: row.ttopTr("DISK I/O")
        iconName: "drive-harddisk"
        showIcon: row.showIcon
        showLabel: row.showLabel
        statusText: row.available ? "" : row.statusText
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: PlasmaCore.Units.largeSpacing
        visible: row.available

        PlasmaComponents.Label {
            visible: row.showRead
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.ttopTr("↓ READ  %1", [row.readText])
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            visible: row.showWrite
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.ttopTr("↑ WRITE  %1", [row.writeText])
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
}

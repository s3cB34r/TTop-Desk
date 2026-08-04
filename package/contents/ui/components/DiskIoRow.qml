/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

ColumnLayout {
    id: row

    property string readText: ""
    property string writeText: ""
    property string availabilityState: "loading"

    readonly property bool available: availabilityState === "available"
    readonly property string statusText: availabilityState === "unavailable"
                                                   ? "Unavailable"
                                                   : availabilityState === "loading"
                                                     ? "Detecting…" : ""

    spacing: 0

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: "DISK I/O"
            color: "#f5f5f5"
            font.bold: true
        }

        PlasmaComponents.Label {
            visible: !row.available
            text: row.statusText
            color: "#b8bcc2"
            font.family: "monospace"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: PlasmaCore.Units.largeSpacing
        visible: row.available

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: "↓ READ  " + row.readText
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: "↑ WRITE  " + row.writeText
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
}

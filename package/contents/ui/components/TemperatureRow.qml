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

    property string valueText: ""
    property string availabilityState: "loading"
    property string severity: "unknown"

    readonly property bool available: availabilityState === "available"
    readonly property string displayedValue: available
                                               ? valueText
                                               : availabilityState === "unavailable"
                                                 ? "Unavailable"
                                                 : "Detecting…"

    spacing: PlasmaCore.Units.smallSpacing

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: "TEMPERATURE"
        color: "#f5f5f5"
        font.bold: true
    }

    PlasmaComponents.Label {
        text: row.displayedValue
        color: row.available ? PlasmaCore.Theme.highlightColor : "#b8bcc2"
        font.family: "monospace"
    }
}

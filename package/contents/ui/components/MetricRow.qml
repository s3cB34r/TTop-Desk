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

    property string metricLabel: ""
    property string valueText: ""
    property real progressValue: 0
    // Supported states: "loading", "available", and "unavailable".
    property string availabilityState: "loading"

    readonly property bool available: availabilityState === "available"
    readonly property string displayedValue: available
                                               ? valueText
                                               : availabilityState === "unavailable"
                                                 ? "Unavailable"
                                                 : "Detecting…"

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: row.metricLabel
            color: "#f5f5f5"
        }

        PlasmaComponents.Label {
            Layout.maximumWidth: row.width * 0.78
            text: row.displayedValue
            color: row.available ? PlasmaCore.Theme.highlightColor : "#b8bcc2"
            elide: Text.ElideLeft
            horizontalAlignment: Text.AlignRight
            font.family: "monospace"
        }
    }

    PlasmaComponents.ProgressBar {
        Layout.fillWidth: true
        minimumValue: 0
        maximumValue: 100
        value: row.available && isFinite(row.progressValue)
               ? Math.max(0, Math.min(100, row.progressValue))
               : 0
        indeterminate: row.availabilityState === "loading"
        opacity: row.availabilityState === "unavailable" ? 0.45 : 1
    }
}

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

    property string mountPath: ""
    property string capacityText: ""
    property real percent: 0

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: row.mountPath
            color: "#f5f5f5"
            font.family: "monospace"
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            text: row.capacityText
            color: "#b8bcc2"
            font.family: "monospace"
        }

        PlasmaComponents.Label {
            text: isFinite(row.percent) ? row.percent.toFixed(1) + "%" : "Unavailable"
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
        }
    }

    PlasmaComponents.ProgressBar {
        Layout.fillWidth: true
        minimumValue: 0
        maximumValue: 100
        value: isFinite(row.percent) ? Math.max(0, Math.min(100, row.percent)) : 0
    }
}

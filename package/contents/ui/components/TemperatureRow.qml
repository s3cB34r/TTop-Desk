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
    property bool showIcon: true

    readonly property bool available: availabilityState === "available"
    readonly property string displayedValue: available
                                               ? valueText
                                               : availabilityState === "unavailable"
                                                 ? "Unavailable"
                                                 : "Detecting…"

    spacing: PlasmaCore.Units.smallSpacing

    PlasmaCore.IconItem {
        visible: row.showIcon
        source: "temperature-normal"
        Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
        Layout.preferredHeight: width
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: qsTr("TEMPERATURE")
        color: PlasmaCore.Theme.textColor
        font.bold: true
    }

    PlasmaComponents.Label {
        text: row.displayedValue
        color: row.available ? PlasmaCore.Theme.highlightColor
                             : PlasmaCore.Theme.disabledTextColor
        font.family: "monospace"
    }
}

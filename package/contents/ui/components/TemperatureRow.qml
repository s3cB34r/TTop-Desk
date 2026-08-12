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
    property string valueText: ""
    property string availabilityState: "loading"
    property string severity: "unknown"
    property bool showIcon: true
    property bool showLabel: true

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    readonly property bool available: availabilityState === "available"
    readonly property string displayedValue: available
                                               ? valueText
                                               : availabilityState === "unavailable"
                                                 ? row.ttopTr("Unavailable")
                                                 : row.ttopTr("Detecting…")

    spacing: PlasmaCore.Units.smallSpacing

    PlasmaCore.IconItem {
        visible: row.showIcon
        source: "temperature-normal"
        Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
        Layout.preferredHeight: width
    }

    PlasmaComponents.Label {
        visible: row.showLabel
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: row.ttopTr("TEMPERATURE")
        color: PlasmaCore.Theme.textColor
        font.bold: true
    }

    PlasmaComponents.Label {
        Layout.alignment: Qt.AlignRight
        Layout.minimumWidth: 0
        text: row.displayedValue
        color: row.available ? PlasmaCore.Theme.highlightColor
                             : PlasmaCore.Theme.disabledTextColor
        font.family: "monospace"
    }
}

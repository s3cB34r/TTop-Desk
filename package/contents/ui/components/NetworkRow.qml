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

    property string rxText: ""
    property string txText: ""
    property bool showIcon: true
    // Supported states: "loading", "available", and "unavailable".
    property string availabilityState: "loading"

    readonly property bool available: availabilityState === "available"
    readonly property string statusText: availabilityState === "unavailable"
                                                   ? "Unavailable"
                                                   : availabilityState === "loading"
                                                     ? "Detecting…" : ""

    spacing: 0

    SectionHeader {
        Layout.fillWidth: true
        title: qsTr("NETWORK")
        iconName: "network-wired"
        showIcon: row.showIcon
        statusText: row.available ? "" : row.statusText
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: PlasmaCore.Units.largeSpacing
        visible: row.available

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: "↓ RX  " + row.rxText
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: "↑ TX  " + row.txText
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
}

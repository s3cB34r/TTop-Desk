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
    property string rxText: ""
    property string txText: ""
    property bool showIcon: true
    property bool showLabel: true
    property bool showRx: true
    property bool showTx: true
    property bool showGraph: false
    property var rxHistory: []
    property var txHistory: []
    property string graphAccessibleName: ttopTr("Network receive and transmit history")
    property string graphDescription: ttopTr("Receive is solid; transmit is dashed")
    property string graphTooltip: ttopTr("RX solid · TX dashed · dynamically scaled")
    property color graphBackgroundColor: PlasmaCore.Theme.backgroundColor
    // Supported states: "loading", "available", and "unavailable".
    property string availabilityState: "loading"

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
        title: row.ttopTr("NETWORK")
        iconName: "network-wired"
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
            visible: row.showRx
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.ttopTr("↓ RX  %1", [row.rxText])
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            visible: row.showTx
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.ttopTr("↑ TX  %1", [row.txText])
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }

    Sparkline {
        languageMode: row.languageMode
        objectName: "networkSparkline"
        visible: row.available && row.showGraph && (row.showRx || row.showTx)
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        values: row.rxHistory
        secondaryValues: row.txHistory
        showPrimary: row.showRx
        showSecondary: row.showTx
        dynamicScale: true
        dynamicMinimumMaximum: 1024
        secondaryDashed: true
        accessibleName: row.graphAccessibleName
        accessibleDescription: row.graphDescription
        tooltipText: row.graphTooltip
        backgroundColor: row.graphBackgroundColor
    }
}

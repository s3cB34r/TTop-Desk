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

    property string languageMode: "en"
    property string metricLabel: ""
    property string iconName: ""
    property bool showIcon: true
    property bool showLabel: true
    property bool showProgressBar: true
    property bool showGraph: false
    property var graphValues: []
    property string graphAccessibleName: ttopTr("Metric history")
    property string graphDescription: ""
    property string graphTooltip: ""
    property color graphBackgroundColor: PlasmaCore.Theme.backgroundColor
    property string valueText: ""
    property real progressValue: 0
    // Supported states: "loading", "available", and "unavailable".
    property string availabilityState: "loading"

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    readonly property bool available: availabilityState === "available"
    readonly property string displayedValue: available
                                               ? valueText
                                               : availabilityState === "unavailable"
                                                 ? row.ttopTr("Unavailable")
                                                 : row.ttopTr("Detecting…")

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaCore.IconItem {
            visible: row.showIcon && row.iconName !== ""
            source: row.iconName
            Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
            Layout.preferredHeight: width
        }

        PlasmaComponents.Label {
            visible: row.showLabel
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.metricLabel
            color: PlasmaCore.Theme.textColor
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 0
            Layout.maximumWidth: row.width * 0.78
            text: row.displayedValue
            color: row.available ? PlasmaCore.Theme.highlightColor
                                 : PlasmaCore.Theme.disabledTextColor
            elide: Text.ElideLeft
            horizontalAlignment: Text.AlignRight
            font.family: "monospace"
        }
    }

    PlasmaComponents.ProgressBar {
        objectName: "metricProgressBar"
        visible: row.showProgressBar
        Layout.fillWidth: true
        minimumValue: 0
        maximumValue: 100
        value: row.available && isFinite(row.progressValue)
               ? Math.max(0, Math.min(100, row.progressValue))
               : 0
        indeterminate: row.availabilityState === "loading"
        opacity: row.availabilityState === "unavailable" ? 0.45 : 1
    }

    Sparkline {
        languageMode: row.languageMode
        objectName: "metricSparkline"
        visible: row.showGraph && row.available
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        values: row.graphValues
        minimumValue: 0
        maximumValue: 100
        accessibleName: row.graphAccessibleName
        accessibleDescription: row.graphDescription
        tooltipText: row.graphTooltip
        backgroundColor: row.graphBackgroundColor
    }
}

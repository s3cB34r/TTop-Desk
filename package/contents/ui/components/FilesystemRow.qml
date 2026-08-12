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
    property string mountPath: ""
    property string capacityText: ""
    property real percent: 0
    property bool showProgressBar: true

    function ttopTr(source, values) {
        return ttopTranslations.text(languageMode, source, values || []);
    }

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.mountPath
            color: PlasmaCore.Theme.textColor
            font.family: "monospace"
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            Layout.minimumWidth: 0
            text: row.capacityText
            color: PlasmaCore.Theme.disabledTextColor
            font.family: "monospace"
            elide: Text.ElideLeft
        }

        PlasmaComponents.Label {
            text: isFinite(row.percent) ? row.percent.toFixed(1) + "%" : row.ttopTr("Unavailable")
            color: PlasmaCore.Theme.highlightColor
            font.family: "monospace"
        }
    }

    PlasmaComponents.ProgressBar {
        objectName: "filesystemProgressBar"
        visible: row.showProgressBar
        Layout.fillWidth: true
        minimumValue: 0
        maximumValue: 100
        value: isFinite(row.percent) ? Math.max(0, Math.min(100, row.percent)) : 0
    }
}

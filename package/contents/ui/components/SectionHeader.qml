/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

RowLayout {
    id: header

    Layout.minimumWidth: 0

    property string title: ""
    property string iconName: ""
    property bool showIcon: true
    property bool showLabel: true
    property string statusText: ""

    spacing: PlasmaCore.Units.smallSpacing

    PlasmaCore.IconItem {
        visible: header.showIcon && header.iconName !== ""
        source: header.iconName
        Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
        Layout.preferredHeight: width
    }

    PlasmaComponents.Label {
        visible: header.showLabel
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: header.title
        color: PlasmaCore.Theme.textColor
        font.bold: true
        elide: Text.ElideRight
    }

    PlasmaComponents.Label {
        visible: header.statusText !== ""
        Layout.minimumWidth: 0
        text: header.statusText
        color: PlasmaCore.Theme.disabledTextColor
        font.family: "monospace"
        elide: Text.ElideLeft
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Milestone 1.0 intentionally uses static values. A future shared TTop Core
 * backend can replace this model without changing the presentation structure.
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    Plasmoid.switchWidth: PlasmaCore.Units.gridUnit * 12
    Plasmoid.switchHeight: PlasmaCore.Units.gridUnit * 9
    Plasmoid.compactRepresentation: compactRepresentation
    Plasmoid.fullRepresentation: fullRepresentation

    Component {
        id: compactRepresentation

        Item {
            implicitWidth: PlasmaCore.Units.gridUnit * 7
            implicitHeight: PlasmaCore.Units.gridUnit * 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: PlasmaCore.Units.smallSpacing
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaCore.IconItem {
                    source: "utilities-system-monitor"
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                    Layout.preferredHeight: width
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: "TTop Desk"
                    elide: Text.ElideRight
                }
            }
        }
    }

    Component {
        id: fullRepresentation

        Rectangle {
            id: card

            Layout.minimumWidth: PlasmaCore.Units.gridUnit * 12
            Layout.minimumHeight: PlasmaCore.Units.gridUnit * 9
            Layout.preferredWidth: PlasmaCore.Units.gridUnit * 16
            Layout.preferredHeight: PlasmaCore.Units.gridUnit * 13
            implicitWidth: Layout.preferredWidth
            implicitHeight: Layout.preferredHeight

            color: "#25282d"
            radius: PlasmaCore.Units.smallSpacing
            border.color: Qt.rgba(PlasmaCore.Theme.highlightColor.r,
                                  PlasmaCore.Theme.highlightColor.g,
                                  PlasmaCore.Theme.highlightColor.b, 0.45)
            border.width: 1

            ListModel {
                id: metricModel

                ListElement { metricName: "CPU"; metricValue: "-- %"; progress: 0 }
                ListElement { metricName: "RAM"; metricValue: "-- %"; progress: 0 }
                ListElement { metricName: "Network"; metricValue: "-- KiB/s"; progress: 0 }
                ListElement { metricName: "Temperature"; metricValue: "-- °C"; progress: 0 }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: PlasmaCore.Units.largeSpacing
                spacing: PlasmaCore.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: PlasmaCore.Units.smallSpacing

                    PlasmaCore.IconItem {
                        source: "utilities-system-monitor"
                        Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
                        Layout.preferredHeight: width
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: "TTop Desk"
                        color: "#f5f5f5"
                        font.bold: true
                        font.pointSize: PlasmaCore.Theme.defaultFont.pointSize + 2
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: PlasmaCore.Theme.highlightColor
                    opacity: 0.45
                }

                Repeater {
                    model: metricModel

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: metricName
                                color: "#f5f5f5"
                            }

                            PlasmaComponents.Label {
                                text: metricValue
                                color: PlasmaCore.Theme.highlightColor
                                font.family: "monospace"
                            }
                        }

                        PlasmaComponents.ProgressBar {
                            Layout.fillWidth: true
                            minimumValue: 0
                            maximumValue: 100
                            value: progress
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}

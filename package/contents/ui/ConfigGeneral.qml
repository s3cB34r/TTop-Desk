/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.15 as QtControls
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: configPage

    property alias cfg_showCpu: showCpuCheckBox.checked
    property alias cfg_showMemory: showMemoryCheckBox.checked
    property alias cfg_showNetwork: showNetworkCheckBox.checked
    property alias cfg_showTemperature: showTemperatureCheckBox.checked
    property alias cfg_showFilesystems: showFilesystemsCheckBox.checked
    property alias cfg_showDiskIo: showDiskIoCheckBox.checked
    property alias cfg_showHeader: showHeaderCheckBox.checked
    property alias cfg_showMetricIcons: showMetricIconsCheckBox.checked
    property alias cfg_compactModeDetails: compactDetailsCheckBox.checked
    property int cfg_refreshIntervalMs: 1000
    property alias cfg_filesystemRefreshIntervalMs: filesystemIntervalSpinBox.value
    property alias cfg_maximumFilesystemEntries: filesystemEntriesSpinBox.value

    function refreshIndex(value) {
        var options = [500, 1000, 2000, 5000];
        var index = options.indexOf(Number(value));
        return index >= 0 ? index : 1;
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Visible sections")
    }

    QtControls.CheckBox {
        id: showCpuCheckBox
        Kirigami.FormData.label: qsTr("Metrics:")
        text: qsTr("CPU usage")
    }

    QtControls.CheckBox {
        id: showMemoryCheckBox
        text: qsTr("Memory usage")
    }

    QtControls.CheckBox {
        id: showNetworkCheckBox
        text: qsTr("Network throughput")
    }

    QtControls.CheckBox {
        id: showTemperatureCheckBox
        text: qsTr("CPU temperature")
    }

    QtControls.CheckBox {
        id: showFilesystemsCheckBox
        text: qsTr("Filesystem capacity")
    }

    QtControls.CheckBox {
        id: showDiskIoCheckBox
        text: qsTr("Disk read/write throughput")
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Appearance")
    }

    QtControls.CheckBox {
        id: showHeaderCheckBox
        Kirigami.FormData.label: qsTr("Full view:")
        text: qsTr("Show widget header")
    }

    QtControls.CheckBox {
        id: showMetricIconsCheckBox
        text: qsTr("Show metric icons")
    }

    QtControls.CheckBox {
        id: compactDetailsCheckBox
        Kirigami.FormData.label: qsTr("Compact view:")
        text: qsTr("Show network and temperature details")
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: qsTr("Update intervals")
    }

    QtControls.ComboBox {
        id: refreshIntervalComboBox
        Kirigami.FormData.label: qsTr("Metrics:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        textRole: "label"
        valueRole: "milliseconds"
        model: [
            { "label": qsTr("500 ms"), "milliseconds": 500 },
            { "label": qsTr("1 second"), "milliseconds": 1000 },
            { "label": qsTr("2 seconds"), "milliseconds": 2000 },
            { "label": qsTr("5 seconds"), "milliseconds": 5000 }
        ]
        currentIndex: configPage.refreshIndex(configPage.cfg_refreshIntervalMs)
        onActivated: configPage.cfg_refreshIntervalMs = currentValue
        Accessible.name: qsTr("Normal metric refresh interval")
    }

    QtControls.SpinBox {
        id: filesystemIntervalSpinBox
        Kirigami.FormData.label: qsTr("Filesystems:")
        from: 5000
        to: 60000
        stepSize: 5000
        editable: true
        textFromValue: function(value) {
            return qsTr("%1 seconds").arg(value / 1000);
        }
        valueFromText: function(text) {
            var parsed = Number.fromLocaleString(Qt.locale(), text.replace(/[^0-9.,]/g, ""));
            return isFinite(parsed) ? Math.round(parsed * 1000) : 15000;
        }
        Accessible.name: qsTr("Filesystem refresh interval in seconds")
    }

    QtControls.SpinBox {
        id: filesystemEntriesSpinBox
        Kirigami.FormData.label: qsTr("Filesystem rows:")
        from: 1
        to: 10
        stepSize: 1
        editable: true
        Accessible.name: qsTr("Maximum displayed filesystem entries")
    }
}

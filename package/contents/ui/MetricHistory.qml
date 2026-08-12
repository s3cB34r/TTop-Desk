/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15

Item {
    id: history
    objectName: "metricHistory"

    property var metricsProvider
    property var backendProvider
    property int maximumSamples: 60
    property bool cpuEnabled: true
    property bool memoryEnabled: true
    property bool gpuEnabled: true
    property bool networkEnabled: true
    property bool networkRxEnabled: true
    property bool networkTxEnabled: true

    readonly property var cpuValues: cpuBuffer.values
    readonly property var memoryValues: memoryBuffer.values
    readonly property var gpuValues: gpuBuffer.values
    readonly property var networkRxValues: networkRxBuffer.values
    readonly property var networkTxValues: networkTxBuffer.values

    visible: false
    width: 0
    height: 0

    function appendCpu() {
        if (cpuEnabled && metricsProvider !== null && metricsProvider.cpuAvailable) {
            cpuBuffer.append(metricsProvider.cpuPercent);
        }
    }

    function appendMemory() {
        if (memoryEnabled && metricsProvider !== null
                && metricsProvider.memoryState === "available") {
            memoryBuffer.append(metricsProvider.memoryPercent);
        }
    }

    function appendGpu() {
        if (gpuEnabled && backendProvider !== null
                && backendProvider.gpuState === "available") {
            gpuBuffer.append(backendProvider.gpuUtilizationPercent);
        }
    }

    function appendNetworkRx() {
        if (networkEnabled && networkRxEnabled && metricsProvider !== null
                && metricsProvider.networkState === "available") {
            networkRxBuffer.append(metricsProvider.networkRxBytesPerSecond);
        }
    }

    function appendNetworkTx() {
        if (networkEnabled && networkTxEnabled && metricsProvider !== null
                && metricsProvider.networkState === "available") {
            networkTxBuffer.append(metricsProvider.networkTxBytesPerSecond);
        }
    }

    HistoryBuffer { id: cpuBuffer; maximumSamples: history.maximumSamples }
    HistoryBuffer { id: memoryBuffer; maximumSamples: history.maximumSamples }
    HistoryBuffer { id: gpuBuffer; maximumSamples: history.maximumSamples }
    HistoryBuffer { id: networkRxBuffer; maximumSamples: history.maximumSamples }
    HistoryBuffer { id: networkTxBuffer; maximumSamples: history.maximumSamples }

    Connections {
        target: history.metricsProvider
        ignoreUnknownSignals: true
        function onCpuPercentChanged() { history.appendCpu(); }
        function onMemoryPercentChanged() { history.appendMemory(); }
        function onNetworkRxBytesPerSecondChanged() { history.appendNetworkRx(); }
        function onNetworkTxBytesPerSecondChanged() { history.appendNetworkTx(); }
    }

    Connections {
        target: history.backendProvider
        ignoreUnknownSignals: true
        function onGpuUtilizationPercentChanged() { history.appendGpu(); }
        function onGpuStateChanged() {
            if (history.backendProvider.gpuState !== "available") gpuBuffer.clear();
        }
    }

    onCpuEnabledChanged: if (!cpuEnabled) cpuBuffer.clear()
    onMemoryEnabledChanged: if (!memoryEnabled) memoryBuffer.clear()
    onGpuEnabledChanged: if (!gpuEnabled) gpuBuffer.clear()
    onNetworkEnabledChanged: {
        if (!networkEnabled) {
            networkRxBuffer.clear();
            networkTxBuffer.clear();
        }
    }
    onNetworkRxEnabledChanged: if (!networkRxEnabled) networkRxBuffer.clear()
    onNetworkTxEnabledChanged: if (!networkTxEnabled) networkTxBuffer.clear()

    Component.onCompleted: {
        appendCpu();
        appendMemory();
        appendGpu();
        appendNetworkRx();
        appendNetworkTx();
    }
}

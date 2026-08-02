/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Plasma 5 system-monitor source names and payloads vary between releases.
 * This provider probes a small, ordered compatibility list and exposes a
 * stable interface to the visual components.
 */

import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.ksysguard.sensors 1.0 as Sensors

Item {
    id: provider

    property bool debugMetrics: false

    readonly property bool cpuAvailable: cpuState === "available"
    property real cpuPercent: 0
    property string cpuState: "loading"

    readonly property bool memoryAvailable: memoryState === "available"
    property real memoryPercent: 0
    property real memoryUsedBytes: 0
    property real memoryTotalBytes: 0
    property string memoryState: "loading"
    readonly property string memoryDisplayText: {
        if (!memoryAvailable) {
            return "";
        }

        if (memoryTotalBytes > 0) {
            return memoryPercent.toFixed(1) + "%  ·  "
                    + formatBytes(memoryUsedBytes) + " / "
                    + formatBytes(memoryTotalBytes);
        }

        return memoryPercent.toFixed(1) + "%  ·  size unavailable";
    }

    readonly property var cpuCandidates: [
        { "name": "cpu/system/TotalLoad", "scale": 1 },
        { "name": "cpu/all/usage", "scale": 1 },
        { "name": "cpu/total/usage", "scale": 1 },
        { "name": "cpu/TotalLoad", "scale": 1 }
    ]
    readonly property var memoryByteCandidates: [
        {
            "used": "mem/physical/used",
            "total": "mem/physical/total",
            "defaultMultiplier": 1024
        },
        {
            "used": "memory/physical/used",
            "total": "memory/physical/total",
            "defaultMultiplier": 1
        }
    ]
    readonly property var memoryPercentCandidates: [
        {
            "name": "mem/physical/usedPercent",
            "total": "mem/physical/total",
            "totalDefaultMultiplier": 1024,
            "scale": 1
        },
        {
            "name": "memory/physical/usedPercent",
            "total": "memory/physical/total",
            "totalDefaultMultiplier": 1,
            "scale": 1
        },
        {
            "name": "memory/physical/usage",
            "total": "memory/physical/total",
            "totalDefaultMultiplier": 1,
            "scale": 1
        }
    ]

    property string selectedCpuSource: ""
    property string selectedMemoryUsedSource: ""
    property string selectedMemoryTotalSource: ""
    property string selectedMemoryPercentSource: ""

    property var receivedData: ({})
    property var rejectionLog: ({})
    property bool sourceListLogged: false
    property real initialDebugCpuPercent: NaN
    property bool cpuUpdateLogged: false

    function finiteNumber(value) {
        if (value === null || value === undefined || value === "") {
            return NaN;
        }

        var number = Number(value);
        return isFinite(number) ? number : NaN;
    }

    function extractNumber(payload) {
        var direct = finiteNumber(payload);
        if (isFinite(direct)) {
            return direct;
        }

        if (typeof payload !== "object" || payload === null) {
            return NaN;
        }

        var keys = ["value", "Value", "data"];
        for (var index = 0; index < keys.length; ++index) {
            var key = keys[index];
            if (payload[key] !== undefined && payload[key] !== payload) {
                var nested = finiteNumber(payload[key]);
                if (isFinite(nested)) {
                    return nested;
                }
            }
        }

        return NaN;
    }

    function payloadText(payload, keys) {
        if (typeof payload !== "object" || payload === null) {
            return "";
        }

        for (var index = 0; index < keys.length; ++index) {
            var value = payload[keys[index]];
            if (value !== undefined && value !== null) {
                return String(value);
            }
        }

        return "";
    }

    function clampPercent(value) {
        if (!isFinite(value)) {
            return NaN;
        }
        return Math.max(0, Math.min(100, value));
    }

    function normalizePercentage(payload, defaultScale) {
        var value = extractNumber(payload);
        if (!isFinite(value)) {
            return NaN;
        }

        var scale = defaultScale;
        if (typeof payload === "object" && payload !== null) {
            var maximum = extractNumber(payload.maximum);
            if (!isFinite(maximum)) {
                maximum = extractNumber(payload.max);
            }

            var units = payloadText(payload, ["units", "unit"]).toLowerCase();
            if (isFinite(maximum) && maximum > 0 && maximum <= 1) {
                scale = 100;
            } else if (units === "ratio" || units === "fraction") {
                scale = 100;
            } else if (units.indexOf("%") !== -1 || units.indexOf("percent") !== -1) {
                scale = 1;
            }
        }

        return clampPercent(value * scale);
    }

    function bytesFromPayload(payload, defaultMultiplier) {
        var value = extractNumber(payload);
        if (!isFinite(value) || value < 0) {
            return NaN;
        }

        var multiplier = defaultMultiplier;
        var units = payloadText(payload, ["units", "unit"]).toLowerCase();
        if (units === "b" || units === "byte" || units === "bytes") {
            multiplier = 1;
        } else if (units === "kib" || units === "kibibyte" || units === "kibibytes") {
            multiplier = 1024;
        } else if (units === "mib" || units === "mebibyte" || units === "mebibytes") {
            multiplier = 1024 * 1024;
        } else if (units === "gib" || units === "gibibyte" || units === "gibibytes") {
            multiplier = 1024 * 1024 * 1024;
        } else if (units === "kb") {
            multiplier = 1000;
        } else if (units === "mb") {
            multiplier = 1000 * 1000;
        } else if (units === "gb") {
            multiplier = 1000 * 1000 * 1000;
        }

        var bytes = value * multiplier;
        return isFinite(bytes) ? bytes : NaN;
    }

    function formatBytes(bytes) {
        if (!isFinite(bytes) || bytes < 0) {
            return "Unavailable";
        }

        var gibibyte = 1024 * 1024 * 1024;
        var mebibyte = 1024 * 1024;
        if (bytes >= gibibyte) {
            return (bytes / gibibyte).toFixed(1) + " GiB";
        }
        return (bytes / mebibyte).toFixed(1) + " MiB";
    }

    function allCandidateNames() {
        var names = [];
        var index;
        for (index = 0; index < cpuCandidates.length; ++index) {
            names.push(cpuCandidates[index].name);
        }
        for (index = 0; index < memoryByteCandidates.length; ++index) {
            names.push(memoryByteCandidates[index].used);
            names.push(memoryByteCandidates[index].total);
        }
        for (index = 0; index < memoryPercentCandidates.length; ++index) {
            names.push(memoryPercentCandidates[index].name);
        }
        return names;
    }

    function logRejectedOnce(sourceName, reason) {
        if (!debugMetrics || rejectionLog[sourceName]) {
            return;
        }

        rejectionLog[sourceName] = true;
        console.log("TTop Desk metrics: rejected " + sourceName + " (" + reason + ")");
    }

    function logAvailableSources(logEmptyList) {
        if (!debugMetrics || sourceListLogged) {
            return;
        }

        if (monitor.sources.length === 0 && !logEmptyList) {
            return;
        }

        sourceListLogged = true;
        console.log("TTop Desk metrics: available system-monitor sources: "
                    + (monitor.sources.length > 0
                       ? monitor.sources.join(", ")
                       : "(none advertised)"));

        var candidates = allCandidateNames();
        for (var index = 0; index < candidates.length; ++index) {
            if (monitor.sources.indexOf(candidates[index]) === -1) {
                logRejectedOnce(candidates[index],
                                "not advertised by the DataEngine; native fallback checked separately");
            }
        }
    }

    function rememberData(sourceName, payload) {
        var updated = receivedData;
        updated[sourceName] = payload;
        receivedData = updated;
    }

    function tryCpuSources() {
        for (var index = 0; index < cpuCandidates.length; ++index) {
            var candidate = cpuCandidates[index];
            var percent = normalizePercentage(receivedData[candidate.name], candidate.scale);
            if (!isFinite(percent)) {
                continue;
            }

            if (selectedCpuSource !== candidate.name) {
                selectedCpuSource = candidate.name;
                initialDebugCpuPercent = percent;
                cpuUpdateLogged = false;
                if (debugMetrics) {
                    console.log("TTop Desk metrics: selected CPU source: "
                                + candidate.name + " (initial value "
                                + percent.toFixed(1) + "%)");
                }
            } else if (debugMetrics && !cpuUpdateLogged
                       && Math.abs(percent - initialDebugCpuPercent) >= 0.05) {
                cpuUpdateLogged = true;
                console.log("TTop Desk metrics: CPU live update received from "
                            + candidate.name + " (" + percent.toFixed(1) + "%)");
            }

            cpuPercent = percent;
            cpuState = "available";
            return;
        }
    }

    function tryMemoryByteSources() {
        for (var index = 0; index < memoryByteCandidates.length; ++index) {
            var candidate = memoryByteCandidates[index];
            var used = bytesFromPayload(receivedData[candidate.used],
                                        candidate.defaultMultiplier);
            var total = bytesFromPayload(receivedData[candidate.total],
                                         candidate.defaultMultiplier);
            if (!isFinite(used) || !isFinite(total) || total <= 0) {
                continue;
            }

            if (selectedMemoryUsedSource !== candidate.used) {
                selectedMemoryUsedSource = candidate.used;
                selectedMemoryTotalSource = candidate.total;
                selectedMemoryPercentSource = "";
                if (debugMetrics) {
                    console.log("TTop Desk metrics: selected memory sources: "
                                + candidate.used + ", " + candidate.total
                                + " (initial value " + formatBytes(used) + " / "
                                + formatBytes(total) + ")");
                }
            }

            memoryUsedBytes = Math.max(0, Math.min(used, total));
            memoryTotalBytes = total;
            memoryPercent = clampPercent((memoryUsedBytes / memoryTotalBytes) * 100);
            memoryState = "available";
            return true;
        }
        return false;
    }

    function tryMemoryPercentSources() {
        if (selectedMemoryUsedSource !== "") {
            return;
        }

        for (var index = 0; index < memoryPercentCandidates.length; ++index) {
            var candidate = memoryPercentCandidates[index];
            var percent = normalizePercentage(receivedData[candidate.name], candidate.scale);
            if (!isFinite(percent)) {
                continue;
            }

            if (selectedMemoryPercentSource !== candidate.name) {
                selectedMemoryPercentSource = candidate.name;
                if (debugMetrics) {
                    console.log("TTop Desk metrics: selected memory percentage source: "
                                + candidate.name + " (initial value "
                                + percent.toFixed(1) + "%)");
                }
            }

            if (selectedMemoryPercentSource === candidate.name) {
                memoryPercent = percent;
                var total = bytesFromPayload(receivedData[candidate.total],
                                             candidate.totalDefaultMultiplier);
                if (isFinite(total) && total > 0) {
                    memoryTotalBytes = total;
                    memoryUsedBytes = total * (percent / 100);
                } else {
                    memoryUsedBytes = 0;
                    memoryTotalBytes = 0;
                }
                memoryState = "available";
                return;
            }
        }
    }

    function handleData(sourceName, payload) {
        rememberData(sourceName, payload);
        tryCpuSources();
        if (!tryMemoryByteSources() && fallbackTimer.hasTriggered) {
            tryMemoryPercentSources();
        }
    }

    function handleNativeSensor(sourceName, value, maximum) {
        // Plasma 5.19+ ships Sensor as the native ksystemstats interface. It
        // is a fallback for distributions whose legacy DataEngine no longer
        // has a ksysguardd backend. DataSource candidates remain preferred by
        // the ordered selection above whenever they return data.
        handleData(sourceName, { "value": value, "maximum": maximum });
    }

    PlasmaCore.DataSource {
        id: monitor

        engine: "systemmonitor"
        interval: 1000
        connectedSources: provider.allCandidateNames()

        onNewData: provider.handleData(sourceName, data)
        onSourceAdded: sourceLogTimer.restart()
    }

    Instantiator {
        model: provider.allCandidateNames()

        delegate: Sensors.Sensor {
            id: nativeSensor

            sensorId: modelData
            updateRateLimit: 1000

            function publishValue() {
                if (name !== "" && isFinite(Number(value))) {
                    provider.handleNativeSensor(sensorId, value, maximum);
                }
            }

            onNameChanged: publishValue()
            onValueChanged: publishValue()
        }
    }

    Timer {
        id: sourceLogTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: provider.logAvailableSources(true)
    }

    Timer {
        id: fallbackTimer
        property bool hasTriggered: false

        interval: 2000
        repeat: false
        running: true
        onTriggered: {
            hasTriggered = true;
            provider.tryMemoryPercentSources();
        }
    }

    Timer {
        id: discoveryTimer

        interval: 6000
        repeat: false
        running: true
        onTriggered: {
            provider.logAvailableSources(true);

            var candidates = provider.allCandidateNames();
            for (var index = 0; index < candidates.length; ++index) {
                if (provider.receivedData[candidates[index]] === undefined) {
                    provider.logRejectedOnce(candidates[index], "no valid data received");
                }
            }

            if (!provider.cpuAvailable) {
                provider.cpuState = "unavailable";
                if (provider.debugMetrics) {
                    console.log("TTop Desk metrics: no compatible CPU source returned valid data");
                }
            }

            if (!provider.memoryAvailable) {
                provider.memoryState = "unavailable";
                if (provider.debugMetrics) {
                    console.log("TTop Desk metrics: no compatible memory source returned valid data");
                }
            }
        }
    }
}

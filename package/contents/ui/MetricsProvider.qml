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

    readonly property bool networkAvailable: networkState === "available"
    property real networkRxBytesPerSecond: 0
    property real networkTxBytesPerSecond: 0
    property string networkState: "loading"
    readonly property string networkRxDisplayText: networkAvailable
                                                          ? formatByteRate(networkRxBytesPerSecond)
                                                          : ""
    readonly property string networkTxDisplayText: networkAvailable
                                                          ? formatByteRate(networkTxBytesPerSecond)
                                                          : ""
    property var activeNetworkSources: []

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

    property var networkCandidateSources: []
    property var networkDescriptors: ({})
    property var selectedNetworkPairs: []
    property var networkSamples: ({})
    property string networkSourceSignature: "__uninitialized__"
    property string networkCandidateSignature: "__uninitialized__"
    property string networkSelectionSignature: "__uninitialized__"
    property bool networkSampleLogged: false
    property var networkDiscoveryLogs: ({})
    property var ignoredInterfaceLogs: ({})

    property var receivedData: ({})
    property var rejectionLog: ({})
    property var dataSourceLogSignatures: ({})
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

    function formatByteRate(bytesPerSecond) {
        if (!isFinite(bytesPerSecond) || bytesPerSecond < 0) {
            return "Unavailable";
        }

        var units = ["B/s", "KiB/s", "MiB/s", "GiB/s"];
        var value = bytesPerSecond;
        var unitIndex = 0;
        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024;
            ++unitIndex;
        }

        var decimals = value >= 10 ? 1 : 2;
        return value.toFixed(decimals) + " " + units[unitIndex];
    }

    function pushUnique(values, value) {
        if (values.indexOf(value) === -1) {
            values.push(value);
        }
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
        for (index = 0; index < networkCandidateSources.length; ++index) {
            pushUnique(names, networkCandidateSources[index]);
        }
        return names;
    }

    function collectSensorTreeSources(parentIndex, isRoot, result) {
        var count = isRoot ? sensorTree.rowCount() : sensorTree.rowCount(parentIndex);
        for (var row = 0; row < count; ++row) {
            var index = isRoot ? sensorTree.index(row, 0)
                               : sensorTree.index(row, 0, parentIndex);
            var sensorId = sensorTree.data(index, Sensors.SensorTreeModel.SensorId);
            if (sensorId !== undefined && sensorId !== null && String(sensorId) !== "") {
                pushUnique(result, String(sensorId));
            }
            collectSensorTreeSources(index, false, result);
        }
    }

    function allDiscoveredSources() {
        var sources = [];
        for (var index = 0; index < monitor.sources.length; ++index) {
            pushUnique(sources, String(monitor.sources[index]));
        }
        collectSensorTreeSources(null, true, sources);
        return sources;
    }

    function ignoredInterfaceReason(interfaceName) {
        var name = interfaceName.toLowerCase();
        if (name === "lo" || name === "loopback") {
            return "loopback interface";
        }

        var ignoredPrefixes = [
            "docker", "veth", "virbr", "vmnet", "br-", "tun", "tap", "wg"
        ];
        for (var index = 0; index < ignoredPrefixes.length; ++index) {
            if (name.indexOf(ignoredPrefixes[index]) === 0) {
                return "virtual or tunnel interface prefix " + ignoredPrefixes[index];
            }
        }
        return "";
    }

    function modernNetworkDescriptor(sourceName, parts) {
        if (parts.length !== 3) {
            return null;
        }

        var interfaceName = parts[1];
        var metric = parts[2];
        var definitions = {
            "download": { "direction": "rx", "mode": "rate", "multiplier": 1,
                          "family": "modern-byte-rate", "priority": 10 },
            "upload": { "direction": "tx", "mode": "rate", "multiplier": 1,
                        "family": "modern-byte-rate", "priority": 10 },
            "downloadBits": { "direction": "rx", "mode": "rate", "multiplier": 0.125,
                              "family": "modern-bit-rate", "priority": 20 },
            "uploadBits": { "direction": "tx", "mode": "rate", "multiplier": 0.125,
                            "family": "modern-bit-rate", "priority": 20 },
            "totalDownload": { "direction": "rx", "mode": "counter", "multiplier": 1,
                               "family": "modern-counter", "priority": 30 },
            "totalUpload": { "direction": "tx", "mode": "counter", "multiplier": 1,
                             "family": "modern-counter", "priority": 30 },
            "receivedDataRate": { "direction": "rx", "mode": "rate", "multiplier": 1024,
                                  "family": "legacy-aggregate-rate", "priority": 40 },
            "sentDataRate": { "direction": "tx", "mode": "rate", "multiplier": 1024,
                              "family": "legacy-aggregate-rate", "priority": 40 }
        };
        var definition = definitions[metric];
        if (definition === undefined) {
            return null;
        }

        return {
            "source": sourceName,
            "interfaceName": interfaceName,
            "aggregate": interfaceName === "all",
            "direction": definition.direction,
            "mode": definition.mode,
            "multiplier": definition.multiplier,
            "family": definition.family,
            "priority": definition.priority
        };
    }

    function legacyNetworkDescriptor(sourceName, parts) {
        if (parts.length !== 5 || parts[1] !== "interfaces") {
            return null;
        }

        var directionPart = parts[3];
        var valuePart = parts[4];
        var direction = directionPart === "receiver" ? "rx"
                        : directionPart === "transmitter" ? "tx" : "";
        if (direction === "") {
            return null;
        }

        if (valuePart === "data") {
            return {
                "source": sourceName,
                "interfaceName": parts[2],
                "aggregate": false,
                "direction": direction,
                "mode": "rate",
                "multiplier": 1024,
                "family": "legacy-interface-rate",
                "priority": 40
            };
        }
        if (valuePart === "bytes") {
            return {
                "source": sourceName,
                "interfaceName": parts[2],
                "aggregate": false,
                "direction": direction,
                "mode": "counter",
                "multiplier": 1,
                "family": "legacy-interface-counter",
                "priority": 50
            };
        }
        return null;
    }

    function networkDescriptor(sourceName) {
        var parts = sourceName.split("/");
        if (parts.length < 3 || parts[0] !== "network") {
            return null;
        }
        return parts[1] === "interfaces"
                ? legacyNetworkDescriptor(sourceName, parts)
                : modernNetworkDescriptor(sourceName, parts);
    }

    function logIgnoredInterface(interfaceName, reason) {
        if (!debugMetrics || ignoredInterfaceLogs[interfaceName]) {
            return;
        }
        ignoredInterfaceLogs[interfaceName] = true;
        console.log("TTop Desk metrics: ignored network interface "
                    + interfaceName + " (" + reason + ")");
    }

    function chooseNetworkPairs(descriptors) {
        var groups = ({});
        for (var sourceName in descriptors) {
            var descriptor = descriptors[sourceName];
            var reason = descriptor.aggregate ? "" : ignoredInterfaceReason(descriptor.interfaceName);
            if (reason !== "") {
                logIgnoredInterface(descriptor.interfaceName, reason);
                continue;
            }

            var key = descriptor.interfaceName + "|" + descriptor.family;
            if (groups[key] === undefined) {
                groups[key] = {
                    "interfaceName": descriptor.interfaceName,
                    "aggregate": descriptor.aggregate,
                    "family": descriptor.family,
                    "mode": descriptor.mode,
                    "priority": descriptor.priority,
                    "rx": null,
                    "tx": null
                };
            }
            groups[key][descriptor.direction] = descriptor;
        }

        var completePairs = [];
        for (var groupKey in groups) {
            if (groups[groupKey].rx !== null && groups[groupKey].tx !== null) {
                completePairs.push(groups[groupKey]);
            }
        }
        completePairs.sort(function(left, right) { return left.priority - right.priority; });

        var perInterfacePairs = [];
        var aggregatePairs = [];
        var selectedInterfaces = ({});
        for (var index = 0; index < completePairs.length; ++index) {
            var pair = completePairs[index];
            if (pair.aggregate) {
                aggregatePairs.push(pair);
            } else if (!selectedInterfaces[pair.interfaceName]) {
                selectedInterfaces[pair.interfaceName] = true;
                perInterfacePairs.push(pair);
            }
        }

        // Per-interface pairs make filtering explicit and support safe
        // aggregation. A single aggregate pair is only a fallback, so totals
        // and per-interface values are never added together.
        return perInterfacePairs.length > 0
                ? perInterfacePairs
                : aggregatePairs.length > 0 ? [aggregatePairs[0]] : [];
    }

    function discoverNetworkSources() {
        var allSources = allDiscoveredSources();
        var networkSources = [];
        var candidates = [];
        var descriptors = ({});
        for (var index = 0; index < allSources.length; ++index) {
            var sourceName = allSources[index];
            if (sourceName.indexOf("network/") !== 0 && sourceName !== "network") {
                continue;
            }
            networkSources.push(sourceName);

            var descriptor = networkDescriptor(sourceName);
            if (descriptor !== null) {
                candidates.push(sourceName);
                descriptors[sourceName] = descriptor;
            } else {
                var parts = sourceName.split("/");
                if (parts.length >= 3 && parts[1] !== "all" && parts[1] !== "interfaces") {
                    var reason = ignoredInterfaceReason(parts[1]);
                    if (reason !== "") {
                        logIgnoredInterface(parts[1], reason);
                    }
                }
            }
        }

        networkSources.sort();
        candidates.sort();
        var signature = networkSources.join("\n");
        if (signature !== networkSourceSignature) {
            networkSourceSignature = signature;
            if (debugMetrics && !networkDiscoveryLogs[signature]) {
                networkDiscoveryLogs[signature] = true;
                console.log("TTop Desk metrics: discovered network sources: "
                            + (networkSources.length > 0
                               ? networkSources.join(", ") : "(none)"));
                console.log("TTop Desk metrics: candidate network sources: "
                            + (candidates.length > 0 ? candidates.join(", ") : "(none)"));
            }
        }

        var candidateSignature = candidates.join("\n");
        if (candidateSignature !== networkCandidateSignature) {
            networkCandidateSignature = candidateSignature;
            networkDescriptors = descriptors;
            networkCandidateSources = candidates;
        }

        var newPairs = chooseNetworkPairs(descriptors);
        var selectionParts = [];
        for (index = 0; index < newPairs.length; ++index) {
            selectionParts.push(newPairs[index].rx.source + "|"
                                + newPairs[index].tx.source + "|"
                                + newPairs[index].mode);
        }
        var selectionSignature = selectionParts.join("\n");
        if (selectionSignature !== networkSelectionSignature) {
            networkSelectionSignature = selectionSignature;
            selectedNetworkPairs = newPairs;

            var activeSources = [];
            for (index = 0; index < selectedNetworkPairs.length; ++index) {
                var pair = selectedNetworkPairs[index];
                activeSources.push(pair.rx.source);
                activeSources.push(pair.tx.source);
                if (debugMetrics) {
                    console.log("TTop Desk metrics: selected network "
                                + (pair.aggregate ? "aggregate" : "interface " + pair.interfaceName)
                                + " sources: " + pair.rx.source + ", " + pair.tx.source
                                + " (" + pair.mode + ")");
                }
            }
            activeNetworkSources = activeSources;
            if (debugMetrics) {
                var selectedNames = [];
                for (index = 0; index < selectedNetworkPairs.length; ++index) {
                    selectedNames.push(selectedNetworkPairs[index].aggregate
                                       ? "aggregate"
                                       : selectedNetworkPairs[index].interfaceName);
                }
                console.log("TTop Desk metrics: final selected network interfaces: "
                            + (selectedNames.length > 0
                               ? selectedNames.join(", ") : "(none)"));
            }
        }

        if (selectedNetworkPairs.length === 0 && networkState === "available") {
            networkState = "loading";
            networkRxBytesPerSecond = 0;
            networkTxBytesPerSecond = 0;
        }
        updateNetworkAggregate();
    }

    function normalizeByteRate(payload, defaultMultiplier) {
        var value = extractNumber(payload);
        if (!isFinite(value) || value < 0) {
            return NaN;
        }

        var multiplier = defaultMultiplier;
        var units = payloadText(payload, ["units", "unit"]).toLowerCase();
        units = units.replace(/\s/g, "");
        if (units.indexOf("gib") !== -1) {
            multiplier = 1024 * 1024 * 1024;
        } else if (units.indexOf("mib") !== -1) {
            multiplier = 1024 * 1024;
        } else if (units.indexOf("kib") !== -1) {
            multiplier = 1024;
        } else if (units.indexOf("gbit") !== -1) {
            multiplier = 1000 * 1000 * 1000 / 8;
        } else if (units.indexOf("mbit") !== -1) {
            multiplier = 1000 * 1000 / 8;
        } else if (units.indexOf("kbit") !== -1) {
            multiplier = 1000 / 8;
        } else if (units.indexOf("bit") !== -1) {
            multiplier = 1 / 8;
        } else if (units.indexOf("gb") !== -1) {
            multiplier = 1000 * 1000 * 1000;
        } else if (units.indexOf("mb") !== -1) {
            multiplier = 1000 * 1000;
        } else if (units.indexOf("kb") !== -1) {
            multiplier = 1000;
        } else if (units.indexOf("byte") !== -1 || units === "b/s" || units === "b") {
            multiplier = 1;
        }

        var bytesPerSecond = value * multiplier;
        return isFinite(bytesPerSecond) && bytesPerSecond >= 0 ? bytesPerSecond : NaN;
    }

    function rememberNetworkSample(sourceName, payload) {
        var descriptor = networkDescriptors[sourceName];
        if (descriptor === undefined) {
            return;
        }

        var now = Date.now();
        var rawValue;
        var updatedSamples = networkSamples;
        var previous = updatedSamples[sourceName];

        if (descriptor.mode === "rate") {
            rawValue = normalizeByteRate(payload, descriptor.multiplier);
            if (!isFinite(rawValue)) {
                return;
            }
            updatedSamples[sourceName] = {
                "ready": true,
                "rate": rawValue,
                "raw": rawValue,
                "timestamp": now
            };
        } else {
            rawValue = bytesFromPayload(payload, descriptor.multiplier);
            if (!isFinite(rawValue)) {
                return;
            }

            if (previous === undefined || !isFinite(previous.raw)) {
                updatedSamples[sourceName] = {
                    "ready": false,
                    "rate": 0,
                    "raw": rawValue,
                    "timestamp": now
                };
            } else {
                var elapsedMilliseconds = now - previous.timestamp;
                var delta = rawValue - previous.raw;
                var validDelta = delta >= 0 && elapsedMilliseconds > 0
                                 && elapsedMilliseconds <= 30000;
                updatedSamples[sourceName] = {
                    "ready": validDelta,
                    "rate": validDelta ? delta * 1000 / elapsedMilliseconds : 0,
                    "raw": rawValue,
                    "timestamp": now
                };
            }
        }

        networkSamples = updatedSamples;
        updateNetworkAggregate();
    }

    function updateNetworkAggregate() {
        var rxTotal = 0;
        var txTotal = 0;
        var readyPairCount = 0;
        for (var index = 0; index < selectedNetworkPairs.length; ++index) {
            var pair = selectedNetworkPairs[index];
            var rxSample = networkSamples[pair.rx.source];
            var txSample = networkSamples[pair.tx.source];
            if (rxSample === undefined || txSample === undefined
                    || !rxSample.ready || !txSample.ready
                    || !isFinite(rxSample.rate) || !isFinite(txSample.rate)) {
                continue;
            }
            rxTotal += rxSample.rate;
            txTotal += txSample.rate;
            ++readyPairCount;
        }

        if (readyPairCount > 0) {
            networkRxBytesPerSecond = Math.max(0, rxTotal);
            networkTxBytesPerSecond = Math.max(0, txTotal);
            networkState = "available";
            if (debugMetrics && !networkSampleLogged) {
                networkSampleLogged = true;
                console.log("TTop Desk metrics: first aggregated network sample: RX "
                            + formatByteRate(networkRxBytesPerSecond) + ", TX "
                            + formatByteRate(networkTxBytesPerSecond));
            }
        }
    }

    function settleUnchangedNetworkCounters() {
        var now = Date.now();
        var samples = networkSamples;
        var changed = false;
        for (var index = 0; index < selectedNetworkPairs.length; ++index) {
            var pair = selectedNetworkPairs[index];
            if (pair.mode !== "counter") {
                continue;
            }

            var sourceNames = [pair.rx.source, pair.tx.source];
            for (var sourceIndex = 0; sourceIndex < sourceNames.length; ++sourceIndex) {
                var sourceName = sourceNames[sourceIndex];
                var sample = samples[sourceName];
                if (sample === undefined || now - sample.timestamp < 1500) {
                    continue;
                }

                // No valueChanged signal means the cumulative counter stayed
                // constant. That is a valid zero-rate second sample. Keep the
                // original timestamp/raw value so a later delta uses the full
                // real elapsed interval.
                if (!sample.ready || sample.rate !== 0) {
                    sample.ready = true;
                    sample.rate = 0;
                    samples[sourceName] = sample;
                    changed = true;
                }
            }
        }

        if (changed) {
            networkSamples = samples;
            updateNetworkAggregate();
        }
    }

    function handleNetworkSourceLoss(sourceName) {
        if (activeNetworkSources.indexOf(sourceName) === -1) {
            return;
        }

        var samples = networkSamples;
        delete samples[sourceName];
        networkSamples = samples;
        networkState = "loading";
        networkSampleLogged = false;
        networkRxBytesPerSecond = 0;
        networkTxBytesPerSecond = 0;
        if (debugMetrics) {
            console.log("TTop Desk metrics: network source lost: "
                        + sourceName + "; scheduling re-discovery");
        }
        networkDiscoveryTimer.restart();
        networkDeadlineTimer.restart();
    }

    function logRejectedOnce(sourceName, reason) {
        if (!debugMetrics || rejectionLog[sourceName]) {
            return;
        }

        rejectionLog[sourceName] = true;
        console.log("TTop Desk metrics: rejected " + sourceName + " (" + reason + ")");
    }

    function logAvailableSources(logEmptyList) {
        if (!debugMetrics) {
            return;
        }

        if (monitor.sources.length === 0 && !logEmptyList) {
            return;
        }

        var listedSources = [];
        for (var sourceIndex = 0; sourceIndex < monitor.sources.length; ++sourceIndex) {
            listedSources.push(String(monitor.sources[sourceIndex]));
        }
        listedSources.sort();
        var signature = listedSources.join("\n");
        if (dataSourceLogSignatures[signature]) {
            return;
        }
        dataSourceLogSignatures[signature] = true;
        console.log("TTop Desk metrics: available system-monitor sources: "
                    + (listedSources.length > 0
                       ? listedSources.join(", ")
                       : "(none advertised)"));

        var candidates = allCandidateNames();
        for (var index = 0; index < candidates.length; ++index) {
            if (listedSources.indexOf(candidates[index]) === -1) {
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
        rememberNetworkSample(sourceName, payload);
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
        onSourceAdded: {
            sourceLogTimer.restart();
            networkDiscoveryTimer.restart();
        }
        onSourceRemoved: provider.handleNetworkSourceLoss(source)
    }

    Sensors.SensorTreeModel {
        id: sensorTree

        onRowsInserted: networkDiscoveryTimer.restart()
        onRowsRemoved: networkDiscoveryTimer.restart()
        onModelReset: networkDiscoveryTimer.restart()
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
            onStatusChanged: {
                if (status === Sensors.Sensor.Error || status === Sensors.Sensor.Removed) {
                    provider.handleNetworkSourceLoss(sensorId);
                }
            }
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

    Timer {
        id: networkDiscoveryTimer

        interval: 750
        repeat: false
        running: true
        onTriggered: provider.discoverNetworkSources()
    }

    Timer {
        interval: 2000
        repeat: true
        running: provider.networkState !== "available"
        onTriggered: provider.discoverNetworkSources()
    }

    Timer {
        id: networkDeadlineTimer

        interval: 8000
        repeat: false
        running: true
        onTriggered: {
            if (!provider.networkAvailable) {
                provider.networkState = "unavailable";
                provider.networkRxBytesPerSecond = 0;
                provider.networkTxBytesPerSecond = 0;
                if (provider.debugMetrics) {
                    console.log("TTop Desk metrics: no compatible network source pair returned valid data");
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: provider.selectedNetworkPairs.length > 0
        onTriggered: provider.settleUnchangedNetworkCounters()
    }
}

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

    // Configuration-facing inputs. The effective values are clamped here as
    // a second line of defence in case an older or hand-edited configuration
    // contains unsafe values.
    property int refreshIntervalMs: 1000
    property int filesystemRefreshIntervalMs: 15000
    property int maximumFilesystemEntries: 3
    readonly property int effectiveRefreshIntervalMs:
        Math.max(500, Math.min(5000, refreshIntervalMs > 0 ? refreshIntervalMs : 1000))
    readonly property int effectiveFilesystemRefreshIntervalMs:
        Math.max(5000, Math.min(60000, filesystemRefreshIntervalMs > 0
                               ? filesystemRefreshIntervalMs : 15000))
    readonly property int effectiveMaximumFilesystemEntries:
        Math.max(1, Math.min(10, maximumFilesystemEntries > 0
                            ? maximumFilesystemEntries : 3))

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

    readonly property bool diskIoAvailable: diskIoState === "available"
    property real diskReadBytesPerSecond: 0
    property real diskWriteBytesPerSecond: 0
    property string diskIoState: "loading"
    readonly property string diskReadDisplayText: diskIoAvailable
                                                       ? formatByteRate(diskReadBytesPerSecond)
                                                       : ""
    readonly property string diskWriteDisplayText: diskIoAvailable
                                                        ? formatByteRate(diskWriteBytesPerSecond)
                                                        : ""
    property var selectedDiskSources: []
    property var selectedDiskDevices: []

    readonly property bool temperatureAvailable: temperatureState === "available"
    property real temperatureCelsius: 0
    readonly property string temperatureDisplayText: temperatureAvailable
                                                             ? temperatureCelsius.toFixed(1) + " °C"
                                                             : ""
    property string selectedTemperatureSource: ""
    property string temperatureState: "loading"
    readonly property string temperatureSeverity: !temperatureAvailable ? "unknown"
                                                         : temperatureCelsius < 45 ? "cool"
                                                         : temperatureCelsius < 70 ? "normal"
                                                         : temperatureCelsius < 85 ? "warm" : "hot"

    readonly property bool filesystemAvailable: filesystemState === "available"
    property string filesystemState: "loading"
    property alias filesystemEntries: filesystemModel
    readonly property bool rootFilesystemAvailable: rootFilesystemTotalBytes > 0
    property real rootFilesystemPercent: 0
    property real rootFilesystemUsedBytes: 0
    property real rootFilesystemTotalBytes: 0
    readonly property string rootFilesystemDisplayText: rootFilesystemAvailable
                                                             ? formatCapacity(rootFilesystemUsedBytes)
                                                               + " / " + formatCapacity(rootFilesystemTotalBytes)
                                                               + "  ·  " + rootFilesystemPercent.toFixed(1) + "%"
                                                             : ""

    ListModel {
        id: filesystemModel
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

    property var diskIoCandidateSources: []
    property var diskIoDescriptors: ({})
    property var selectedDiskPairs: []
    property var diskIoSamples: ({})
    property var diskIoSizeSamples: ({})
    property string diskIoSourceSignature: "__uninitialized__"
    property string diskIoCandidateSignature: "__uninitialized__"
    property string diskIoSelectionSignature: "__uninitialized__"
    property bool diskIoSampleLogged: false
    property var diskIoDiscoveryLogs: ({})
    property var diskIoIgnoredLogs: ({})

    property var temperatureCandidateSources: []
    property var temperatureDescriptors: ({})
    property var temperatureSamples: ({})
    property var selectedTemperatureSources: []
    property string temperatureDiscoverySignature: "__uninitialized__"
    property string temperatureCandidateSignature: "__uninitialized__"
    property string temperatureSelectionSignature: "__uninitialized__"
    property var temperatureDiscoveryLogs: ({})
    property var temperatureRejectionLogs: ({})
    property var temperatureSampleLogs: ({})

    property var filesystemCandidateSources: []
    property var filesystemDescriptors: ({})
    property var filesystemSamples: ({})
    property var activeFilesystemSources: []
    property string filesystemDiscoverySignature: "__uninitialized__"
    property string filesystemCandidateSignature: "__uninitialized__"
    property string filesystemSelectionSignature: "__uninitialized__"
    property string filesystemModelSignature: "__uninitialized__"
    property var filesystemDiscoveryLogs: ({})
    property var filesystemRejectionLogs: ({})
    property var filesystemSampleTimes: ({})
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

    function formatCapacity(bytes) {
        if (!isFinite(bytes) || bytes < 0) {
            return "Unavailable";
        }

        var units = ["B", "KiB", "MiB", "GiB", "TiB"];
        var value = bytes;
        var unitIndex = 0;
        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024;
            ++unitIndex;
        }
        return value.toFixed(1) + " " + units[unitIndex];
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
        for (index = 0; index < diskIoCandidateSources.length; ++index) {
            pushUnique(names, diskIoCandidateSources[index]);
        }
        for (index = 0; index < temperatureCandidateSources.length; ++index) {
            pushUnique(names, temperatureCandidateSources[index]);
        }
        for (index = 0; index < filesystemCandidateSources.length; ++index) {
            pushUnique(names, filesystemCandidateSources[index]);
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

    function filesystemRole(sourceName) {
        var leaf = sourceName.substring(sourceName.lastIndexOf("/") + 1)
                             .toLowerCase().replace(/[^a-z]/g, "");
        if (leaf === "used" || leaf === "usedspace" || leaf === "usedbytes") {
            return "used";
        }
        if (leaf === "free" || leaf === "available" || leaf === "avail"
                || leaf === "freespace" || leaf === "availablebytes") {
            return "available";
        }
        if (leaf === "total" || leaf === "size" || leaf === "capacity"
                || leaf === "totalspace" || leaf === "totalbytes") {
            return "total";
        }
        if (leaf === "usedpercent" || leaf === "usage" || leaf === "percentageused") {
            return "percent";
        }
        if (leaf === "freepercent" || leaf === "availablepercent") {
            return "freePercent";
        }
        if (leaf === "mount" || leaf === "mountpoint" || leaf === "mountpath"
                || leaf === "path") {
            return "mount";
        }
        if (leaf === "name" || leaf === "label" || leaf === "filesystemlabel") {
            return "label";
        }
        if (leaf === "type" || leaf === "fstype" || leaf === "filesystemtype") {
            return "type";
        }
        if (leaf === "device" || leaf === "devicename") {
            return "device";
        }
        return "";
    }

    function filesystemDescriptor(sourceName) {
        var lower = sourceName.toLowerCase();
        if (sourceName.indexOf("\\") !== -1 || sourceName.indexOf("*") !== -1) {
            return { "rejected": true, "reason": "template sensor identifier" };
        }
        if (lower.indexOf("disk/") !== 0
                && lower.indexOf("filesystem/") !== 0
                && lower.indexOf("filesystems/") !== 0
                && lower.indexOf("storage/") !== 0) {
            return { "rejected": true, "reason": "not a filesystem-capacity namespace" };
        }

        var role = filesystemRole(sourceName);
        if (role === "") {
            return { "rejected": true, "reason": "not a capacity or mount metadata sensor" };
        }
        var separator = sourceName.lastIndexOf("/");
        var group = sourceName.substring(0, separator);
        var groupTail = group.substring(group.indexOf("/") + 1);
        return {
            "rejected": false,
            "source": sourceName,
            "group": group,
            "groupTail": groupTail,
            "role": role,
            "aggregate": groupTail.toLowerCase() === "all"
        };
    }

    function isFilesystemSourceName(sourceName) {
        return !filesystemDescriptor(sourceName).rejected;
    }

    function logFilesystemRejection(sourceName, reason) {
        var key = sourceName + "|" + reason;
        if (!debugMetrics || filesystemRejectionLogs[key]) {
            return;
        }
        filesystemRejectionLogs[key] = true;
        console.log("TTop Desk metrics: ignored filesystem source "
                    + sourceName + " (" + reason + ")");
    }

    function discoverFilesystemSources() {
        var allSources = allDiscoveredSources();
        var discovered = [];
        var candidates = [];
        var descriptors = ({});
        for (var index = 0; index < allSources.length; ++index) {
            var sourceName = allSources[index];
            var descriptor = filesystemDescriptor(sourceName);
            if (descriptor.rejected) {
                continue;
            }
            discovered.push(sourceName);
            candidates.push(sourceName);
            descriptors[sourceName] = descriptor;
        }

        discovered.sort();
        candidates.sort();
        var discoverySignature = discovered.join("\n");
        if (discoverySignature !== filesystemDiscoverySignature) {
            filesystemDiscoverySignature = discoverySignature;
            if (debugMetrics && !filesystemDiscoveryLogs[discoverySignature]) {
                filesystemDiscoveryLogs[discoverySignature] = true;
                console.log("TTop Desk metrics: discovered filesystem candidates: "
                            + (discovered.length > 0 ? discovered.join(", ") : "(none)"));
            }
        }

        var candidateSignature = candidates.join("\n");
        if (candidateSignature !== filesystemCandidateSignature) {
            filesystemCandidateSignature = candidateSignature;
            filesystemCandidateSources = candidates;
            filesystemDescriptors = descriptors;
        }
        updateFilesystemEntries();
    }

    function filesystemPrimitiveText(payload) {
        if (typeof payload === "string") {
            return payload;
        }
        if (typeof payload !== "object" || payload === null) {
            return "";
        }
        var keys = ["value", "Value", "data", "text"];
        for (var index = 0; index < keys.length; ++index) {
            var value = payload[keys[index]];
            if (value !== undefined && value !== null && typeof value !== "object") {
                return String(value);
            }
        }
        return "";
    }

    function capacityFromPayload(payload) {
        var value = extractNumber(payload);
        var text = filesystemPrimitiveText(payload);
        if (!isFinite(value)) {
            var match = text.match(/[-+]?(?:\d+\.?\d*|\.\d+)/);
            if (match === null) {
                return NaN;
            }
            value = Number(match[0]);
        }
        if (!isFinite(value) || value < 0) {
            return NaN;
        }

        var units = payloadText(payload, ["units", "unit"]);
        if (units === "") {
            var unitMatch = text.match(/\b(kib|mib|gib|tib|kb|mb|gb|tb|bytes?|b)\b/i);
            units = unitMatch !== null ? unitMatch[1] : "";
        }
        units = units.toLowerCase();
        var multiplier = 1;
        if (units === "kib") {
            multiplier = 1024;
        } else if (units === "mib") {
            multiplier = 1024 * 1024;
        } else if (units === "gib") {
            multiplier = 1024 * 1024 * 1024;
        } else if (units === "tib") {
            multiplier = 1024 * 1024 * 1024 * 1024;
        } else if (units === "kb") {
            multiplier = 1000;
        } else if (units === "mb") {
            multiplier = 1000 * 1000;
        } else if (units === "gb") {
            multiplier = 1000 * 1000 * 1000;
        } else if (units === "tb") {
            multiplier = 1000 * 1000 * 1000 * 1000;
        }
        var bytes = value * multiplier;
        return isFinite(bytes) && bytes >= 0 ? bytes : NaN;
    }

    function rememberFilesystemSample(sourceName, payload) {
        var descriptor = filesystemDescriptors[sourceName];
        if (descriptor === undefined) {
            return;
        }

        var now = Date.now();
        var lastAccepted = filesystemSampleTimes[sourceName];
        var isMetadata = descriptor.role === "mount" || descriptor.role === "label"
                         || descriptor.role === "type" || descriptor.role === "device";

        var sample = {
            "source": sourceName,
            "role": descriptor.role,
            "group": descriptor.group,
            "name": payloadText(payload, ["name"]),
            "shortName": payloadText(payload, ["shortName"]),
            "description": payloadText(payload, ["description"]),
            "text": filesystemPrimitiveText(payload),
            "number": NaN
        };
        if (descriptor.role === "percent" || descriptor.role === "freePercent") {
            sample.number = normalizePercentage(payload, 1);
        } else if (!isMetadata) {
            sample.number = capacityFromPayload(payload);
        }
        if (!isMetadata && !isFinite(sample.number)) {
            logFilesystemRejection(sourceName, "invalid or negative capacity value");
            return;
        }

        var previous = filesystemSamples[sourceName];
        var replacesInitialZero = previous !== undefined && previous.number === 0
                                  && sample.number > 0;
        if (!isMetadata && !replacesInitialZero && lastAccepted !== undefined
                && now - lastAccepted < effectiveFilesystemRefreshIntervalMs - 250) {
            return;
        }

        var samples = filesystemSamples;
        samples[sourceName] = sample;
        filesystemSamples = samples;
        filesystemSampleTimes[sourceName] = now;
        updateFilesystemEntries();
    }

    function decodedFilesystemGroupTail(tail) {
        try {
            return decodeURIComponent(tail);
        } catch (error) {
            return tail;
        }
    }

    function filesystemGroupInfo(groupName, groupedSamples) {
        var descriptorSource = groupedSamples[0].source;
        var descriptor = filesystemDescriptors[descriptorSource];
        var label = "";
        var filesystemType = "";
        var device = "";
        var explicitMount = "";
        var metadata = [];
        var values = ({});
        var sources = ({});

        for (var index = 0; index < groupedSamples.length; ++index) {
            var sample = groupedSamples[index];
            values[sample.role] = sample.number;
            sources[sample.role] = sample.source;
            if (sample.role === "label" && sample.text !== "") {
                label = sample.text;
            } else if (sample.role === "type" && sample.text !== "") {
                filesystemType = sample.text;
            } else if (sample.role === "device" && sample.text !== "") {
                device = sample.text;
            } else if (sample.role === "mount" && sample.text.indexOf("/") === 0) {
                explicitMount = sample.text;
            }
            metadata.push(sample.name, sample.shortName, sample.description);
        }

        var decodedTail = decodedFilesystemGroupTail(descriptor.groupTail);
        var mountPath = explicitMount;
        if (mountPath === "" && decodedTail.indexOf("/") === 0) {
            mountPath = decodedTail;
        }
        if (mountPath === "") {
            var metadataText = metadata.join(" ");
            var mountMatch = metadataText.match(/(?:mounted\s+(?:at|on)|mount\s*point:?|filesystem)\s*(\/[^\s,)]*)/i);
            if (mountMatch !== null) {
                mountPath = mountMatch[1];
            }
        }

        var normalizedLabel = label.toLowerCase().replace(/^\s+|\s+$/g, "");
        if (mountPath === "" && (normalizedLabel === "/" || normalizedLabel === "root"
                || normalizedLabel === "rootfs" || normalizedLabel === "system"
                || normalizedLabel.indexOf("linux mint") !== -1
                || normalizedLabel === "ubuntu")) {
            mountPath = "/";
        } else if (mountPath === "" && normalizedLabel === "home") {
            mountPath = "/home";
        } else if (mountPath === "" && normalizedLabel === "data") {
            mountPath = "/data";
        }

        return {
            "group": groupName,
            "aggregate": descriptor.aggregate,
            "mountPath": mountPath,
            "label": label,
            "filesystemType": filesystemType.toLowerCase(),
            "device": device,
            "values": values,
            "sources": sources
        };
    }

    function filesystemIgnoredReason(info) {
        if (info.aggregate) {
            return "aggregate disk entry; mount-specific entries are preferred";
        }
        var ignoredTypes = [
            "proc", "sysfs", "tmpfs", "devtmpfs", "cgroup", "cgroup2",
            "overlay", "squashfs", "debugfs", "tracefs", "securityfs",
            "pstore", "efivarfs", "configfs", "fusectl", "mqueue",
            "hugetlbfs", "binfmt_misc", "autofs"
        ];
        for (var typeIndex = 0; typeIndex < ignoredTypes.length; ++typeIndex) {
            if (info.filesystemType === ignoredTypes[typeIndex]) {
                return "virtual or transient filesystem type " + info.filesystemType;
            }
        }
        var path = info.mountPath;
        var ignoredPaths = ["/proc", "/sys", "/dev", "/run", "/snap"];
        for (var pathIndex = 0; pathIndex < ignoredPaths.length; ++pathIndex) {
            if (path === ignoredPaths[pathIndex]
                    || path.indexOf(ignoredPaths[pathIndex] + "/") === 0) {
                return "virtual or transient mount path " + path;
            }
        }
        if (path === "") {
            return "mount path could not be inferred safely";
        }
        return "";
    }

    function filesystemCompleteness(info) {
        var values = info.values;
        var score = 0;
        if (isFinite(values.used)) {
            score += 4;
        }
        if (isFinite(values.total)) {
            score += 4;
        }
        if (isFinite(values.available)) {
            score += 3;
        }
        if (isFinite(values.percent)) {
            score += 2;
        }
        if (info.filesystemType !== "") {
            ++score;
        }
        return score;
    }

    function normalizedFilesystemEntry(info) {
        var total = info.values.total;
        var used = info.values.used;
        var available = info.values.available;
        var percent = info.values.percent;
        var chosenSources = ({});
        var usedFromAvailable = isFinite(total) && isFinite(available)
                                ? total - available : NaN;
        var directUsedIsInitialZero = used === 0 && isFinite(usedFromAvailable)
                                      && usedFromAvailable > 0;
        if (isFinite(total)) {
            chosenSources.total = info.sources.total;
        }
        if (!isFinite(percent) && isFinite(info.values.freePercent)) {
            percent = 100 - info.values.freePercent;
        }
        if (isFinite(used) && !directUsedIsInitialZero) {
            chosenSources.used = info.sources.used;
        } else if (isFinite(usedFromAvailable)) {
            used = usedFromAvailable;
            chosenSources.available = info.sources.available;
        }
        if (isFinite(used) && isFinite(total) && total > 0) {
            // Locally calculated usage keeps the text and progress bar
            // consistent and takes precedence over a direct percentage.
            percent = used / total * 100;
        }
        if (!isFinite(used) && isFinite(percent) && isFinite(total) && total > 0) {
            used = total * clampPercent(percent) / 100;
            if (isFinite(info.values.percent)) {
                chosenSources.percent = info.sources.percent;
            } else {
                chosenSources.freePercent = info.sources.freePercent;
            }
        }
        if (!isFinite(total) || total <= 0 || !isFinite(used) || used < 0
                || used > total || !isFinite(percent)) {
            return null;
        }
        percent = clampPercent(percent);
        return {
            "mountPath": info.mountPath,
            "usedBytes": used,
            "totalBytes": total,
            "percent": percent,
            "displayText": formatCapacity(used) + " / " + formatCapacity(total),
            "group": info.group,
            "filesystemType": info.filesystemType,
            "sources": chosenSources,
            "score": filesystemCompleteness(info)
        };
    }

    function filesystemMountPriority(mountPath) {
        if (mountPath === "/") {
            return 0;
        }
        if (mountPath === "/home") {
            return 1;
        }
        if (mountPath === "/data") {
            return 2;
        }
        return 10;
    }

    function syncFilesystemModel(entries) {
        var mountNames = [];
        for (var index = 0; index < entries.length; ++index) {
            mountNames.push(entries[index].mountPath);
        }
        var signature = mountNames.join("\n");
        if (signature !== filesystemModelSignature) {
            filesystemModelSignature = signature;
            filesystemModel.clear();
            for (index = 0; index < entries.length; ++index) {
                filesystemModel.append(entries[index]);
            }
            return;
        }
        for (index = 0; index < entries.length; ++index) {
            filesystemModel.setProperty(index, "usedBytes", entries[index].usedBytes);
            filesystemModel.setProperty(index, "totalBytes", entries[index].totalBytes);
            filesystemModel.setProperty(index, "percent", entries[index].percent);
            filesystemModel.setProperty(index, "displayText", entries[index].displayText);
        }
    }

    function updateFilesystemEntries() {
        var grouped = ({});
        var sampleNames = Object.keys(filesystemSamples);
        for (var index = 0; index < sampleNames.length; ++index) {
            var sample = filesystemSamples[sampleNames[index]];
            if (filesystemDescriptors[sample.source] === undefined) {
                continue;
            }
            if (grouped[sample.group] === undefined) {
                grouped[sample.group] = [];
            }
            grouped[sample.group].push(sample);
        }

        var groups = Object.keys(grouped);
        var byMount = ({});
        for (index = 0; index < groups.length; ++index) {
            var info = filesystemGroupInfo(groups[index], grouped[groups[index]]);
            var ignoredReason = filesystemIgnoredReason(info);
            if (ignoredReason !== "") {
                logFilesystemRejection(info.group, ignoredReason);
                continue;
            }
            var entry = normalizedFilesystemEntry(info);
            if (entry === null) {
                continue;
            }
            var existing = byMount[entry.mountPath];
            if (existing === undefined || entry.score > existing.score
                    || (entry.score === existing.score && entry.group < existing.group)) {
                if (existing !== undefined) {
                    logFilesystemRejection(existing.group,
                                           "duplicate mount " + entry.mountPath
                                           + "; more complete source group selected");
                }
                byMount[entry.mountPath] = entry;
            } else {
                logFilesystemRejection(entry.group,
                                       "duplicate mount " + entry.mountPath
                                       + "; existing source group is more complete");
            }
        }

        var entries = [];
        var mountPaths = Object.keys(byMount);
        for (index = 0; index < mountPaths.length; ++index) {
            entries.push(byMount[mountPaths[index]]);
        }
        entries.sort(function(left, right) {
            var priorityDifference = filesystemMountPriority(left.mountPath)
                                     - filesystemMountPriority(right.mountPath);
            return priorityDifference !== 0 ? priorityDifference
                                            : left.mountPath.localeCompare(right.mountPath);
        });
        if (entries.length > effectiveMaximumFilesystemEntries) {
            entries = entries.slice(0, effectiveMaximumFilesystemEntries);
        }

        syncFilesystemModel(entries);
        var activeSources = [];
        for (index = 0; index < entries.length; ++index) {
            var sourceRoles = Object.keys(entries[index].sources);
            for (var roleIndex = 0; roleIndex < sourceRoles.length; ++roleIndex) {
                pushUnique(activeSources, entries[index].sources[sourceRoles[roleIndex]]);
            }
        }
        activeFilesystemSources = activeSources;

        var rootEntry = byMount["/"];
        if (rootEntry !== undefined) {
            rootFilesystemUsedBytes = rootEntry.usedBytes;
            rootFilesystemTotalBytes = rootEntry.totalBytes;
            rootFilesystemPercent = rootEntry.percent;
        } else {
            rootFilesystemUsedBytes = 0;
            rootFilesystemTotalBytes = 0;
            rootFilesystemPercent = 0;
        }

        if (entries.length > 0) {
            filesystemState = "available";
        } else if (filesystemState === "available") {
            filesystemState = "loading";
        }

        var selectionParts = [];
        for (index = 0; index < entries.length; ++index) {
            var signatureRoles = Object.keys(entries[index].sources);
            signatureRoles.sort();
            var signatureSources = [];
            for (var signatureIndex = 0; signatureIndex < signatureRoles.length;
                    ++signatureIndex) {
                signatureSources.push(signatureRoles[signatureIndex] + "="
                                      + entries[index].sources[signatureRoles[signatureIndex]]);
            }
            selectionParts.push(entries[index].mountPath + "=" + entries[index].group
                                + "[" + signatureSources.join(",") + "]");
        }
        var selectionSignature = selectionParts.join("\n");
        if (selectionSignature !== filesystemSelectionSignature) {
            filesystemSelectionSignature = selectionSignature;
            if (debugMetrics) {
                console.log("TTop Desk metrics: selected filesystem mounts: "
                            + (selectionParts.length > 0
                               ? selectionParts.join(", ") : "(none)"));
                for (index = 0; index < entries.length; ++index) {
                    var selected = entries[index];
                    console.log("TTop Desk metrics: filesystem " + selected.mountPath
                                + " uses " + Object.keys(selected.sources).map(function(role) {
                                    return role + "=" + selected.sources[role];
                                }).join(", ") + " (type "
                                + (selected.filesystemType !== ""
                                   ? selected.filesystemType : "not exposed") + "; "
                                + selected.displayText + ", "
                                + selected.percent.toFixed(1) + "%)");
                }
            }
        }
    }

    function handleFilesystemSourceLoss(sourceName) {
        if (filesystemSamples[sourceName] === undefined
                && activeFilesystemSources.indexOf(sourceName) === -1) {
            return;
        }
        var samples = filesystemSamples;
        delete samples[sourceName];
        filesystemSamples = samples;
        if (debugMetrics) {
            console.log("TTop Desk metrics: filesystem source lost: "
                        + sourceName + "; scheduling re-discovery");
        }
        updateFilesystemEntries();
        filesystemDiscoveryTimer.restart();
        filesystemDeadlineTimer.restart();
    }

    function temperatureNumber(payload) {
        var number = extractNumber(payload);
        if (isFinite(number)) {
            return number;
        }

        var text = "";
        if (typeof payload === "string") {
            text = payload;
        } else if (typeof payload === "object" && payload !== null) {
            text = payloadText(payload, ["value", "Value", "data"]);
        }
        var match = text.match(/[-+]?(?:\d+\.?\d*|\.\d+)/);
        if (match === null) {
            return NaN;
        }
        number = Number(match[0]);
        return isFinite(number) ? number : NaN;
    }

    function normalizeTemperatureCelsius(payload, sourceName) {
        var units = payloadText(payload, ["units", "unit"]).toLowerCase();
        var rawText = typeof payload === "string" ? payload.toLowerCase() : "";
        if (units.indexOf("fahrenheit") !== -1 || units.indexOf("°f") !== -1
                || rawText.indexOf("°f") !== -1) {
            return NaN;
        }

        var value = temperatureNumber(payload);
        if (!isFinite(value)) {
            return NaN;
        }

        // hwmon-style sources commonly expose integer millidegrees Celsius.
        if (Math.abs(value) >= 1000) {
            value /= 1000;
        }
        var advertisedMaximum = typeof payload === "object" && payload !== null
                                ? extractNumber(payload.maximum) : NaN;
        if (value === 0 && advertisedMaximum === 0
                && sourceName.indexOf("cpu/") === 0) {
            return NaN;
        }
        if (!isFinite(value) || value < -20 || value > 150) {
            return NaN;
        }
        return value;
    }

    function temperatureMetadataText(sourceName, payload) {
        return (sourceName + " "
                + payloadText(payload, ["name"]) + " "
                + payloadText(payload, ["shortName"]) + " "
                + payloadText(payload, ["description"])).toLowerCase();
    }

    function temperatureDescriptor(sourceName, payload, allowPending) {
        var text = temperatureMetadataText(sourceName, payload);
        if (sourceName.indexOf("\\") !== -1 || sourceName.indexOf("*") !== -1) {
            return { "rejected": true, "reason": "template sensor identifier" };
        }
        if (text.indexOf("minimumtemperature") !== -1
                || text.indexOf("minimum temperature") !== -1) {
            return { "rejected": true,
                     "reason": "minimum summary is not representative of package temperature" };
        }
        var hasCpuContext = text.indexOf("cpu") !== -1
                            || text.indexOf("package") !== -1
                            || text.indexOf("tctl") !== -1
                            || text.indexOf("tdie") !== -1
                            || text.indexOf("core") !== -1
                            || text.indexOf("k10temp") !== -1
                            || text.indexOf("zenpower") !== -1
                            || text.indexOf("x86_pkg_temp") !== -1;

        var rejectedTerms = [
            "nvme", "nvidia", "battery", "wifi", "wireless", "chipset",
            "motherboard", "mainboard", "spd5118", "r8169", "iwlwifi"
        ];
        for (var rejectedIndex = 0; rejectedIndex < rejectedTerms.length; ++rejectedIndex) {
            if (text.indexOf(rejectedTerms[rejectedIndex]) !== -1) {
                return { "rejected": true,
                         "reason": "unrelated sensor term " + rejectedTerms[rejectedIndex] };
            }
        }
        if (text.indexOf("gpu") !== -1 || text.indexOf("amdgpu") !== -1) {
            return { "rejected": true, "reason": "GPU temperature sensor" };
        }
        if ((text.indexOf("edge") !== -1 || text.indexOf("junction") !== -1)
                && text.indexOf("cpu") === -1) {
            return { "rejected": true, "reason": "non-CPU edge or junction sensor" };
        }
        if ((text.indexOf("acpi") !== -1 || text.indexOf("thermal_zone") !== -1)
                && !hasCpuContext) {
            return { "rejected": true, "reason": "ACPI thermal zone without CPU context" };
        }

        var category = "";
        var priority = 999;
        if (text.indexOf("x86_pkg_temp") !== -1) {
            category = "x86 package";
            priority = 30;
        } else if (text.indexOf("package") !== -1 || text.indexOf("cpu package") !== -1) {
            category = "CPU package";
            priority = 10;
        } else if (text.indexOf("tctl") !== -1 || text.indexOf("tdie") !== -1) {
            category = "AMD Tctl/Tdie";
            priority = 20;
        } else if (text.indexOf("k10temp") !== -1 || text.indexOf("zenpower") !== -1) {
            category = "AMD CPU temperature";
            priority = 25;
        } else if (text.indexOf("cpu/all/averagetemperature") !== -1
                   || text.indexOf("cpu aggregate") !== -1
                   || text.indexOf("average cpu temperature") !== -1) {
            category = "CPU aggregate";
            priority = 40;
        } else if (/cpu\/cpu\d+\/temperature/.test(text)
                   || /core[\s/_-]*\d+/.test(text)) {
            category = "CPU core";
            priority = 50;
        } else if (hasCpuContext && text.indexOf("temp") !== -1) {
            category = "CPU aggregate";
            priority = 45;
        } else if (allowPending) {
            category = "pending metadata";
        } else {
            return { "rejected": true, "reason": "no CPU context" };
        }

        var coreMatch = text.match(/cpu\/cpu(\d+)\/temperature/);
        if (coreMatch === null) {
            coreMatch = text.match(/core[\s/_-]*(\d+)/);
        }
        return {
            "rejected": false,
            "source": sourceName,
            "category": category,
            "priority": priority,
            "coreKey": coreMatch !== null ? coreMatch[1] : sourceName
        };
    }

    function isTemperatureSourceName(sourceName) {
        var lower = sourceName.toLowerCase();
        return lower.indexOf("temperature") !== -1
               || lower.indexOf("thermal") !== -1
               || /\/temp\d*(?:\/|$)/.test(lower);
    }

    function logTemperatureRejection(sourceName, reason) {
        var key = sourceName + "|" + reason;
        if (!debugMetrics || temperatureRejectionLogs[key]) {
            return;
        }
        temperatureRejectionLogs[key] = true;
        console.log("TTop Desk metrics: rejected temperature candidate "
                    + sourceName + " (" + reason + ")");
    }

    function logTemperatureSampleRejection(sourceName, reason) {
        var key = sourceName + "|" + reason;
        if (!debugMetrics || temperatureSampleLogs[key]) {
            return;
        }
        temperatureSampleLogs[key] = true;
        console.log("TTop Desk metrics: ignored temperature sample from "
                    + sourceName + " (" + reason + ")");
    }

    function discoverTemperatureSources() {
        var allSources = allDiscoveredSources();
        var discovered = [];
        var candidates = [];
        var descriptors = ({});
        for (var index = 0; index < allSources.length; ++index) {
            var sourceName = allSources[index];
            if (!isTemperatureSourceName(sourceName)) {
                continue;
            }
            discovered.push(sourceName);
            var descriptor = temperatureDescriptor(sourceName, {}, true);
            if (descriptor.rejected) {
                logTemperatureRejection(sourceName, descriptor.reason);
                continue;
            }
            candidates.push(sourceName);
            descriptors[sourceName] = descriptor;
        }

        discovered.sort();
        candidates.sort();
        var discoverySignature = discovered.join("\n");
        if (discoverySignature !== temperatureDiscoverySignature) {
            temperatureDiscoverySignature = discoverySignature;
            if (debugMetrics && !temperatureDiscoveryLogs[discoverySignature]) {
                temperatureDiscoveryLogs[discoverySignature] = true;
                console.log("TTop Desk metrics: discovered temperature sources: "
                            + (discovered.length > 0 ? discovered.join(", ") : "(none)"));
                console.log("TTop Desk metrics: temperature candidates requiring samples: "
                            + (candidates.length > 0 ? candidates.join(", ") : "(none)"));
                for (index = 0; index < candidates.length; ++index) {
                    var candidateDescriptor = descriptors[candidates[index]];
                    console.log("TTop Desk metrics: temperature candidate "
                                + candidates[index] + " category "
                                + candidateDescriptor.category + " priority "
                                + candidateDescriptor.priority);
                }
            }
        }

        var candidateSignature = candidates.join("\n");
        if (candidateSignature !== temperatureCandidateSignature) {
            temperatureCandidateSignature = candidateSignature;
            temperatureDescriptors = descriptors;
            temperatureCandidateSources = candidates;
        }
        selectTemperatureSources();
    }

    function selectTemperatureSources() {
        var validSamples = [];
        for (var sourceName in temperatureSamples) {
            var sample = temperatureSamples[sourceName];
            if (sample !== undefined && isFinite(sample.value)
                    && temperatureCandidateSources.indexOf(sourceName) !== -1) {
                validSamples.push(sample);
            }
        }
        validSamples.sort(function(left, right) {
            if (left.descriptor.priority !== right.descriptor.priority) {
                return left.descriptor.priority - right.descriptor.priority;
            }
            return left.source < right.source ? -1 : left.source > right.source ? 1 : 0;
        });

        var chosen = [];
        if (validSamples.length > 0) {
            if (validSamples[0].descriptor.priority < 50) {
                chosen = [validSamples[0]];
            } else {
                var seenCores = ({});
                for (var index = 0; index < validSamples.length; ++index) {
                    var coreSample = validSamples[index];
                    if (coreSample.descriptor.priority !== 50) {
                        continue;
                    }
                    var coreKey = coreSample.descriptor.coreKey;
                    if (!seenCores[coreKey]) {
                        seenCores[coreKey] = true;
                        chosen.push(coreSample);
                    }
                }
            }
        }

        if (chosen.length === 0) {
            return;
        }

        var total = 0;
        var chosenSources = [];
        for (var chosenIndex = 0; chosenIndex < chosen.length; ++chosenIndex) {
            total += chosen[chosenIndex].value;
            chosenSources.push(chosen[chosenIndex].source);
        }
        temperatureCelsius = total / chosen.length;
        selectedTemperatureSources = chosenSources;
        selectedTemperatureSource = chosen.length > 1
                                    ? "Average of " + chosen.length + " CPU core sensors"
                                    : chosen[0].source;
        temperatureState = "available";

        var selectionSignature = chosenSources.join("\n");
        if (selectionSignature !== temperatureSelectionSignature) {
            temperatureSelectionSignature = selectionSignature;
            if (debugMetrics) {
                if (chosen.length > 1) {
                    console.log("TTop Desk metrics: selected CPU core temperature average: "
                                + chosenSources.join(", "));
                } else {
                    console.log("TTop Desk metrics: selected temperature source: "
                                + chosen[0].source + " ("
                                + chosen[0].descriptor.category + ", priority "
                                + chosen[0].descriptor.priority + ")");
                }
                console.log("TTop Desk metrics: normalized temperature sample: "
                            + temperatureCelsius.toFixed(1) + " °C");
            }
        }
    }

    function rememberTemperatureSample(sourceName, payload) {
        if (temperatureCandidateSources.indexOf(sourceName) === -1) {
            return;
        }

        var descriptor = temperatureDescriptor(sourceName, payload, false);
        if (descriptor.rejected) {
            logTemperatureRejection(sourceName, descriptor.reason);
            return;
        }
        var celsius = normalizeTemperatureCelsius(payload, sourceName);
        if (!isFinite(celsius)) {
            logTemperatureSampleRejection(
                        sourceName,
                        "invalid, unsupported, implausible, or zero-without-range value");
            return;
        }

        var samples = temperatureSamples;
        samples[sourceName] = {
            "source": sourceName,
            "value": celsius,
            "descriptor": descriptor
        };
        temperatureSamples = samples;
        temperatureDescriptors[sourceName] = descriptor;
        selectTemperatureSources();
    }

    function handleTemperatureSourceLoss(sourceName) {
        if (selectedTemperatureSources.indexOf(sourceName) === -1) {
            return;
        }

        var samples = temperatureSamples;
        delete samples[sourceName];
        temperatureSamples = samples;
        selectedTemperatureSources = [];
        selectedTemperatureSource = "";
        temperatureSelectionSignature = "__rediscovering__";
        temperatureState = "loading";
        if (debugMetrics) {
            console.log("TTop Desk metrics: temperature source lost: "
                        + sourceName + "; scheduling re-discovery");
        }
        selectTemperatureSources();
        temperatureDiscoveryTimer.restart();
        temperatureDeadlineTimer.restart();
    }

    function diskIoDescriptor(sourceName) {
        var parts = sourceName.split("/");
        if (parts.length < 3 || parts[0].toLowerCase() !== "disk") {
            return null;
        }
        if (sourceName.indexOf("\\") !== -1 || sourceName.indexOf("*") !== -1) {
            return null;
        }

        var deviceName = parts[1];
        var metric = parts[parts.length - 1].toLowerCase().replace(/[^a-z]/g, "");
        if (parts.length === 4 && parts[2].toLowerCase() === "rate") {
            if (metric === "rblk" || metric === "readblocks") {
                return diskIoDescriptorResult(sourceName, deviceName, "read", "rate",
                                              1024, "legacy-rate", 30, "");
            }
            if (metric === "wblk" || metric === "writeblocks") {
                return diskIoDescriptorResult(sourceName, deviceName, "write", "rate",
                                              1024, "legacy-rate", 30, "");
            }
            return null;
        }
        if (parts.length !== 3) {
            return null;
        }

        var rateDefinitions = {
            "read": { "direction": "read", "family": "modern-rate", "priority": 10 },
            "write": { "direction": "write", "family": "modern-rate", "priority": 10 },
            "readrate": { "direction": "read", "family": "named-rate", "priority": 15 },
            "writerate": { "direction": "write", "family": "named-rate", "priority": 15 },
            "readbytespersecond": { "direction": "read", "family": "named-rate", "priority": 15 },
            "writebytespersecond": { "direction": "write", "family": "named-rate", "priority": 15 },
            "readbytesrate": { "direction": "read", "family": "named-rate", "priority": 15 },
            "writebytesrate": { "direction": "write", "family": "named-rate", "priority": 15 }
        };
        var rateDefinition = rateDefinitions[metric];
        if (rateDefinition !== undefined) {
            return diskIoDescriptorResult(sourceName, deviceName,
                                          rateDefinition.direction, "rate", 1,
                                          rateDefinition.family,
                                          rateDefinition.priority, "");
        }

        var counterDefinitions = {
            "totalread": "read", "totalwrite": "write",
            "totalreadbytes": "read", "totalwritebytes": "write",
            "readbytes": "read", "writtenbytes": "write", "writebytes": "write"
        };
        if (counterDefinitions[metric] !== undefined) {
            return diskIoDescriptorResult(sourceName, deviceName,
                                          counterDefinitions[metric], "counter", 1,
                                          "byte-counter", 40, "");
        }

        var unitCounters = {
            "readsectors": { "direction": "read", "unitKind": "sector" },
            "writesectors": { "direction": "write", "unitKind": "sector" },
            "readblocks": { "direction": "read", "unitKind": "block" },
            "writeblocks": { "direction": "write", "unitKind": "block" }
        };
        var unitCounter = unitCounters[metric];
        if (unitCounter !== undefined) {
            return diskIoDescriptorResult(sourceName, deviceName,
                                          unitCounter.direction, "unitCounter", 1,
                                          unitCounter.unitKind + "-counter", 50,
                                          unitCounter.unitKind);
        }
        if (metric === "sectorsize" || metric === "logicalsectorsize") {
            return diskIoDescriptorResult(sourceName, deviceName, "size", "metadata", 1,
                                          "sector-size", 0, "sector");
        }
        if (metric === "blocksize" || metric === "logicalblocksize") {
            return diskIoDescriptorResult(sourceName, deviceName, "size", "metadata", 1,
                                          "block-size", 0, "block");
        }
        return null;
    }

    function diskIoDescriptorResult(sourceName, deviceName, direction, mode,
                                    multiplier, family, priority, unitKind) {
        var normalizedDevice = deviceName.toLowerCase();
        return {
            "source": sourceName,
            "deviceName": deviceName,
            "normalizedDevice": normalizedDevice,
            "aggregate": normalizedDevice === "all" || normalizedDevice === "total"
                         || normalizedDevice === "aggregate",
            "direction": direction,
            "mode": mode,
            "multiplier": multiplier,
            "family": family,
            "priority": priority,
            "unitKind": unitKind
        };
    }

    function diskPartitionParent(deviceName) {
        var name = deviceName.toLowerCase();
        var match = name.match(/^(nvme\d+n\d+|mmcblk\d+|md\d+)p\d+$/);
        if (match !== null) {
            return match[1];
        }
        match = name.match(/^((?:sd|hd|vd|xvd)[a-z]+)\d+$/);
        return match !== null ? match[1] : "";
    }

    function diskDeviceClass(deviceName) {
        var name = deviceName.toLowerCase();
        if (name === "all" || name === "total" || name === "aggregate") {
            return "aggregate";
        }
        if (diskPartitionParent(name) !== "") {
            return "partition";
        }
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(name)) {
            return "volume-identifier";
        }
        if (name.indexOf("dm-") === 0) {
            return "device-mapper";
        }
        if (/^md\d+/.test(name)) {
            return "raid";
        }
        if (/^(?:nvme\d+n\d+|mmcblk\d+|(?:sd|hd|vd|xvd)[a-z]+)$/.test(name)) {
            return "whole-device";
        }
        return "unknown-device";
    }

    function ignoredDiskDeviceReason(deviceName) {
        var name = deviceName.toLowerCase();
        var ignoredPrefixes = ["loop", "ram", "zram", "sr", "fd"];
        for (var index = 0; index < ignoredPrefixes.length; ++index) {
            if (name.indexOf(ignoredPrefixes[index]) === 0) {
                return "virtual or irrelevant device prefix " + ignoredPrefixes[index];
            }
        }
        return "";
    }

    function logIgnoredDiskIo(key, reason) {
        var signature = key + "|" + reason;
        if (!debugMetrics || diskIoIgnoredLogs[signature]) {
            return;
        }
        diskIoIgnoredLogs[signature] = true;
        console.log("TTop Desk metrics: ignored disk I/O " + key + " (" + reason + ")");
    }

    function chooseDiskIoPairs(descriptors) {
        var groups = ({});
        var sizeSources = ({});
        for (var sourceName in descriptors) {
            var descriptor = descriptors[sourceName];
            if (descriptor.direction === "size") {
                sizeSources[descriptor.normalizedDevice + "|" + descriptor.unitKind] = descriptor;
                continue;
            }
            var ignoredReason = descriptor.aggregate ? ""
                                                      : ignoredDiskDeviceReason(descriptor.deviceName);
            if (ignoredReason !== "") {
                logIgnoredDiskIo(descriptor.deviceName, ignoredReason);
                continue;
            }
            var key = descriptor.normalizedDevice + "|" + descriptor.family;
            if (groups[key] === undefined) {
                groups[key] = {
                    "deviceName": descriptor.deviceName,
                    "normalizedDevice": descriptor.normalizedDevice,
                    "deviceClass": diskDeviceClass(descriptor.deviceName),
                    "aggregate": descriptor.aggregate,
                    "family": descriptor.family,
                    "mode": descriptor.mode,
                    "priority": descriptor.priority,
                    "unitKind": descriptor.unitKind,
                    "read": null,
                    "write": null,
                    "size": null
                };
            }
            groups[key][descriptor.direction] = descriptor;
        }

        var completePairs = [];
        for (var groupKey in groups) {
            var group = groups[groupKey];
            if (group.read === null || group.write === null) {
                continue;
            }
            if (group.mode === "unitCounter") {
                group.size = sizeSources[group.normalizedDevice + "|" + group.unitKind];
                if (group.size === undefined) {
                    logIgnoredDiskIo(group.deviceName + " " + group.family,
                                     "no trustworthy " + group.unitKind + " size sensor");
                    continue;
                }
            }
            completePairs.push(group);
        }
        completePairs.sort(function(left, right) {
            if (left.priority !== right.priority) {
                return left.priority - right.priority;
            }
            return left.normalizedDevice.localeCompare(right.normalizedDevice);
        });

        var bestByDevice = ({});
        var aggregates = [];
        for (var index = 0; index < completePairs.length; ++index) {
            var pair = completePairs[index];
            if (pair.aggregate) {
                aggregates.push(pair);
            } else if (bestByDevice[pair.normalizedDevice] === undefined) {
                bestByDevice[pair.normalizedDevice] = pair;
            } else {
                logIgnoredDiskIo(pair.deviceName + " " + pair.family,
                                 "duplicate sensor family; higher-priority pair selected");
            }
        }

        var wholeDevices = [];
        var partitions = [];
        var logicalDevices = [];
        var deviceNames = Object.keys(bestByDevice);
        for (index = 0; index < deviceNames.length; ++index) {
            pair = bestByDevice[deviceNames[index]];
            if (pair.deviceClass === "whole-device") {
                wholeDevices.push(pair);
            } else if (pair.deviceClass === "partition") {
                partitions.push(pair);
            } else {
                logicalDevices.push(pair);
            }
        }

        if (wholeDevices.length > 0) {
            for (index = 0; index < partitions.length; ++index) {
                var parent = diskPartitionParent(partitions[index].deviceName);
                if (bestByDevice[parent] !== undefined) {
                    logIgnoredDiskIo(partitions[index].deviceName,
                                     "parent whole-device sensor " + parent + " is available");
                }
            }
            for (index = 0; index < logicalDevices.length; ++index) {
                logIgnoredDiskIo(logicalDevices[index].deviceName,
                                 logicalDevices[index].deviceClass
                                 + " may duplicate selected physical devices");
            }
            return wholeDevices;
        }

        if (aggregates.length > 0) {
            for (index = 0; index < partitions.length; ++index) {
                logIgnoredDiskIo(partitions[index].deviceName,
                                 "reliable aggregate pair selected instead of partitions");
            }
            for (index = 0; index < logicalDevices.length; ++index) {
                logIgnoredDiskIo(logicalDevices[index].deviceName,
                                 "reliable aggregate pair selected instead of "
                                 + logicalDevices[index].deviceClass + " alias");
            }
            return [aggregates[0]];
        }

        if (partitions.length > 0) {
            return partitions;
        }
        if (logicalDevices.length > 0) {
            // Without topology metadata, combining several mapper/RAID aliases
            // could count the same operation twice. One complete pair is the
            // conservative last fallback.
            for (index = 1; index < logicalDevices.length; ++index) {
                logIgnoredDiskIo(logicalDevices[index].deviceName,
                                 "ambiguous logical-device duplication");
            }
            return [logicalDevices[0]];
        }
        return [];
    }

    function discoverDiskIoSources() {
        var allSources = allDiscoveredSources();
        var candidates = [];
        var descriptors = ({});
        for (var index = 0; index < allSources.length; ++index) {
            var sourceName = allSources[index];
            var descriptor = diskIoDescriptor(sourceName);
            if (descriptor === null) {
                continue;
            }
            candidates.push(sourceName);
            descriptors[sourceName] = descriptor;
        }
        candidates.sort();
        var sourceSignature = candidates.join("\n");
        if (sourceSignature !== diskIoSourceSignature) {
            diskIoSourceSignature = sourceSignature;
            if (debugMetrics && !diskIoDiscoveryLogs[sourceSignature]) {
                diskIoDiscoveryLogs[sourceSignature] = true;
                console.log("TTop Desk metrics: discovered disk I/O candidates: "
                            + (candidates.length > 0 ? candidates.join(", ") : "(none)"));
                for (index = 0; index < candidates.length; ++index) {
                    descriptor = descriptors[candidates[index]];
                    console.log("TTop Desk metrics: disk I/O candidate "
                                + descriptor.source + " device " + descriptor.deviceName
                                + " class " + diskDeviceClass(descriptor.deviceName)
                                + " mode " + descriptor.mode);
                }
            }
        }

        if (sourceSignature !== diskIoCandidateSignature) {
            diskIoCandidateSignature = sourceSignature;
            diskIoDescriptors = descriptors;
            diskIoCandidateSources = candidates;
        }

        var newPairs = chooseDiskIoPairs(descriptors);
        var selectionParts = [];
        for (index = 0; index < newPairs.length; ++index) {
            selectionParts.push(newPairs[index].read.source + "|"
                                + newPairs[index].write.source + "|"
                                + newPairs[index].mode);
        }
        var selectionSignature = selectionParts.join("\n");
        if (selectionSignature !== diskIoSelectionSignature) {
            diskIoSelectionSignature = selectionSignature;
            selectedDiskPairs = newPairs;
            var sources = [];
            var devices = [];
            for (index = 0; index < newPairs.length; ++index) {
                var pair = newPairs[index];
                sources.push(pair.read.source, pair.write.source);
                if (pair.size !== null && pair.size !== undefined) {
                    sources.push(pair.size.source);
                }
                devices.push(pair.aggregate ? "aggregate" : pair.deviceName);
                if (debugMetrics) {
                    console.log("TTop Desk metrics: selected disk I/O "
                                + (pair.aggregate ? "aggregate" : "device " + pair.deviceName)
                                + " sources: " + pair.read.source + ", " + pair.write.source
                                + " (" + pair.mode + ")");
                }
            }
            selectedDiskSources = sources;
            selectedDiskDevices = devices;
            diskIoSampleLogged = false;
            if (debugMetrics) {
                console.log("TTop Desk metrics: disk I/O selection strategy: "
                            + (newPairs.length === 0 ? "none"
                               : newPairs[0].aggregate ? "aggregate source"
                               : "per-device aggregation") + "; devices: "
                            + (devices.length > 0 ? devices.join(", ") : "(none)"));
            }
        }
        if (selectedDiskPairs.length === 0 && diskIoState === "available") {
            diskIoState = "loading";
            diskReadBytesPerSecond = 0;
            diskWriteBytesPerSecond = 0;
        }
        updateDiskIoAggregate();
    }

    function rememberDiskIoSample(sourceName, payload) {
        var descriptor = diskIoDescriptors[sourceName];
        if (descriptor === undefined) {
            return;
        }
        if (descriptor.direction === "size") {
            var size = capacityFromPayload(payload);
            if (isFinite(size) && size >= 128 && size <= 1024 * 1024) {
                var sizes = diskIoSizeSamples;
                sizes[sourceName] = size;
                diskIoSizeSamples = sizes;
            } else {
                logIgnoredDiskIo(sourceName, "invalid or implausible block/sector size");
            }
            return;
        }

        var now = Date.now();
        var samples = diskIoSamples;
        var previous = samples[sourceName];
        var rawValue = NaN;
        if (descriptor.mode === "rate") {
            rawValue = normalizeByteRate(payload, descriptor.multiplier);
            if (!isFinite(rawValue)) {
                return;
            }
            samples[sourceName] = {
                "ready": true, "rate": rawValue, "raw": rawValue, "timestamp": now
            };
        } else {
            rawValue = descriptor.mode === "unitCounter"
                       ? extractNumber(payload) : bytesFromPayload(payload, descriptor.multiplier);
            var counterMultiplier = descriptor.multiplier;
            if (descriptor.mode === "unitCounter") {
                var pairSizeSource = null;
                for (var pairIndex = 0; pairIndex < selectedDiskPairs.length; ++pairIndex) {
                    var selectedPair = selectedDiskPairs[pairIndex];
                    if (selectedPair.normalizedDevice === descriptor.normalizedDevice
                            && selectedPair.family === descriptor.family) {
                        pairSizeSource = selectedPair.size;
                        break;
                    }
                }
                if (pairSizeSource === null || pairSizeSource === undefined
                        || !isFinite(diskIoSizeSamples[pairSizeSource.source])) {
                    return;
                }
                counterMultiplier = diskIoSizeSamples[pairSizeSource.source];
            }
            if (!isFinite(rawValue) || rawValue < 0) {
                return;
            }
            rawValue *= counterMultiplier;
            if (!isFinite(rawValue)) {
                return;
            }
            if (previous === undefined || !isFinite(previous.raw)) {
                samples[sourceName] = {
                    "ready": false, "rate": 0, "raw": rawValue, "timestamp": now
                };
            } else {
                var elapsedMilliseconds = now - previous.timestamp;
                var delta = rawValue - previous.raw;
                var validDelta = delta >= 0 && elapsedMilliseconds >= 250
                                 && elapsedMilliseconds <= 10000;
                samples[sourceName] = {
                    "ready": validDelta,
                    "rate": validDelta ? delta * 1000 / elapsedMilliseconds : 0,
                    "raw": rawValue,
                    "timestamp": now
                };
            }
        }
        diskIoSamples = samples;
        updateDiskIoAggregate();
    }

    function updateDiskIoAggregate() {
        var readTotal = 0;
        var writeTotal = 0;
        var readyPairs = 0;
        for (var index = 0; index < selectedDiskPairs.length; ++index) {
            var pair = selectedDiskPairs[index];
            var readSample = diskIoSamples[pair.read.source];
            var writeSample = diskIoSamples[pair.write.source];
            if (readSample === undefined || writeSample === undefined
                    || !readSample.ready || !writeSample.ready
                    || !isFinite(readSample.rate) || !isFinite(writeSample.rate)) {
                continue;
            }
            readTotal += readSample.rate;
            writeTotal += writeSample.rate;
            ++readyPairs;
        }
        if (readyPairs > 0) {
            diskReadBytesPerSecond = Math.max(0, readTotal);
            diskWriteBytesPerSecond = Math.max(0, writeTotal);
            diskIoState = "available";
            if (debugMetrics && !diskIoSampleLogged) {
                diskIoSampleLogged = true;
                console.log("TTop Desk metrics: first aggregated disk I/O sample: read "
                            + formatByteRate(diskReadBytesPerSecond) + ", write "
                            + formatByteRate(diskWriteBytesPerSecond));
            }
        }
    }

    function settleUnchangedDiskIoCounters() {
        var now = Date.now();
        var samples = diskIoSamples;
        var changed = false;
        for (var index = 0; index < selectedDiskPairs.length; ++index) {
            var pair = selectedDiskPairs[index];
            if (pair.mode === "rate") {
                continue;
            }
            var sourceNames = [pair.read.source, pair.write.source];
            for (var sourceIndex = 0; sourceIndex < sourceNames.length; ++sourceIndex) {
                var sourceName = sourceNames[sourceIndex];
                var sample = samples[sourceName];
                if (sample === undefined || now - sample.timestamp < 1500) {
                    continue;
                }
                if (!sample.ready || sample.rate !== 0) {
                    sample.ready = true;
                    sample.rate = 0;
                    samples[sourceName] = sample;
                    changed = true;
                }
            }
        }
        if (changed) {
            diskIoSamples = samples;
            updateDiskIoAggregate();
        }
    }

    function handleDiskIoSourceLoss(sourceName) {
        if (selectedDiskSources.indexOf(sourceName) === -1) {
            return;
        }
        var samples = diskIoSamples;
        delete samples[sourceName];
        diskIoSamples = samples;
        var sizes = diskIoSizeSamples;
        delete sizes[sourceName];
        diskIoSizeSamples = sizes;
        diskIoState = "loading";
        diskReadBytesPerSecond = 0;
        diskWriteBytesPerSecond = 0;
        diskIoSampleLogged = false;
        if (debugMetrics) {
            console.log("TTop Desk metrics: disk I/O source lost: "
                        + sourceName + "; scheduling re-discovery");
        }
        diskIoDiscoveryTimer.restart();
        diskIoDeadlineTimer.restart();
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
        rememberDiskIoSample(sourceName, payload);
        rememberTemperatureSample(sourceName, payload);
        rememberFilesystemSample(sourceName, payload);
    }

    onEffectiveMaximumFilesystemEntriesChanged: updateFilesystemEntries()

    function handleNativeSensor(sourceName, value, maximum, name, shortName, description) {
        // Plasma 5.19+ ships Sensor as the native ksystemstats interface. It
        // is a fallback for distributions whose legacy DataEngine no longer
        // has a ksysguardd backend. DataSource candidates remain preferred by
        // the ordered selection above whenever they return data.
        handleData(sourceName, {
            "value": value,
            "maximum": maximum,
            "name": name,
            "shortName": shortName,
            "description": description
        });
    }

    PlasmaCore.DataSource {
        id: monitor

        engine: "systemmonitor"
        interval: provider.effectiveRefreshIntervalMs
        connectedSources: provider.allCandidateNames()

        onNewData: provider.handleData(sourceName, data)
        onSourceAdded: {
            sourceLogTimer.restart();
            networkDiscoveryTimer.restart();
            diskIoDiscoveryTimer.restart();
            temperatureDiscoveryTimer.restart();
            filesystemDiscoveryTimer.restart();
        }
        onSourceRemoved: {
            provider.handleNetworkSourceLoss(source);
            provider.handleDiskIoSourceLoss(source);
            provider.handleTemperatureSourceLoss(source);
            provider.handleFilesystemSourceLoss(source);
        }
    }

    Sensors.SensorTreeModel {
        id: sensorTree

        onRowsRemoved: {
            networkDiscoveryTimer.restart();
            diskIoDiscoveryTimer.restart();
            temperatureDiscoveryTimer.restart();
            filesystemDiscoveryTimer.restart();
        }
        onModelReset: {
            networkDiscoveryTimer.restart();
            diskIoDiscoveryTimer.restart();
            temperatureDiscoveryTimer.restart();
            filesystemDiscoveryTimer.restart();
        }
        onRowsInserted: {
            networkDiscoveryTimer.restart();
            diskIoDiscoveryTimer.restart();
            temperatureDiscoveryTimer.restart();
            filesystemDiscoveryTimer.restart();
        }
    }

    Instantiator {
        model: provider.allCandidateNames()

        delegate: Sensors.Sensor {
            id: nativeSensor

            sensorId: modelData
            updateRateLimit: provider.isFilesystemSourceName(sensorId)
                             ? provider.effectiveFilesystemRefreshIntervalMs
                             : provider.effectiveRefreshIntervalMs

            function publishValue() {
                if (name !== "" && value !== null && value !== undefined && value !== "") {
                    provider.handleNativeSensor(sensorId, value, maximum,
                                                name, shortName, description);
                }
            }

            onNameChanged: publishValue()
            onValueChanged: publishValue()
            onStatusChanged: {
                if (status === Sensors.Sensor.Error || status === Sensors.Sensor.Removed) {
                    provider.handleNetworkSourceLoss(sensorId);
                    provider.handleDiskIoSourceLoss(sensorId);
                    provider.handleTemperatureSourceLoss(sensorId);
                    provider.handleFilesystemSourceLoss(sensorId);
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
        interval: provider.effectiveRefreshIntervalMs
        repeat: true
        running: provider.selectedNetworkPairs.length > 0
        onTriggered: provider.settleUnchangedNetworkCounters()
    }

    Timer {
        id: diskIoDiscoveryTimer

        interval: 750
        repeat: false
        running: true
        onTriggered: provider.discoverDiskIoSources()
    }

    Timer {
        interval: 2000
        repeat: true
        running: provider.diskIoState !== "available"
        onTriggered: provider.discoverDiskIoSources()
    }

    Timer {
        id: diskIoDeadlineTimer

        interval: 8000
        repeat: false
        running: true
        onTriggered: {
            if (!provider.diskIoAvailable) {
                provider.diskIoState = "unavailable";
                provider.diskReadBytesPerSecond = 0;
                provider.diskWriteBytesPerSecond = 0;
                if (provider.debugMetrics) {
                    console.log("TTop Desk metrics: no compatible disk I/O source pair returned valid data");
                }
            }
        }
    }

    Timer {
        interval: provider.effectiveRefreshIntervalMs
        repeat: true
        running: provider.selectedDiskPairs.length > 0
        onTriggered: provider.settleUnchangedDiskIoCounters()
    }

    Timer {
        id: temperatureDiscoveryTimer

        interval: 750
        repeat: false
        running: true
        onTriggered: provider.discoverTemperatureSources()
    }

    Timer {
        interval: 2000
        repeat: true
        running: provider.temperatureState !== "available"
        onTriggered: provider.discoverTemperatureSources()
    }

    Timer {
        id: temperatureDeadlineTimer

        interval: 8000
        repeat: false
        running: true
        onTriggered: {
            if (!provider.temperatureAvailable) {
                provider.temperatureState = "unavailable";
                provider.temperatureCelsius = 0;
                provider.selectedTemperatureSource = "";
                provider.selectedTemperatureSources = [];
                if (provider.debugMetrics) {
                    console.log("TTop Desk metrics: no compatible CPU temperature source returned valid data");
                }
            }
        }
    }

    Timer {
        id: filesystemDiscoveryTimer

        interval: 750
        repeat: false
        running: true
        onTriggered: provider.discoverFilesystemSources()
    }

    Timer {
        interval: 3000
        repeat: true
        running: provider.filesystemState !== "available"
        onTriggered: provider.discoverFilesystemSources()
    }

    Timer {
        id: filesystemDeadlineTimer

        interval: Math.max(15000, provider.effectiveFilesystemRefreshIntervalMs + 3000)
        repeat: false
        running: true
        onTriggered: {
            if (!provider.filesystemAvailable) {
                provider.filesystemState = "unavailable";
                provider.rootFilesystemUsedBytes = 0;
                provider.rootFilesystemTotalBytes = 0;
                provider.rootFilesystemPercent = 0;
                if (provider.debugMetrics) {
                    console.log("TTop Desk metrics: no compatible filesystem source returned valid data");
                }
            }
        }
    }
}

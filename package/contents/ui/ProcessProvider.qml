/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Process sensor capability provider. It is deliberately independent from
 * MetricsProvider and is not yet instantiated by the widget UI.
 */

import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.ksysguard.sensors 1.0 as Sensors

Item {
    id: provider

    property bool debugProcesses: false
    readonly property bool processAvailable: processState === "available"
    property string processState: "detecting"
    property var processEntries: []
    property int processCount: 0
    property string selectedProcessSource: ""
    property string selectedProcessStructure: ""
    property string lastError: ""

    readonly property int probeIntervalMs: 2000
    readonly property int maximumCandidateSources: 4096
    readonly property int maximumTraversalDepth: 6
    readonly property int maximumNormalizedEntries: 8192

    property var processCandidateSources: []
    property var perProcessRecords: ({})
    property var rejectedSignatures: ({})
    property var debugSignatures: ({})
    property string candidateSignature: "__uninitialized__"
    property string selectedAggregateSource: ""
    property real selectedAggregateScore: -1
    property real lastUsableDataMs: 0

    function finiteNumber(value) {
        if (value === null || value === undefined || value === ""
                || typeof value === "boolean") {
            return NaN;
        }
        var number = Number(value);
        return isFinite(number) ? number : NaN;
    }

    function numericValue(value, depth) {
        var direct = finiteNumber(value);
        if (isFinite(direct)) {
            return direct;
        }
        if (value === null || typeof value !== "object" || depth > 2) {
            return NaN;
        }
        var wrappers = ["value", "Value", "data", "rawValue", "current"];
        for (var index = 0; index < wrappers.length; ++index) {
            var nested = value[wrappers[index]];
            if (nested !== undefined && nested !== value) {
                var number = numericValue(nested, depth + 1);
                if (isFinite(number)) {
                    return number;
                }
            }
        }
        return NaN;
    }

    function safeIntegerPid(value) {
        var number = numericValue(value, 0);
        if (!isFinite(number) || number <= 0 || number > 2147483647
                || Math.floor(number) !== number) {
            return -1;
        }
        return number;
    }

    function normalizedKey(value) {
        return String(value).toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function safeObjectKeys(value) {
        if (value === null || typeof value !== "object") {
            return [];
        }
        try {
            return Object.keys(value);
        } catch (error) {
            return [];
        }
    }

    function firstField(record, aliases, depth) {
        if (record === null || typeof record !== "object" || depth > 2) {
            return undefined;
        }
        var keys = safeObjectKeys(record);
        var index;
        var aliasIndex;
        for (aliasIndex = 0; aliasIndex < aliases.length; ++aliasIndex) {
            for (index = 0; index < keys.length; ++index) {
                if (normalizedKey(keys[index]) === aliases[aliasIndex]) {
                    return {
                        "value": record[keys[index]],
                        "key": keys[index],
                        "owner": record
                    };
                }
            }
        }
        var containers = ["process", "info", "details", "values", "fields", "data"];
        for (index = 0; index < keys.length; ++index) {
            if (containers.indexOf(normalizedKey(keys[index])) === -1) {
                continue;
            }
            var nested = record[keys[index]];
            if (nested !== record) {
                var found = firstField(nested, aliases, depth + 1);
                if (found !== undefined) {
                    return found;
                }
            }
        }
        return undefined;
    }

    function pidFromRecord(record, hintedPid) {
        var pidField = firstField(record,
                                  ["pid", "processid", "processidentifier", "id"], 0);
        var pid = pidField === undefined ? -1 : safeIntegerPid(pidField.value);
        return pid > 0 ? pid : safeIntegerPid(hintedPid);
    }

    function sanitizedName(value, fieldName) {
        if (value !== null && typeof value === "object") {
            var wrappers = ["value", "Value", "data", "current"];
            for (var wrapperIndex = 0; wrapperIndex < wrappers.length; ++wrapperIndex) {
                if (value[wrappers[wrapperIndex]] !== undefined
                        && value[wrappers[wrapperIndex]] !== value) {
                    return sanitizedName(value[wrappers[wrapperIndex]], fieldName);
                }
            }
        }
        if (value === null || value === undefined || typeof value === "object") {
            return "";
        }
        var text = String(value).replace(/^\s+|\s+$/g, "");
        if (text === "" || text.length > 512 || text.indexOf("\u0000") !== -1) {
            return "";
        }

        // Executable fields may contain a path. Expose only the basename.
        var key = normalizedKey(fieldName);
        if (key.indexOf("executable") !== -1 || key === "exe" || text.indexOf("/") !== -1) {
            text = text.replace(/\\/g, "/");
            text = text.substring(text.lastIndexOf("/") + 1);
        }
        // Command-line fields are intentionally never considered by callers.
        return text.length <= 256 ? text : "";
    }

    function processNameFromRecord(record) {
        var field = firstField(record,
                               ["name", "processname", "comm", "executable", "exename", "exe"], 0);
        return field === undefined ? "" : sanitizedName(field.value, field.key);
    }

    function metadataText(field) {
        if (field === undefined || field === null) {
            return "";
        }
        var value = field.value;
        var owner = field.owner;
        var keys = ["unit", "units", "suffix", "symbol", "formattedValue"];
        var index;
        if (value !== null && typeof value === "object") {
            for (index = 0; index < keys.length; ++index) {
                if (value[keys[index]] !== undefined) {
                    var nestedText = String(value[keys[index]]).toLowerCase();
                    if (!/^\d+$/.test(nestedText)) return nestedText;
                }
            }
        }
        if (owner !== null && typeof owner === "object") {
            var fieldPrefix = String(field.key);
            var siblings = [fieldPrefix + "Unit", fieldPrefix + "Units", "unit", "units"];
            for (index = 0; index < siblings.length; ++index) {
                if (owner[siblings[index]] !== undefined) {
                    var siblingText = String(owner[siblings[index]]).toLowerCase();
                    if (!/^\d+$/.test(siblingText)) return siblingText;
                }
            }
        }
        return "";
    }

    function cpuValueFromRecord(record) {
        var field = firstField(record,
                               ["cpupercent", "cpuusage", "totalcpuusage", "cpu", "usagepercent"], 0);
        if (field === undefined) {
            return NaN;
        }
        var value = numericValue(field.value, 0);
        if (!isFinite(value) || value < 0) {
            return NaN;
        }
        var unit = metadataText(field);
        if ((unit.indexOf("ratio") !== -1 || unit.indexOf("fraction") !== -1)
                && value <= 1) {
            return value * 100;
        }
        // Raw non-negative values are preserved, including values above 100.
        return value;
    }

    function byteMultiplier(unit) {
        var text = String(unit).toLowerCase().replace(/\s/g, "");
        if (/(^|[0-9.])(kib|kibyte|kibytes)$/.test(text)) return 1024;
        if (/(^|[0-9.])(mib|mibyte|mibytes)$/.test(text)) return 1048576;
        if (/(^|[0-9.])(gib|gibyte|gibytes)$/.test(text)) return 1073741824;
        if (/(^|[0-9.])(kb|kilobyte|kilobytes)$/.test(text)) return 1000;
        if (/(^|[0-9.])(mb|megabyte|megabytes)$/.test(text)) return 1000000;
        if (/(^|[0-9.])(gb|gigabyte|gigabytes)$/.test(text)) return 1000000000;
        if (/(^|[0-9.])(b|byte|bytes)$/.test(text)) return 1;
        return NaN;
    }

    function memoryValueFromRecord(record) {
        // Resident/physical memory wins by alias order. Virtual size is never
        // used because it is not equivalent to real memory consumption.
        var field = firstField(record,
                               ["residentmemorybytes", "rssbytes", "physicalmemorybytes",
                                "residentmemory", "resident", "rss", "physicalmemory",
                                "realmemory", "memoryresident"], 0);
        if (field === undefined) {
            return NaN;
        }
        var value = numericValue(field.value, 0);
        if (!isFinite(value) || value < 0) {
            return NaN;
        }
        var key = normalizedKey(field.key);
        var multiplier = key.indexOf("bytes") !== -1 ? 1 : byteMultiplier(metadataText(field));
        if (!isFinite(multiplier)) {
            return NaN;
        }
        return value * multiplier;
    }

    function normalizeRecord(record, hintedPid) {
        if (record === null || typeof record !== "object") {
            return null;
        }
        var pid = pidFromRecord(record, hintedPid);
        if (pid <= 0) {
            return null;
        }
        var entry = { "pid": pid };
        var name = processNameFromRecord(record);
        var cpu = cpuValueFromRecord(record);
        var memory = memoryValueFromRecord(record);
        if (name !== "") entry.name = name;
        if (isFinite(cpu)) entry.cpuPercent = cpu;
        if (isFinite(memory)) entry.memoryBytes = memory;
        return safeObjectKeys(entry).length > 1 ? entry : null;
    }

    function completeness(entry) {
        var score = 0;
        if (entry.name !== undefined) score += 4;
        if (entry.cpuPercent !== undefined) score += 2;
        if (entry.memoryBytes !== undefined) score += 2;
        return score;
    }

    function mergeEntry(target, incoming) {
        if (target === undefined || completeness(incoming) > completeness(target)) {
            target = target === undefined ? { "pid": incoming.pid } : target;
        }
        if (incoming.name !== undefined) target.name = incoming.name;
        if (incoming.cpuPercent !== undefined) target.cpuPercent = incoming.cpuPercent;
        if (incoming.memoryBytes !== undefined) target.memoryBytes = incoming.memoryBytes;
        return target;
    }

    function collectRecords(value, hintedPid, depth, result, visited) {
        if (value === null || value === undefined || depth > maximumTraversalDepth
                || result.length >= maximumNormalizedEntries || typeof value !== "object") {
            return;
        }
        if (visited.indexOf(value) !== -1) {
            return;
        }
        visited.push(value);

        var entry = normalizeRecord(value, hintedPid);
        if (entry !== null) {
            result.push(entry);
            return;
        }

        if (Array.isArray(value)) {
            for (var arrayIndex = 0; arrayIndex < value.length; ++arrayIndex) {
                collectRecords(value[arrayIndex], -1, depth + 1, result, visited);
            }
            return;
        }

        var keys = safeObjectKeys(value);
        for (var index = 0; index < keys.length; ++index) {
            var key = keys[index];
            var child = value[key];
            if (child !== null && typeof child === "object") {
                var keyPid = safeIntegerPid(key);
                collectRecords(child, keyPid > 0 ? keyPid : -1,
                               depth + 1, result, visited);
            }
        }
    }

    function deduplicate(entries) {
        var byPid = ({});
        for (var index = 0; index < entries.length; ++index) {
            var entry = entries[index];
            byPid[String(entry.pid)] = mergeEntry(byPid[String(entry.pid)], entry);
        }
        var result = [];
        var pids = safeObjectKeys(byPid);
        for (index = 0; index < pids.length; ++index) {
            result.push(byPid[pids[index]]);
        }
        result.sort(function(left, right) { return left.pid - right.pid; });
        return result;
    }

    function structureType(payload) {
        if (Array.isArray(payload)) return "array";
        if (payload !== null && typeof payload === "object") {
            var keys = safeObjectKeys(payload);
            var numeric = 0;
            for (var index = 0; index < keys.length; ++index) {
                if (safeIntegerPid(keys[index]) > 0) ++numeric;
            }
            return numeric > 0 ? "map-keyed-by-pid" : "nested-map";
        }
        return typeof payload;
    }

    function topLevelFieldNames(payload) {
        var names = [];
        function addRecordFields(value, depth) {
            if (value === null || typeof value !== "object" || depth > 3 || names.length >= 40) return;
            var keys = safeObjectKeys(value);
            for (var index = 0; index < keys.length; ++index) {
                var key = keys[index];
                var normalized = normalizedKey(key);
                if (["pid", "processid", "name", "processname", "comm", "executable", "exe",
                     "cpupercent", "cpuusage", "totalcpuusage", "cpu", "usagepercent",
                     "residentmemorybytes", "rssbytes", "physicalmemorybytes",
                     "residentmemory", "resident", "rss", "physicalmemory", "realmemory"].indexOf(normalized) !== -1
                        && names.indexOf(key) === -1) names.push(key);
                if (value[key] !== null && typeof value[key] === "object") addRecordFields(value[key], depth + 1);
            }
        }
        addRecordFields(payload, 0);
        names.sort();
        return names;
    }

    function logOnce(key, message) {
        if (!debugProcesses || debugSignatures[key]) return;
        debugSignatures[key] = true;
        console.log("TTop Desk processes: " + message);
    }

    function rejectOnce(sourceName, reason) {
        var signature = sourceName + "|" + reason;
        if (rejectedSignatures[signature]) return;
        rejectedSignatures[signature] = true;
        logOnce("reject|" + signature, "rejected " + sourceName + " (" + reason + ")");
    }

    function publish(entries, sourceName, structure) {
        entries = deduplicate(entries);
        if (entries.length === 0) return false;
        processEntries = entries;
        processCount = entries.length;
        selectedProcessSource = sourceName;
        selectedProcessStructure = structure;
        processState = "available";
        lastError = "";
        lastUsableDataMs = Date.now();

        var cpuCount = 0;
        var cpuMaximum = -1;
        var memoryCount = 0;
        for (var index = 0; index < entries.length; ++index) {
            if (entries[index].cpuPercent !== undefined) {
                ++cpuCount;
                cpuMaximum = Math.max(cpuMaximum, entries[index].cpuPercent);
            }
            if (entries[index].memoryBytes !== undefined) ++memoryCount;
        }
        logOnce("selected|" + sourceName + "|" + structure,
                "selected " + sourceName + " with structure " + structure);
        logOnce("count|" + sourceName + "|" + structure,
                "normalized process count: " + entries.length);
        if (cpuCount > 0) {
            logOnce("cpu|" + sourceName,
                    "CPU observations: " + cpuCount + " usable values; maximum "
                    + cpuMaximum + "; non-negative raw semantics preserved and not clamped");
        }
        if (memoryCount > 0) {
            logOnce("memory|" + sourceName,
                    "memory observations: " + memoryCount
                    + " resident/RSS values normalized to bytes from explicit units");
        }
        return true;
    }

    function handleAggregateData(sourceName, payload) {
        var structure = structureType(payload);
        logOnce("structure|" + sourceName,
                "candidate " + sourceName + " has structure " + structure);
        logOnce("fields|" + sourceName,
                "available process field names: "
                + (topLevelFieldNames(payload).join(", ") || "(none recognized)"));
        var records = [];
        collectRecords(payload, -1, 0, records, []);
        var entries = deduplicate(records);
        if (entries.length === 0) {
            rejectOnce(sourceName, "no defensively recognizable process records");
            return false;
        }
        var score = entries.length * 10;
        for (var index = 0; index < entries.length; ++index) score += completeness(entries[index]);
        if (selectedAggregateSource !== "" && sourceName !== selectedAggregateSource
                && score < selectedAggregateScore) return false;
        selectedAggregateSource = sourceName;
        selectedAggregateScore = score;
        return publish(entries, sourceName, structure);
    }

    function processSourceDescriptor(sourceName) {
        var parts = String(sourceName).split("/");
        var pid = -1;
        for (var index = 0; index < parts.length; ++index) {
            var candidate = safeIntegerPid(parts[index]);
            if (candidate > 0) {
                pid = candidate;
                break;
            }
        }
        if (pid <= 0) return null;
        var leaf = normalizedKey(parts[parts.length - 1]);
        var role = "";
        if (["name", "processname", "comm", "executable", "exename", "exe"].indexOf(leaf) !== -1) role = "name";
        else if (["cpupercent", "cpuusage", "totalcpuusage", "cpu", "usagepercent"].indexOf(leaf) !== -1) role = "cpu";
        else if (["residentmemorybytes", "rssbytes", "physicalmemorybytes", "residentmemory",
                  "resident", "rss", "physicalmemory", "realmemory", "memoryresident"].indexOf(leaf) !== -1) role = "memory";
        return role === "" ? null : { "pid": pid, "role": role, "leaf": leaf };
    }

    function handlePerProcessData(sourceName, payload, descriptor) {
        var key = String(descriptor.pid);
        var record = perProcessRecords[key];
        if (record === undefined) record = { "pid": descriptor.pid, "updatedMs": Date.now() };
        if (descriptor.role === "name") {
            var wrappedName = payload !== null && typeof payload === "object"
                              && payload.value !== undefined ? payload.value : payload;
            var name = sanitizedName(wrappedName, descriptor.leaf);
            if (name !== "") record.name = name;
        } else if (descriptor.role === "cpu") {
            var cpuRecord = ({});
            cpuRecord[descriptor.leaf] = payload;
            var cpu = cpuValueFromRecord(cpuRecord);
            if (isFinite(cpu)) record.cpuPercent = cpu;
        } else if (descriptor.role === "memory") {
            var memoryRecord = ({});
            memoryRecord[descriptor.leaf] = payload;
            var memory = memoryValueFromRecord(memoryRecord);
            if (isFinite(memory)) record.memoryBytes = memory;
        }
        record.updatedMs = Date.now();
        perProcessRecords[key] = record;
        publishPerProcessRecords();
    }

    function publishPerProcessRecords() {
        var now = Date.now();
        var records = perProcessRecords;
        var entries = [];
        var keys = safeObjectKeys(records);
        for (var index = 0; index < keys.length; ++index) {
            var record = records[keys[index]];
            if (now - record.updatedMs > 8000) {
                delete records[keys[index]];
                continue;
            }
            var entry = { "pid": record.pid };
            if (record.name !== undefined) entry.name = record.name;
            if (record.cpuPercent !== undefined) entry.cpuPercent = record.cpuPercent;
            if (record.memoryBytes !== undefined) entry.memoryBytes = record.memoryBytes;
            if (safeObjectKeys(entry).length > 1) entries.push(entry);
        }
        perProcessRecords = records;
        if (entries.length > 0 && selectedAggregateSource === "") {
            publish(entries, "per-process sensor family", "one-source-per-process-field");
        } else if (entries.length === 0
                   && selectedProcessStructure === "one-source-per-process-field") {
            processEntries = [];
            processCount = 0;
            selectedProcessSource = "";
            selectedProcessStructure = "";
            processState = "detecting";
            candidateSignature = "__per_process_expired__";
            logOnce("per-process-expired",
                    "per-process sensor records expired; rediscovering");
            discoveryTimer.restart();
            deadlineTimer.restart();
        }
    }

    function handleData(sourceName, payload) {
        var descriptor = processSourceDescriptor(sourceName);
        if (descriptor !== null) {
            handlePerProcessData(sourceName, payload, descriptor);
            return;
        }
        handleAggregateData(sourceName, payload);
    }

    function isProcessRelatedSource(sourceName) {
        var text = String(sourceName).toLowerCase();
        return /(^|[\/_ -])(process|processes|proc|task|tasks)([\/_ -]|$)/.test(text);
    }

    function pushUnique(values, value) {
        if (values.indexOf(value) === -1) values.push(value);
    }

    function collectSensorTreeSources(parentIndex, isRoot, result) {
        if (result.length >= maximumCandidateSources) return;
        var count = isRoot ? sensorTree.rowCount() : sensorTree.rowCount(parentIndex);
        for (var row = 0; row < count && result.length < maximumCandidateSources; ++row) {
            var index = isRoot ? sensorTree.index(row, 0) : sensorTree.index(row, 0, parentIndex);
            var sensorId = sensorTree.data(index, Sensors.SensorTreeModel.SensorId);
            if (sensorId !== undefined && sensorId !== null && isProcessRelatedSource(sensorId)) {
                pushUnique(result, String(sensorId));
            }
            collectSensorTreeSources(index, false, result);
        }
    }

    function discoverSources() {
        if (processAvailable && selectedProcessSource !== "") return;
        var candidates = [];
        for (var index = 0; index < monitor.sources.length; ++index) {
            var source = String(monitor.sources[index]);
            if (isProcessRelatedSource(source)) pushUnique(candidates, source);
        }
        collectSensorTreeSources(null, true, candidates);
        candidates.sort();
        if (candidates.length > maximumCandidateSources) candidates.length = maximumCandidateSources;
        var signature = candidates.join("\n");
        if (signature !== candidateSignature) {
            candidateSignature = signature;
            processCandidateSources = candidates;
            logOnce("discovery|" + signature,
                    "discovered process-related sources: "
                    + (candidates.length > 0 ? candidates.join(", ") : "(none)"));
        }
    }

    function handleSourceLoss(sourceName) {
        var selectedLost = selectedAggregateSource === sourceName;
        if (!selectedLost && processCandidateSources.indexOf(sourceName) === -1) return;
        if (selectedLost) {
            selectedAggregateSource = "";
            selectedAggregateScore = -1;
            selectedProcessSource = "";
            selectedProcessStructure = "";
            processEntries = [];
            processCount = 0;
            processState = "detecting";
            logOnce("loss|" + sourceName, "selected source lost: " + sourceName + "; rediscovering");
        }
        candidateSignature = "__source_lost__";
        discoveryTimer.restart();
        deadlineTimer.restart();
    }

    PlasmaCore.DataSource {
        id: monitor
        engine: "systemmonitor"
        interval: provider.probeIntervalMs
        connectedSources: provider.processCandidateSources
        onNewData: provider.handleData(sourceName, data)
        onSourceAdded: discoveryTimer.restart()
        onSourceRemoved: provider.handleSourceLoss(source)
    }

    Sensors.SensorTreeModel {
        id: sensorTree
        onRowsInserted: discoveryTimer.restart()
        onRowsRemoved: discoveryTimer.restart()
        onModelReset: discoveryTimer.restart()
    }

    Instantiator {
        model: provider.processCandidateSources
        delegate: Sensors.Sensor {
            sensorId: modelData
            updateRateLimit: provider.probeIntervalMs
            function publishValue() {
                if (value !== null && value !== undefined && value !== "") {
                    provider.handleData(sensorId, {
                        "value": value,
                        "maximum": maximum,
                        "unit": unit,
                        "formattedValue": formattedValue,
                        "name": name,
                        "shortName": shortName,
                        "description": description
                    });
                }
            }
            onValueChanged: publishValue()
            onNameChanged: publishValue()
            onStatusChanged: {
                if (status === Sensors.Sensor.Error || status === Sensors.Sensor.Removed) {
                    provider.handleSourceLoss(sensorId);
                }
            }
        }
    }

    Timer {
        id: discoveryTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: provider.discoverSources()
    }

    Timer {
        interval: provider.probeIntervalMs
        repeat: true
        running: !provider.processAvailable
        onTriggered: provider.discoverSources()
    }

    Timer {
        interval: provider.probeIntervalMs
        repeat: true
        running: provider.selectedProcessStructure === "one-source-per-process-field"
        onTriggered: provider.publishPerProcessRecords()
    }

    Timer {
        id: deadlineTimer
        interval: 10000
        repeat: false
        running: true
        onTriggered: {
            if (!provider.processAvailable) {
                provider.processState = "unavailable";
                provider.processEntries = [];
                provider.processCount = 0;
                provider.selectedProcessSource = "";
                provider.selectedProcessStructure = "";
                provider.lastError = "No usable per-process data was exposed by Plasma system-monitor sensors";
                provider.logOnce("unavailable", provider.lastError);
            }
        }
    }
}

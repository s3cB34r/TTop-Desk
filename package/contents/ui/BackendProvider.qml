/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "TTop/Backend" as BackendBridge

Item {
    id: provider

    property bool enabled: true
    property bool processesEnabled: true
    property bool gpuEnabled: true
    property bool autoPoll: true
    property bool debugBackend: false
    property int refreshIntervalMs: 2000
    property int maximumProcessEntries: 5
    property string processSortMode: "cpu"
    property int gpuRefreshIntervalMs: 1000
    property var socketClient: ttopBackendSocketBridge
    property string socketPath: socketClient.defaultSocketPath()

    readonly property bool backendAvailable: backendState === "connected"
    readonly property bool backendConnected: backendAvailable
    readonly property bool backendServiceAvailable: backendAvailable
    property string backendState: "detecting"
    property var processEntries: []
    property int processCount: 0
    property string backendError: ""
    property real backendLastResponse: 0
    property int backendProtocolVersion: 0
    property bool boundedProcessRequestSupported: true
    property string lastRequestCommand: ""
    property string inFlightCommand: ""
    property var requestQueue: []

    readonly property bool gpuAvailable: gpuState === "available"
    property string gpuState: "detecting"
    property string gpuError: ""
    property string gpuName: ""
    property real gpuUtilizationPercent: NaN
    property real gpuMemoryUsedBytes: NaN
    property real gpuMemoryTotalBytes: NaN
    property real gpuMemoryPercent: NaN
    property real gpuTemperatureCelsius: NaN
    readonly property string gpuMemoryDisplayText:
        isFinite(gpuMemoryUsedBytes) && isFinite(gpuMemoryTotalBytes)
        ? formatBytes(gpuMemoryUsedBytes) + " / " + formatBytes(gpuMemoryTotalBytes)
          + (isFinite(gpuMemoryPercent) ? "  ·  " + gpuMemoryPercent.toFixed(1) + "%" : "")
        : ""
    readonly property string gpuTemperatureDisplayText:
        isFinite(gpuTemperatureCelsius) ? gpuTemperatureCelsius.toFixed(1) + " °C" : ""

    readonly property int effectiveRefreshIntervalMs:
        [1000, 2000, 5000].indexOf(Number(refreshIntervalMs)) !== -1
        ? Number(refreshIntervalMs) : 2000
    readonly property int effectiveMaximumProcessEntries:
        [3, 4, 5].indexOf(Number(maximumProcessEntries)) !== -1
        ? Number(maximumProcessEntries) : 5
    readonly property string effectiveProcessSortMode:
        processSortMode === "memory" ? "memory" : "cpu"
    readonly property int effectiveGpuRefreshIntervalMs:
        [500, 1000, 2000, 5000].indexOf(Number(gpuRefreshIntervalMs)) !== -1
        ? Number(gpuRefreshIntervalMs) : 1000
    readonly property int retryIntervalMs: 5000

    property string lastLoggedState: ""
    property int lastLoggedCount: -1
    property string lastLoggedGpuState: ""

    function setState(state, errorText) {
        backendState = state;
        backendError = errorText || "";
        if (debugBackend && lastLoggedState !== state) {
            lastLoggedState = state;
            console.log("TTop Desk backend: state changed to " + state);
        }
    }

    function clearProcesses() {
        processEntries = [];
        processCount = 0;
    }

    function setGpuState(state, errorText) {
        gpuState = state;
        gpuError = errorText || "";
        if (debugBackend && lastLoggedGpuState !== state) {
            lastLoggedGpuState = state;
            console.log("TTop Desk GPU: state changed to " + state);
        }
    }

    function clearGpu() {
        gpuName = "";
        gpuUtilizationPercent = NaN;
        gpuMemoryUsedBytes = NaN;
        gpuMemoryTotalBytes = NaN;
        gpuMemoryPercent = NaN;
        gpuTemperatureCelsius = NaN;
    }

    function formatBytes(bytes) {
        if (!isFinite(bytes) || bytes < 0) return "";
        var gibibyte = 1024 * 1024 * 1024;
        var mebibyte = 1024 * 1024;
        return bytes >= gibibyte ? (bytes / gibibyte).toFixed(1) + " GiB"
                                : (bytes / mebibyte).toFixed(0) + " MiB";
    }

    function finiteNonnegative(value) {
        if (value === null || value === undefined || value === "") return NaN;
        var number = Number(value);
        return isFinite(number) && number >= 0 ? number : NaN;
    }

    function safePid(value) {
        var pid = Number(value);
        return isFinite(pid) && pid > 0 && Math.floor(pid) === pid
               && pid <= 2147483647 ? pid : -1;
    }

    function normalizeProcess(entry) {
        if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
            return null;
        }
        var pid = safePid(entry.pid);
        var cpu = finiteNonnegative(entry.cpuPercent);
        var memory = finiteNonnegative(entry.memoryBytes);
        if (pid <= 0 || typeof entry.name !== "string") {
            return null;
        }
        if (effectiveProcessSortMode === "cpu" && !isFinite(cpu)) return null;
        if (effectiveProcessSortMode === "memory" && !isFinite(memory)) return null;
        var name = entry.name.replace(/^\s+|\s+$/g, "");
        if (name === "" || name.length > 256 || name.indexOf("\u0000") !== -1) {
            return null;
        }
        var normalized = { "pid": pid, "name": name };
        if (isFinite(cpu)) normalized.cpuPercent = cpu;
        if (isFinite(memory)) normalized.memoryBytes = memory;
        return normalized;
    }

    function processOrder(left, right) {
        var metric = effectiveProcessSortMode === "memory" ? "memoryBytes" : "cpuPercent";
        var leftValue = finiteNonnegative(left[metric]);
        var rightValue = finiteNonnegative(right[metric]);
        if (!isFinite(leftValue)) leftValue = -1;
        if (!isFinite(rightValue)) rightValue = -1;
        if (leftValue !== rightValue) {
            return rightValue - leftValue;
        }
        var nameOrder = left.name.localeCompare(right.name);
        return nameOrder !== 0 ? nameOrder : left.pid - right.pid;
    }

    function normalizeGpu(entry) {
        if (entry === null || typeof entry !== "object" || Array.isArray(entry)) return null;
        var index = Number(entry.index);
        if (!isFinite(index) || index < 0 || Math.floor(index) !== index) return null;
        var name = typeof entry.name === "string"
                   ? entry.name.replace(/^\s+|\s+$/g, "") : "";
        if (name === "" || name.length > 256 || name.indexOf("\u0000") !== -1) {
            name = "NVIDIA GPU";
        }
        var normalized = { "index": index, "name": name };
        var utilization = finiteNonnegative(entry.utilizationPercent);
        if (isFinite(utilization) && utilization <= 100) {
            normalized.utilizationPercent = utilization;
        }
        var used = finiteNonnegative(entry.memoryUsedBytes);
        var total = finiteNonnegative(entry.memoryTotalBytes);
        if (isFinite(used) && isFinite(total) && total > 0 && used <= total) {
            normalized.memoryUsedBytes = used;
            normalized.memoryTotalBytes = total;
            normalized.memoryPercent = Math.max(0, Math.min(100, used * 100 / total));
        }
        var temperature = Number(entry.temperatureCelsius);
        if (isFinite(temperature) && temperature >= -20 && temperature <= 150) {
            normalized.temperatureCelsius = temperature;
        }
        return normalized;
    }

    function handleProcessResponse(response, requestCommand) {
        if (!processesEnabled) return;
        if (response.status === "error") {
            if (response.error === "unsupported_command"
                    && requestCommand === "processes") {
                boundedProcessRequestSupported = false;
                setState("detecting", "");
                if (debugBackend) {
                    console.log("TTop Desk backend: bounded process request unsupported; using snapshot fallback");
                }
                fallbackTimer.restart();
                return;
            }
            clearProcesses();
            setState("error", String(response.error || "backend_error"));
            if (debugBackend) console.log("TTop Desk backend: protocol error " + backendError);
            return;
        }
        if (!Array.isArray(response.processes)) {
            clearProcesses();
            setState("error", "missing_processes");
            return;
        }
        var normalized = [];
        var rejected = 0;
        for (var index = 0; index < response.processes.length; ++index) {
            var sourceEntry = response.processes[index];
            if (effectiveProcessSortMode === "cpu"
                    && sourceEntry !== null && typeof sourceEntry === "object"
                    && !Array.isArray(sourceEntry)
                    && sourceEntry.cpuPercent === undefined) {
                continue;
            }
            var process = normalizeProcess(sourceEntry);
            if (process !== null) normalized.push(process);
            else ++rejected;
        }
        normalized.sort(processOrder);
        if (normalized.length > effectiveMaximumProcessEntries) {
            normalized.length = effectiveMaximumProcessEntries;
        }
        processEntries = normalized;
        processCount = normalized.length;
        backendLastResponse = Date.now();
        setState("connected", "");
        if (debugBackend && rejected > 0) {
            console.log("TTop Desk backend: rejected " + rejected + " malformed process entries");
        }
        if (debugBackend && lastLoggedCount !== processCount) {
            lastLoggedCount = processCount;
            console.log("TTop Desk backend: normalized process count " + processCount);
        }
    }

    function handleGpuResponse(response) {
        if (!gpuEnabled) return;
        if (response.status === "error") {
            clearGpu();
            setState("connected", "");
            setGpuState(response.error === "unsupported_command" ? "unavailable" : "error",
                        String(response.error || "gpu_error"));
            return;
        }
        if (!Array.isArray(response.gpus)) {
            clearGpu();
            setState("connected", "");
            setGpuState("error", "missing_gpus");
            return;
        }
        var selected = null;
        if (response.gpus.length === 1) {
            selected = normalizeGpu(response.gpus[0]);
        } else {
            for (var index = 0; index < response.gpus.length; ++index) {
                var candidate = normalizeGpu(response.gpus[index]);
                if (candidate !== null && candidate.index === 0) {
                    selected = candidate;
                    break;
                }
            }
        }
        clearGpu();
        backendLastResponse = Date.now();
        setState("connected", "");
        if (selected === null) {
            setGpuState("unavailable", "no_supported_gpu");
            return;
        }
        gpuName = selected.name;
        gpuUtilizationPercent = selected.utilizationPercent === undefined
                                ? NaN : selected.utilizationPercent;
        gpuMemoryUsedBytes = selected.memoryUsedBytes === undefined
                             ? NaN : selected.memoryUsedBytes;
        gpuMemoryTotalBytes = selected.memoryTotalBytes === undefined
                              ? NaN : selected.memoryTotalBytes;
        gpuMemoryPercent = selected.memoryPercent === undefined
                           ? NaN : selected.memoryPercent;
        gpuTemperatureCelsius = selected.temperatureCelsius === undefined
                                ? NaN : selected.temperatureCelsius;
        setGpuState("available", "");
    }

    function handleResponse(responseText, requestCommand) {
        if (!enabled) return;
        var response;
        try {
            response = JSON.parse(responseText);
        } catch (error) {
            setState("error", "malformed_response");
            if (requestCommand === "gpu") setGpuState("error", "malformed_response");
            else clearProcesses();
            return;
        }
        if (response === null || typeof response !== "object"
                || Number(response.version) !== 1) {
            setState("error", "unsupported_protocol");
            if (requestCommand === "gpu") setGpuState("error", "unsupported_protocol");
            else clearProcesses();
            return;
        }
        backendProtocolVersion = Number(response.version);
        if (requestCommand === "gpu") handleGpuResponse(response);
        else if (requestCommand === "processes" || requestCommand === "snapshot") {
            handleProcessResponse(response, requestCommand);
        } else {
            setState("error", "unexpected_response");
        }
    }

    function completeResponse(responseText) {
        var requestCommand = inFlightCommand;
        inFlightCommand = "";
        handleResponse(responseText, requestCommand);
        dispatchTimer.restart();
    }

    function enqueueRequest(requestType) {
        if (requestType !== "processes" && requestType !== "gpu") return;
        if (inFlightCommand === requestType
                || (requestType === "processes" && inFlightCommand === "snapshot")) {
            return;
        }
        if (requestQueue.indexOf(requestType) !== -1) {
            sendNextRequest();
            return;
        }
        var queued = requestQueue.slice(0);
        queued.push(requestType);
        requestQueue = queued;
        sendNextRequest();
    }

    function sendNextRequest() {
        if (!enabled || socketClient === null || socketClient.busy
                || inFlightCommand !== "" || requestQueue.length === 0) {
            return;
        }
        var queued = requestQueue.slice(0);
        var requestType = queued.shift();
        requestQueue = queued;
        var command = requestType;
        var payload = "";
        if (requestType === "processes") {
            command = boundedProcessRequestSupported ? "processes" : "snapshot";
            payload = command === "processes" ? JSON.stringify({
                "command": "processes",
                "sort": effectiveProcessSortMode,
                "limit": effectiveMaximumProcessEntries
            }) : '{"command":"snapshot"}';
        } else {
            payload = '{"command":"gpu"}';
        }
        inFlightCommand = command;
        lastRequestCommand = command;
        if (!socketClient.request(payload)) {
            inFlightCommand = "";
            queued = requestQueue.slice(0);
            queued.unshift(requestType);
            requestQueue = queued;
            return;
        }
    }

    function requestProcesses() {
        if (!enabled || !processesEnabled || socketClient === null) return;
        if (debugBackend && (backendState === "unavailable" || backendState === "error")) {
            console.log("TTop Desk backend: reconnect attempt");
        }
        enqueueRequest("processes");
    }

    function requestGpu() {
        if (!enabled || !gpuEnabled || socketClient === null) return;
        if (debugBackend && backendState === "unavailable") {
            console.log("TTop Desk GPU: reconnect attempt");
        }
        enqueueRequest("gpu");
    }

    function discardQueuedRequest(requestType) {
        var queued = requestQueue.slice(0);
        var index = queued.indexOf(requestType);
        if (index !== -1) {
            queued.splice(index, 1);
            requestQueue = queued;
        }
    }

    onEnabledChanged: {
        if (enabled) {
            setState("detecting", "");
            if (processesEnabled) processPollTimer.restart();
            if (gpuEnabled) gpuPollTimer.restart();
        } else {
            requestQueue = [];
            clearProcesses();
            clearGpu();
            setState("unavailable", "");
            setGpuState("unavailable", "");
        }
    }
    onProcessesEnabledChanged: {
        if (processesEnabled && enabled) {
            setState("detecting", "");
            processPollTimer.restart();
        } else {
            discardQueuedRequest("processes");
            clearProcesses();
        }
    }
    onGpuEnabledChanged: {
        clearGpu();
        if (gpuEnabled && enabled) {
            setGpuState("detecting", "");
            gpuPollTimer.restart();
        } else {
            discardQueuedRequest("gpu");
            setGpuState("unavailable", "");
        }
    }
    onEffectiveMaximumProcessEntriesChanged: {
        if (processEntries.length > effectiveMaximumProcessEntries) {
            var limited = processEntries.slice(0, effectiveMaximumProcessEntries);
            processEntries = limited;
            processCount = limited.length;
        }
        if (enabled) configurationRequestTimer.restart();
    }
    onEffectiveProcessSortModeChanged: {
        clearProcesses();
        if (enabled) {
            setState("detecting", "");
            configurationRequestTimer.restart();
        }
    }

    Binding {
        target: provider.socketClient
        property: "socketPath"
        value: provider.socketPath
        when: provider.socketClient !== null
    }

    Connections {
        target: provider.socketClient
        function onResponseReceived(jsonLine) {
            provider.completeResponse(jsonLine);
        }
        function onTransportError(errorCode) {
            provider.inFlightCommand = "";
            provider.requestQueue = [];
            provider.clearProcesses();
            provider.clearGpu();
            provider.boundedProcessRequestSupported = true;
            provider.setState("unavailable", errorCode);
            provider.setGpuState("unavailable", errorCode);
        }
    }

    Timer {
        id: dispatchTimer
        interval: 0
        repeat: false
        onTriggered: provider.sendNextRequest()
    }

    Timer {
        id: fallbackTimer
        interval: 100
        repeat: false
        onTriggered: provider.requestProcesses()
    }

    Timer {
        id: configurationRequestTimer
        interval: 50
        repeat: false
        onTriggered: provider.requestProcesses()
    }

    Timer {
        id: processPollTimer
        interval: provider.backendState === "unavailable"
                  || provider.backendState === "error"
                  ? provider.retryIntervalMs : provider.effectiveRefreshIntervalMs
        repeat: true
        running: provider.enabled && provider.processesEnabled && provider.autoPoll
        triggeredOnStart: true
        onTriggered: provider.requestProcesses()
    }

    Timer {
        id: gpuPollTimer
        interval: provider.backendState === "unavailable"
                  || provider.backendState === "error"
                  || provider.gpuState === "unavailable"
                  ? provider.retryIntervalMs : provider.effectiveGpuRefreshIntervalMs
        repeat: true
        running: provider.enabled && provider.gpuEnabled && provider.autoPoll
        triggeredOnStart: true
        onTriggered: provider.requestGpu()
    }
}

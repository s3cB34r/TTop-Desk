/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "TTop/Backend" as BackendBridge

Item {
    id: provider

    property bool enabled: true
    property bool autoPoll: true
    property bool debugBackend: false
    property int refreshIntervalMs: 2000
    property int maximumProcessEntries: 5
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

    readonly property int effectiveRefreshIntervalMs:
        [1000, 2000, 5000].indexOf(Number(refreshIntervalMs)) !== -1
        ? Number(refreshIntervalMs) : 2000
    readonly property int effectiveMaximumProcessEntries:
        Math.max(3, Math.min(5, Math.round(Number(maximumProcessEntries) || 5)))
    readonly property int retryIntervalMs: 5000

    property string lastLoggedState: ""
    property int lastLoggedCount: -1

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
        if (pid <= 0 || !isFinite(cpu) || typeof entry.name !== "string") {
            return null;
        }
        var name = entry.name.replace(/^\s+|\s+$/g, "");
        if (name === "" || name.length > 256 || name.indexOf("\u0000") !== -1) {
            return null;
        }
        var normalized = { "pid": pid, "name": name, "cpuPercent": cpu };
        var memory = finiteNonnegative(entry.memoryBytes);
        if (isFinite(memory)) normalized.memoryBytes = memory;
        return normalized;
    }

    function processOrder(left, right) {
        if (left.cpuPercent !== right.cpuPercent) {
            return right.cpuPercent - left.cpuPercent;
        }
        var nameOrder = left.name.localeCompare(right.name);
        return nameOrder !== 0 ? nameOrder : left.pid - right.pid;
    }

    function handleResponse(responseText) {
        if (!enabled) {
            clearProcesses();
            setState("unavailable", "");
            return;
        }
        var response;
        try {
            response = JSON.parse(responseText);
        } catch (error) {
            clearProcesses();
            setState("error", "malformed_response");
            if (debugBackend) console.log("TTop Desk backend: malformed JSON response");
            return;
        }

        if (response === null || typeof response !== "object"
                || Number(response.version) !== 1) {
            clearProcesses();
            setState("error", "unsupported_protocol");
            if (debugBackend) console.log("TTop Desk backend: protocol version error");
            return;
        }
        backendProtocolVersion = Number(response.version);
        if (response.status === "error") {
            if (response.error === "unsupported_command"
                    && lastRequestCommand === "processes") {
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
            if (debugBackend) console.log("TTop Desk backend: snapshot has no process array");
            return;
        }

        var normalized = [];
        var rejected = 0;
        for (var index = 0; index < response.processes.length; ++index) {
            var sourceEntry = response.processes[index];
            // A missing CPU field is the backend's intentional first-sample
            // warm-up state, not malformed data and not suitable for ranking.
            if (sourceEntry !== null && typeof sourceEntry === "object"
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

    function requestProcesses() {
        if (!enabled || socketClient === null || socketClient.busy) return;
        if (debugBackend && (backendState === "unavailable" || backendState === "error")) {
            console.log("TTop Desk backend: reconnect attempt");
        }
        if (boundedProcessRequestSupported) {
            lastRequestCommand = "processes";
            socketClient.request(JSON.stringify({
                "command": "processes",
                "sort": "cpu",
                "limit": effectiveMaximumProcessEntries
            }));
        } else {
            lastRequestCommand = "snapshot";
            socketClient.request('{"command":"snapshot"}');
        }
    }

    onEnabledChanged: {
        if (enabled) {
            setState("detecting", "");
            pollTimer.restart();
        } else {
            clearProcesses();
            setState("unavailable", "");
        }
    }
    onEffectiveMaximumProcessEntriesChanged: {
        if (processEntries.length > effectiveMaximumProcessEntries) {
            var limited = processEntries.slice(0, effectiveMaximumProcessEntries);
            processEntries = limited;
            processCount = limited.length;
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
            provider.handleResponse(jsonLine);
        }
        function onTransportError(errorCode) {
            provider.clearProcesses();
            provider.boundedProcessRequestSupported = true;
            provider.setState("unavailable", errorCode);
        }
    }

    Timer {
        id: fallbackTimer
        interval: 100
        repeat: false
        onTriggered: provider.requestProcesses()
    }

    Timer {
        id: pollTimer
        interval: provider.backendState === "unavailable"
                  || provider.backendState === "error"
                  ? provider.retryIntervalMs : provider.effectiveRefreshIntervalMs
        repeat: true
        running: provider.enabled && provider.autoPoll
        triggeredOnStart: true
        onTriggered: provider.requestProcesses()
    }
}

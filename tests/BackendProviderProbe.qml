/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui" as Ui

Item {
    QtObject {
        id: fakeSocketClient
        property bool busy: false
        property string socketPath: ""
        property var requests: []
        signal responseReceived(string jsonLine)
        signal transportError(string errorCode)

        function defaultSocketPath() {
            return "/tmp/ttop-desk-probe.sock";
        }

        function request(payload) {
            requests.push(payload);
            return true;
        }
    }

    function fail(message) {
        console.error("TTop Desk backend provider probe: FAIL: " + message);
        Qt.exit(1);
    }

    Ui.BackendProvider {
        id: provider
        enabled: true
        autoPoll: false
        maximumProcessEntries: 5
        socketClient: fakeSocketClient
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            provider.refreshIntervalMs = 1000;
            if (provider.effectiveRefreshIntervalMs !== 1000) {
                fail("process refresh interval did not update live");
            }
            provider.refreshIntervalMs = 0;
            if (provider.effectiveRefreshIntervalMs !== 2000) {
                fail("invalid process refresh interval did not use its default");
            }
            provider.refreshIntervalMs = 2000;

            provider.requestProcesses();
            var boundedRequest = JSON.parse(fakeSocketClient.requests.shift());
            if (boundedRequest.command !== "processes"
                    || boundedRequest.sort !== "cpu"
                    || boundedRequest.limit !== 5) {
                fail("bounded process request is incorrect");
            }
            provider.completeResponse(JSON.stringify({
                "status": "ok", "version": 1, "processes": []
            }));

            provider.maximumProcessEntries = 3;
            provider.requestProcesses();
            if (JSON.parse(fakeSocketClient.requests.shift()).limit !== 3) {
                fail("process limit 3 was not applied");
            }
            provider.completeResponse(JSON.stringify({
                "status": "ok", "version": 1, "processes": []
            }));
            provider.processSortMode = "memory";
            provider.maximumProcessEntries = 4;
            provider.requestProcesses();
            var memoryRequest = JSON.parse(fakeSocketClient.requests.shift());
            if (memoryRequest.sort !== "memory" || memoryRequest.limit !== 4) {
                fail("live process sort or limit was not applied");
            }
            provider.completeResponse(JSON.stringify({
                "status": "ok",
                "version": 1,
                "sort": "memory",
                "limit": 4,
                "processes": [
                    { "pid": 2, "name": "small", "memoryBytes": 20 },
                    { "pid": 1, "name": "large", "memoryBytes": 100 }
                ]
            }));
            if (provider.processEntries[0].pid !== 1
                    || provider.processEntries[0].cpuPercent !== undefined) {
                fail("memory sorting or CPU warm-up handling is incorrect");
            }

            provider.processSortMode = "cpu";
            provider.maximumProcessEntries = 5;
            provider.requestProcesses();
            if (JSON.parse(fakeSocketClient.requests.shift()).limit !== 5) {
                fail("process limit 5 was not restored");
            }
            provider.completeResponse(JSON.stringify({
                "status": "ok", "version": 1, "processes": []
            }));
            provider.maximumProcessEntries = 3;
            provider.requestProcesses();
            fakeSocketClient.requests.shift();

            provider.completeResponse(JSON.stringify({
                "status": "error",
                "version": 1,
                "error": "unsupported_command"
            }));
            provider.requestProcesses();
            var fallbackRequest = JSON.parse(fakeSocketClient.requests.shift());
            if (fallbackRequest.command !== "snapshot") {
                fail("legacy snapshot fallback was not selected");
            }

            provider.completeResponse(JSON.stringify({
                "version": 1,
                "timestamp": 1720000000.0,
                "processes": [
                    { "pid": 9, "name": "zeta", "cpuPercent": 135.6, "memoryBytes": 1073741824, "username": "private", "cmdline": ["never", "copy"] },
                    { "pid": 5, "name": "alpha", "cpuPercent": 10, "memoryBytes": 50 },
                    { "pid": 2, "name": "alpha", "cpuPercent": 10, "memoryBytes": 20 },
                    { "pid": 3, "name": "beta", "cpuPercent": 1, "memoryBytes": 10 },
                    { "pid": 4, "name": "warming-up", "memoryBytes": 10 }
                ],
                "gpu": null
            }));
            if (provider.backendState !== "connected") fail("response was not accepted");
            if (provider.processCount !== 3) fail("display limit was not enforced");
            if (provider.processEntries[0].pid !== 9
                    || provider.processEntries[1].pid !== 2
                    || provider.processEntries[2].pid !== 5) {
                fail("CPU/name/PID deterministic ordering is incorrect");
            }
            if (provider.processEntries[0].cpuPercent !== 135.6) {
                fail("CPU above 100 percent was changed");
            }
            if (provider.processEntries[0].username !== undefined
                    || provider.processEntries[0].cmdline !== undefined) {
                fail("private or unapproved fields crossed the provider boundary");
            }

            provider.gpuRefreshIntervalMs = 500;
            if (provider.effectiveGpuRefreshIntervalMs !== 500) {
                fail("GPU refresh interval did not update live");
            }
            provider.gpuRefreshIntervalMs = -1;
            if (provider.effectiveGpuRefreshIntervalMs !== 1000) {
                fail("invalid GPU refresh interval did not use its default");
            }
            provider.gpuRefreshIntervalMs = 1000;
            provider.requestGpu();
            var gpuRequest = JSON.parse(fakeSocketClient.requests.shift());
            if (gpuRequest.command !== "gpu") fail("GPU request is incorrect");
            provider.completeResponse(JSON.stringify({
                "status": "ok",
                "version": 1,
                "gpus": [
                    { "index": 1, "name": "Other GPU", "utilizationPercent": 90 },
                    {
                        "index": 0,
                        "name": "  NVIDIA Test GPU  ",
                        "utilizationPercent": 8,
                        "memoryUsedBytes": 2147483648,
                        "memoryTotalBytes": 8589934592,
                        "memoryPercent": 99,
                        "temperatureCelsius": 47,
                        "privateField": "discard"
                    }
                ]
            }));
            if (!provider.gpuAvailable || provider.gpuName !== "NVIDIA Test GPU"
                    || provider.gpuUtilizationPercent !== 8
                    || provider.gpuMemoryPercent !== 25
                    || provider.gpuTemperatureCelsius !== 47) {
                fail("GPU index 0 normalization is incorrect");
            }
            if (provider.gpuMemoryDisplayText.indexOf("2.0 GiB / 8.0 GiB") !== 0
                    || provider.gpuTemperatureDisplayText !== "47.0 °C") {
                fail("GPU display formatting is incorrect");
            }
            if (provider.processCount !== 3 || provider.processEntries[0].pid !== 9) {
                fail("GPU response cleared existing process data");
            }

            var retainedGpuName = provider.gpuName;
            provider.requestProcesses();
            var postGpuProcessRequest = JSON.parse(fakeSocketClient.requests.shift());
            if (postGpuProcessRequest.command !== "snapshot") {
                fail("process request did not remain functional after GPU response");
            }
            provider.completeResponse(JSON.stringify({
                "version": 1,
                "processes": [
                    { "pid": 12, "name": "after-gpu", "cpuPercent": 4.5,
                      "memoryBytes": 104857600 }
                ],
                "gpu": null
            }));
            if (provider.processCount !== 1 || provider.processEntries[0].pid !== 12
                    || provider.gpuName !== retainedGpuName) {
                fail("process response failed or cleared existing GPU data");
            }

            fakeSocketClient.busy = true;
            provider.requestProcesses();
            provider.requestProcesses();
            provider.requestGpu();
            provider.requestGpu();
            if (provider.requestQueue.length !== 2) {
                fail("request queue is not bounded and coalesced by request type");
            }
            fakeSocketClient.busy = false;
            provider.sendNextRequest();
            if (JSON.parse(fakeSocketClient.requests.shift()).command !== "snapshot"
                    || provider.requestQueue.length !== 1) {
                fail("queued process request was not serialized first");
            }
            provider.completeResponse(JSON.stringify({
                "version": 1,
                "processes": [
                    { "pid": 13, "name": "queued", "cpuPercent": 3,
                      "memoryBytes": 52428800 }
                ]
            }));
            provider.sendNextRequest();
            if (JSON.parse(fakeSocketClient.requests.shift()).command !== "gpu") {
                fail("queued GPU request was not serialized after processes");
            }
            provider.completeResponse(JSON.stringify({
                "status": "ok", "version": 1,
                "gpus": [{ "index": 0, "name": "Queued GPU",
                           "utilizationPercent": 7 }]
            }));
            if (provider.processCount !== 1 || provider.gpuName !== "Queued GPU") {
                fail("sequential response routing changed unrelated state");
            }

            provider.requestGpu();
            fakeSocketClient.requests.shift();
            provider.completeResponse(JSON.stringify({
                "status": "ok", "version": 1, "gpus": []
            }));
            if (provider.gpuState !== "unavailable"
                    || provider.backendState !== "connected") {
                fail("GPU absence was confused with backend absence");
            }

            var gpuRequestCount = fakeSocketClient.requests.length;
            provider.gpuEnabled = false;
            provider.requestGpu();
            if (fakeSocketClient.requests.length !== gpuRequestCount
                    || provider.gpuName !== "") {
                fail("disabled GPU continued requesting or retained values");
            }
            var requestCount = fakeSocketClient.requests.length;
            provider.enabled = false;
            provider.requestProcesses();
            if (fakeSocketClient.requests.length !== requestCount
                    || provider.processCount !== 0) {
                fail("disabled process section continued requesting or retained rows");
            }
            console.log("TTop Desk backend provider probe: PASS");
            Qt.quit();
        }
    }
}

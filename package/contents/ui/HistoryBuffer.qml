/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15

QtObject {
    id: buffer

    property var values: []
    property int maximumSamples: 60

    readonly property int effectiveMaximumSamples:
        [30, 60, 120].indexOf(Number(maximumSamples)) !== -1
        ? Number(maximumSamples) : 60
    readonly property int sampleCount: values.length

    function append(value) {
        if (typeof value !== "number" || !isFinite(value)) return false;
        var nextValues = values.slice(0);
        nextValues.push(value);
        if (nextValues.length > effectiveMaximumSamples) {
            nextValues.splice(0, nextValues.length - effectiveMaximumSamples);
        }
        values = nextValues;
        return true;
    }

    function clear() {
        if (values.length > 0) values = [];
    }

    onEffectiveMaximumSamplesChanged: {
        if (values.length > effectiveMaximumSamples) {
            values = values.slice(values.length - effectiveMaximumSamples);
        }
    }
}

/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: sparkline

    property var values: []
    property var secondaryValues: []
    property bool showPrimary: true
    property bool showSecondary: false
    property bool dynamicScale: false
    property real minimumValue: 0
    property real maximumValue: 100
    property real dynamicMinimumMaximum: 1
    property color lineColor: PlasmaCore.Theme.highlightColor
    property color secondaryLineColor: Qt.rgba(PlasmaCore.Theme.textColor.r,
                                                PlasmaCore.Theme.textColor.g,
                                                PlasmaCore.Theme.textColor.b, 0.68)

    implicitHeight: 24

    function validValues(source) {
        var valid = [];
        if (!Array.isArray(source)) return valid;
        for (var index = 0; index < source.length; ++index) {
            var value = source[index];
            if (typeof value === "number" && isFinite(value) && value >= 0) {
                valid.push(value);
            }
        }
        return valid;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        function drawSeries(context, series, color, lower, upper) {
            if (series.length === 0 || width <= 0 || height <= 0) return;
            var range = Math.max(0.000001, upper - lower);
            var usableHeight = Math.max(1, height - 2);
            context.strokeStyle = color;
            context.fillStyle = color;
            context.lineWidth = 1.5;
            context.lineJoin = "round";
            context.lineCap = "round";
            if (series.length === 1) {
                var singleY = 1 + usableHeight
                              * (1 - Math.max(0, Math.min(1,
                                  (series[0] - lower) / range)));
                context.beginPath();
                context.arc(width - 1.5, singleY, 1.5, 0, Math.PI * 2);
                context.fill();
                return;
            }
            context.beginPath();
            for (var index = 0; index < series.length; ++index) {
                var x = index * (width - 1) / (series.length - 1);
                var normalized = Math.max(0, Math.min(1,
                                      (series[index] - lower) / range));
                var y = 1 + usableHeight * (1 - normalized);
                if (index === 0) context.moveTo(x, y);
                else context.lineTo(x, y);
            }
            context.stroke();
        }

        onPaint: {
            var context = getContext("2d");
            context.reset();
            context.clearRect(0, 0, width, height);
            var primary = sparkline.showPrimary
                          ? sparkline.validValues(sparkline.values) : [];
            var secondary = sparkline.showSecondary
                            ? sparkline.validValues(sparkline.secondaryValues) : [];
            var lower = sparkline.minimumValue;
            var upper = sparkline.maximumValue;
            if (sparkline.dynamicScale) {
                var observedMaximum = sparkline.dynamicMinimumMaximum;
                for (var first = 0; first < primary.length; ++first) {
                    observedMaximum = Math.max(observedMaximum, primary[first]);
                }
                for (var second = 0; second < secondary.length; ++second) {
                    observedMaximum = Math.max(observedMaximum, secondary[second]);
                }
                lower = 0;
                upper = observedMaximum * 1.1;
            }
            if (!isFinite(lower)) lower = 0;
            if (!isFinite(upper) || upper <= lower) upper = lower + 1;
            drawSeries(context, primary, sparkline.lineColor, lower, upper);
            drawSeries(context, secondary, sparkline.secondaryLineColor, lower, upper);
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onValuesChanged: canvas.requestPaint()
    onSecondaryValuesChanged: canvas.requestPaint()
    onShowPrimaryChanged: canvas.requestPaint()
    onShowSecondaryChanged: canvas.requestPaint()
    onDynamicScaleChanged: canvas.requestPaint()
    onMinimumValueChanged: canvas.requestPaint()
    onMaximumValueChanged: canvas.requestPaint()
    onDynamicMinimumMaximumChanged: canvas.requestPaint()
    onLineColorChanged: canvas.requestPaint()
    onSecondaryLineColorChanged: canvas.requestPaint()
}

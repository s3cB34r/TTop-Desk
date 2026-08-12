/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Window 2.15
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
    property bool secondaryDashed: true
    property string accessibleName: qsTr("Metric history graph")
    property string accessibleDescription: ""
    property string tooltipText: ""
    property color backgroundColor: PlasmaCore.Theme.backgroundColor
    property color lineColor: PlasmaCore.Theme.highlightColor
    property color secondaryLineColor: PlasmaCore.Theme.textColor

    readonly property real devicePixelRatio: Math.max(1, Screen.devicePixelRatio || 1)
    readonly property color effectiveLineColor: contrastColor(lineColor, backgroundColor)
    readonly property color effectiveSecondaryLineColor:
        withAlpha(contrastColor(secondaryLineColor, backgroundColor), 0.72)
    readonly property size backingStoreSize: canvas.canvasSize

    implicitHeight: 24
    Accessible.role: Accessible.Graphic
    Accessible.name: accessibleName
    Accessible.description: accessibleDescription

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, Math.max(0, Math.min(1, alpha)));
    }

    function linearChannel(channel) {
        return channel <= 0.03928 ? channel / 12.92
                                 : Math.pow((channel + 0.055) / 1.055, 2.4);
    }

    function luminance(color) {
        return 0.2126 * linearChannel(color.r)
               + 0.7152 * linearChannel(color.g)
               + 0.0722 * linearChannel(color.b);
    }

    function contrastRatio(first, second) {
        var bright = Math.max(luminance(first), luminance(second));
        var dark = Math.min(luminance(first), luminance(second));
        return (bright + 0.05) / (dark + 0.05);
    }

    function contrastColor(preferred, background) {
        var candidates = [preferred, PlasmaCore.Theme.textColor,
                          Qt.rgba(0, 0, 0, 1), Qt.rgba(1, 1, 1, 1)];
        var selected = candidates[0];
        var selectedRatio = contrastRatio(selected, background);
        for (var index = 1; index < candidates.length; ++index) {
            var ratio = contrastRatio(candidates[index], background);
            if (ratio > selectedRatio) {
                selected = candidates[index];
                selectedRatio = ratio;
            }
        }
        return selectedRatio >= 2.5 ? selected : preferred;
    }

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
        objectName: "sparklineCanvas"
        anchors.fill: parent
        renderTarget: Canvas.Image
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * sparkline.devicePixelRatio)),
                            Math.max(1, Math.ceil(height * sparkline.devicePixelRatio)))

        function drawSeries(context, series, color, lower, upper, dashed) {
            if (series.length === 0 || width <= 0 || height <= 0) return;
            var range = Math.max(0.000001, upper - lower);
            var lineWidth = 1.25;
            var inset = Math.max(lineWidth / 2, 1 / sparkline.devicePixelRatio);
            var usableWidth = Math.max(1, width - inset * 2);
            var usableHeight = Math.max(1, height - inset * 2);
            context.strokeStyle = color;
            context.fillStyle = color;
            context.lineWidth = lineWidth;
            context.lineJoin = "round";
            context.lineCap = "round";
            context.setLineDash(dashed ? [3.5, 2.5] : []);
            if (series.length === 1) {
                var singleY = inset + usableHeight
                              * (1 - Math.max(0, Math.min(1,
                                  (series[0] - lower) / range)));
                context.beginPath();
                context.arc(width - inset - lineWidth, singleY, lineWidth, 0, Math.PI * 2);
                context.fill();
                context.setLineDash([]);
                return;
            }
            context.beginPath();
            for (var index = 0; index < series.length; ++index) {
                var x = inset + index * usableWidth / (series.length - 1);
                var normalized = Math.max(0, Math.min(1,
                                      (series[index] - lower) / range));
                var y = inset + usableHeight * (1 - normalized);
                if (index === 0) context.moveTo(x, y);
                else context.lineTo(x, y);
            }
            context.stroke();
            context.setLineDash([]);
        }

        onPaint: {
            var context = getContext("2d");
            context.reset();
            context.clearRect(0, 0, canvasSize.width, canvasSize.height);
            context.scale(sparkline.devicePixelRatio, sparkline.devicePixelRatio);
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
            drawSeries(context, primary, sparkline.effectiveLineColor,
                       lower, upper, false);
            drawSeries(context, secondary, sparkline.effectiveSecondaryLineColor,
                       lower, upper, sparkline.secondaryDashed);
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: sparkline.accessibleName
        subText: sparkline.tooltipText
    }

    onValuesChanged: canvas.requestPaint()
    onSecondaryValuesChanged: canvas.requestPaint()
    onShowPrimaryChanged: canvas.requestPaint()
    onShowSecondaryChanged: canvas.requestPaint()
    onDynamicScaleChanged: canvas.requestPaint()
    onMinimumValueChanged: canvas.requestPaint()
    onMaximumValueChanged: canvas.requestPaint()
    onDynamicMinimumMaximumChanged: canvas.requestPaint()
    onSecondaryDashedChanged: canvas.requestPaint()
    onEffectiveLineColorChanged: canvas.requestPaint()
    onEffectiveSecondaryLineColorChanged: canvas.requestPaint()
    onDevicePixelRatioChanged: canvas.requestPaint()
}

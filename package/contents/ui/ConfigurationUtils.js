.pragma library

var DEFAULT_TITLE = "TTop Desk";
var DEFAULT_BACKGROUND_COLOR = "#20252b";

function languageMode(value) {
    return ["en", "de", "system"].indexOf(value) !== -1 ? value : "en";
}

function title(value) {
    if (value === null || value === undefined) return DEFAULT_TITLE;
    var normalized = String(value).replace(/^\s+|\s+$/g, "");
    if (normalized === "") return DEFAULT_TITLE;
    return normalized.slice(0, 40);
}

function allowedInteger(value, supported, fallback) {
    var number = Number(value);
    return supported.indexOf(number) !== -1 ? number : fallback;
}

function processSort(value) {
    return value === "memory" ? "memory" : "cpu";
}

function compactGraphMetric(value) {
    return ["cpu", "memory", "gpu", "network"].indexOf(value) !== -1
            ? value : "cpu";
}

function opacity(value) {
    var number = Number(value);
    if (!isFinite(number)) return 1.0;
    return Math.max(0.35, Math.min(1.0, number));
}

function color(value, fallback) {
    var normalized = String(value === undefined || value === null ? "" : value)
            .replace(/^\s+|\s+$/g, "");
    if (/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(normalized)) {
        return normalized;
    }
    return fallback || DEFAULT_BACKGROUND_COLOR;
}

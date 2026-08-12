/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import "../package/contents/ui/TTop/Runtime"

Item {
    property bool failed: false

    function expect(actual, expected, label) {
        if (actual !== expected) {
            failed = true;
            console.error("TranslationProbe FAIL " + label + ": "
                          + JSON.stringify(actual) + " != " + JSON.stringify(expected));
        }
    }

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            console.log("TranslationProbe languages: "
                        + JSON.stringify(ttopTranslations.availableLanguages()));
            expect(ttopTranslations.normalizedLanguageMode(""), "en", "missing mode");
            expect(ttopTranslations.normalizedLanguageMode("de"), "de", "German mode");
            expect(ttopTranslations.normalizedLanguageMode("system"), "system", "system mode");
            expect(ttopTranslations.normalizedLanguageMode("invalid"), "en", "invalid mode");
            expect(ttopTranslations.text("en", "TEMPERATURE"), "TEMPERATURE", "English lookup");
            expect(ttopTranslations.text("de", "TEMPERATURE"), "TEMPERATUR", "German lookup");
            expect(ttopTranslations.text("invalid", "Network"), "Network", "invalid fallback");
            expect(ttopTranslations.text("de", "Missing translation key"),
                   "Missing translation key", "missing-key fallback");
            expect(ttopTranslations.text("de", "Approximately %1 seconds", [60]),
                   "Ungefähr 60 Sekunden", "placeholder lookup");
            expect(ttopTranslations.effectiveLanguageMode("system"), "de",
                   "German system-locale lookup");
            console.log(failed ? "TranslationProbe FAILED" : "TranslationProbe PASSED");
            Qt.exit(failed ? 1 : 0);
        }
    }
}

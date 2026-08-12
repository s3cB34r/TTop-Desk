/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import org.kde.plasma.configuration 2.0
import "../ui/TTop/Runtime"

ConfigModel {
    id: configModel

    function ttopTr(source, values) {
        // This page is loaded before ConfigGeneral exposes cfg_languageMode.
        // Missing/invalid configuration deliberately falls back to English.
        var applet = typeof plasmoid !== "undefined" ? plasmoid : null;
        var configuredMode = applet !== null && applet.configuration
                ? applet.configuration.languageMode : "en";
        return ttopTranslations.text(configuredMode, source, values || []);
    }

    ConfigCategory {
        name: configModel.ttopTr("TTop Desk settings")
        icon: "configure"
        source: "ConfigGeneral.qml"
    }
}

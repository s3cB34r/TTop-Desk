/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "localsocketclient.h"
#include "translationhelper.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>

class TTopBackendPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_UNUSED(uri)
    }

    void initializeEngine(QQmlEngine *engine, const char *uri) override
    {
        Q_UNUSED(uri)
        auto *client = new LocalSocketClient(engine);
        engine->rootContext()->setContextProperty(QStringLiteral("ttopBackendSocketBridge"), client);
        auto *translations = new TranslationHelper(engine);
        engine->rootContext()->setContextProperty(QStringLiteral("ttopTranslations"), translations);
    }
};

#include "backendplugin.moc"

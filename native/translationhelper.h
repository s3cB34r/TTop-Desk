/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <QObject>
#include <QHash>
#include <QString>
#include <QStringList>
#include <QVariantList>

class TranslationHelper final : public QObject
{
    Q_OBJECT

public:
    explicit TranslationHelper(QObject *parent = nullptr);

    Q_INVOKABLE QString text(const QString &languageMode,
                             const QString &source,
                             const QVariantList &arguments = {}) const;
    Q_INVOKABLE QString normalizedLanguageMode(const QString &languageMode) const;
    Q_INVOKABLE QString effectiveLanguageMode(const QString &languageMode) const;
    Q_INVOKABLE QStringList availableLanguages() const;

private:
    QHash<QString, QString> m_germanMessages;
};

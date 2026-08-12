/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "translationhelper.h"

#include <KLocalizedString>
#include <QDir>
#include <QFile>
#include <QLocale>
#include <QStandardPaths>

namespace
{
constexpr auto CatalogDomain = "plasma_applet_io.github.s3cb34r.ttopdesk";

quint32 readWord(const QByteArray &data, qsizetype offset, bool bigEndian, bool *ok)
{
    if (offset < 0 || offset + 4 > data.size()) {
        *ok = false;
        return 0;
    }
    const auto *bytes = reinterpret_cast<const uchar *>(data.constData() + offset);
    if (bigEndian) {
        return (quint32(bytes[0]) << 24) | (quint32(bytes[1]) << 16)
            | (quint32(bytes[2]) << 8) | quint32(bytes[3]);
    }
    return quint32(bytes[0]) | (quint32(bytes[1]) << 8)
        | (quint32(bytes[2]) << 16) | (quint32(bytes[3]) << 24);
}

QByteArray readString(const QByteArray &data, quint32 offset, quint32 length, bool *ok)
{
    if (quint64(offset) + quint64(length) > quint64(data.size())) {
        *ok = false;
        return {};
    }
    return QByteArray(data.constData() + offset, qsizetype(length));
}

QHash<QString, QString> loadMoCatalog(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    const QByteArray data = file.readAll();
    bool ok = true;
    const quint32 littleMagic = readWord(data, 0, false, &ok);
    if (!ok || (littleMagic != 0x950412deU && littleMagic != 0xde120495U)) {
        return {};
    }
    const bool bigEndian = littleMagic == 0xde120495U;
    const quint32 count = readWord(data, 8, bigEndian, &ok);
    const quint32 originalsOffset = readWord(data, 12, bigEndian, &ok);
    const quint32 translationsOffset = readWord(data, 16, bigEndian, &ok);
    if (!ok || count > 100000U) {
        return {};
    }

    QHash<QString, QString> messages;
    for (quint32 index = 0; index < count; ++index) {
        const quint32 originalLength =
            readWord(data, originalsOffset + index * 8U, bigEndian, &ok);
        const quint32 originalOffset =
            readWord(data, originalsOffset + index * 8U + 4U, bigEndian, &ok);
        const quint32 translationLength =
            readWord(data, translationsOffset + index * 8U, bigEndian, &ok);
        const quint32 translationOffset =
            readWord(data, translationsOffset + index * 8U + 4U, bigEndian, &ok);
        if (!ok) {
            return {};
        }
        QByteArray original = readString(data, originalOffset, originalLength, &ok);
        QByteArray translation = readString(data, translationOffset, translationLength, &ok);
        if (!ok) {
            return {};
        }
        original.truncate(original.indexOf('\0') >= 0 ? original.indexOf('\0')
                                                       : original.size());
        translation.truncate(translation.indexOf('\0') >= 0
                                 ? translation.indexOf('\0') : translation.size());
        if (!original.isEmpty() && !translation.isEmpty()) {
            messages.insert(QString::fromUtf8(original), QString::fromUtf8(translation));
        }
    }
    return messages;
}

bool isGermanLanguage(const QString &language)
{
    const QString normalized = language.toLower().replace(QLatin1Char('-'), QLatin1Char('_'));
    return normalized == QStringLiteral("de") || normalized.startsWith(QStringLiteral("de_"));
}
}

TranslationHelper::TranslationHelper(QObject *parent)
    : QObject(parent)
{
    const QString relativeCatalog = QStringLiteral("locale/de/LC_MESSAGES/%1.mo")
                                        .arg(QString::fromLatin1(CatalogDomain));
    const QStringList dataLocations =
        QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
    for (const QString &dataLocation : dataLocations) {
        m_germanMessages = loadMoCatalog(QDir(dataLocation).filePath(relativeCatalog));
        if (!m_germanMessages.isEmpty()) {
            break;
        }
    }
}

QString TranslationHelper::normalizedLanguageMode(const QString &languageMode) const
{
    if (languageMode == QStringLiteral("de") || languageMode == QStringLiteral("system")) {
        return languageMode;
    }
    return QStringLiteral("en");
}

QString TranslationHelper::effectiveLanguageMode(const QString &languageMode) const
{
    const QString normalizedMode = normalizedLanguageMode(languageMode);
    if (normalizedMode != QStringLiteral("system")) {
        return normalizedMode;
    }

    QStringList languages = KLocalizedString::languages();
    languages.append(QLocale::system().uiLanguages());
    for (const QString &language : languages) {
        if (isGermanLanguage(language)) {
            return QStringLiteral("de");
        }
    }
    return QStringLiteral("en");
}

QStringList TranslationHelper::availableLanguages() const
{
    return m_germanMessages.isEmpty() ? QStringList{QStringLiteral("en")}
                                      : QStringList{QStringLiteral("en"), QStringLiteral("de")};
}

QString TranslationHelper::text(const QString &languageMode,
                                const QString &source,
                                const QVariantList &arguments) const
{
    QString translated = source;
    if (effectiveLanguageMode(languageMode) == QStringLiteral("de")) {
        translated = m_germanMessages.value(source, source);
    }
    for (qsizetype index = 0; index < arguments.size(); ++index) {
        translated.replace(QStringLiteral("%") + QString::number(index + 1),
                           arguments.at(index).toString());
    }
    return translated;
}

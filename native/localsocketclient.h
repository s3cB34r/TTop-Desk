/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <QLocalSocket>
#include <QObject>
#include <QTimer>

class LocalSocketClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString socketPath READ socketPath WRITE setSocketPath NOTIFY socketPathChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit LocalSocketClient(QObject *parent = nullptr);

    QString socketPath() const;
    void setSocketPath(const QString &path);
    bool busy() const;
    QString errorString() const;

    Q_INVOKABLE bool request(const QString &jsonLine);
    Q_INVOKABLE QString defaultSocketPath() const;

Q_SIGNALS:
    void socketPathChanged();
    void busyChanged();
    void errorStringChanged();
    void responseReceived(const QString &jsonLine);
    void transportError(const QString &errorCode);

private Q_SLOTS:
    void handleConnected();
    void handleReadyRead();
    void handleDisconnected();
    void handleSocketError(QLocalSocket::LocalSocketError socketError);
    void handleTimeout();

private:
    static constexpr qsizetype MaximumResponseBytes = 4 * 1024 * 1024;

    void setBusy(bool value);
    void setErrorString(const QString &value);
    void fail(const QString &errorCode, const QString &detail);
    void resetRequest();

    QLocalSocket m_socket;
    QTimer m_timeout;
    QString m_socketPath;
    QString m_pendingRequest;
    QByteArray m_response;
    QString m_errorString;
    bool m_busy = false;
    bool m_responseDelivered = false;
};

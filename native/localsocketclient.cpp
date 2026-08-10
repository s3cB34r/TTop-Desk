/*
 * SPDX-FileCopyrightText: 2026 Yannic Kauffmann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "localsocketclient.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>

LocalSocketClient::LocalSocketClient(QObject *parent)
    : QObject(parent)
    , m_socketPath(defaultSocketPath())
{
    m_timeout.setInterval(4000);
    m_timeout.setSingleShot(true);

    connect(&m_socket, &QLocalSocket::connected, this, &LocalSocketClient::handleConnected);
    connect(&m_socket, &QLocalSocket::readyRead, this, &LocalSocketClient::handleReadyRead);
    connect(&m_socket, &QLocalSocket::disconnected, this, &LocalSocketClient::handleDisconnected);
    connect(&m_socket, &QLocalSocket::errorOccurred, this, &LocalSocketClient::handleSocketError);
    connect(&m_timeout, &QTimer::timeout, this, &LocalSocketClient::handleTimeout);
}

QString LocalSocketClient::socketPath() const
{
    return m_socketPath;
}

void LocalSocketClient::setSocketPath(const QString &path)
{
    if (m_socketPath == path || path.isEmpty()) {
        return;
    }
    if (m_busy) {
        resetRequest();
        m_socket.abort();
    }
    m_socketPath = path;
    Q_EMIT socketPathChanged();
}

bool LocalSocketClient::busy() const
{
    return m_busy;
}

QString LocalSocketClient::errorString() const
{
    return m_errorString;
}

QString LocalSocketClient::defaultSocketPath() const
{
    const QString runtimeDirectory = qEnvironmentVariable("XDG_RUNTIME_DIR").trimmed();
    if (!runtimeDirectory.isEmpty()) {
        return QDir(runtimeDirectory).filePath(QStringLiteral("ttop-desk.sock"));
    }
    return QDir::home().filePath(QStringLiteral(".cache/ttop-desk/ttop-desk.sock"));
}

bool LocalSocketClient::request(const QString &jsonLine)
{
    if (m_busy || jsonLine.isEmpty() || jsonLine.size() > 4096) {
        return false;
    }
    if (m_socket.state() != QLocalSocket::UnconnectedState) {
        m_socket.abort();
    }

    m_pendingRequest = jsonLine;
    m_response.clear();
    m_responseDelivered = false;
    setErrorString(QString());
    setBusy(true);
    m_timeout.start();
    m_socket.connectToServer(m_socketPath, QIODevice::ReadWrite);
    return true;
}

void LocalSocketClient::handleConnected()
{
    QByteArray requestBytes = m_pendingRequest.toUtf8();
    if (!requestBytes.endsWith('\n')) {
        requestBytes.append('\n');
    }
    m_socket.write(requestBytes);
    m_socket.flush();
}

void LocalSocketClient::handleReadyRead()
{
    m_response.append(m_socket.readAll());
    if (m_response.size() > MaximumResponseBytes) {
        fail(QStringLiteral("response_too_large"), QStringLiteral("Backend response exceeded 4 MiB"));
        return;
    }

    const qsizetype newline = m_response.indexOf('\n');
    if (newline < 0) {
        return;
    }

    const QByteArray responseLine = m_response.left(newline);
    m_responseDelivered = true;
    m_timeout.stop();
    setBusy(false);
    Q_EMIT responseReceived(QString::fromUtf8(responseLine));
    m_socket.disconnectFromServer();
}

void LocalSocketClient::handleDisconnected()
{
    if (m_busy && !m_responseDelivered) {
        fail(QStringLiteral("incomplete_response"), QStringLiteral("Backend closed without a full response"));
    }
}

void LocalSocketClient::handleSocketError(QLocalSocket::LocalSocketError socketError)
{
    Q_UNUSED(socketError)
    if (m_busy) {
        fail(QStringLiteral("backend_unavailable"), m_socket.errorString());
    }
}

void LocalSocketClient::handleTimeout()
{
    if (m_busy) {
        fail(QStringLiteral("timeout"), QStringLiteral("Backend request timed out"));
    }
}

void LocalSocketClient::setBusy(bool value)
{
    if (m_busy == value) {
        return;
    }
    m_busy = value;
    Q_EMIT busyChanged();
}

void LocalSocketClient::setErrorString(const QString &value)
{
    if (m_errorString == value) {
        return;
    }
    m_errorString = value;
    Q_EMIT errorStringChanged();
}

void LocalSocketClient::fail(const QString &errorCode, const QString &detail)
{
    m_timeout.stop();
    setErrorString(detail);
    setBusy(false);
    m_socket.abort();
    Q_EMIT transportError(errorCode);
    resetRequest();
}

void LocalSocketClient::resetRequest()
{
    m_timeout.stop();
    m_pendingRequest.clear();
    m_response.clear();
    m_responseDelivered = false;
    setBusy(false);
}

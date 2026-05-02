// symmetria-fm-cli — minimal IPC sender. Replaces `qs ipc --any-display -c
// symmetria-fm call filemanager <method> <args>` with a tiny Qt6 binary
// that opens a QLocalSocket and writes one JSON line.
//
// Usage:
//   symmetria-fm-cli open <path>
//   symmetria-fm-cli openOverlay <path>
//   symmetria-fm-cli createPicker '<json>'
//
// Exits 0 on success, non-zero on connection / protocol error.

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QStringList>
#include <QTextStream>
#include <iostream>

namespace {

constexpr int kConnectTimeoutMs = 2000;
constexpr int kReadTimeoutMs = 2000;

QString socketPath()
{
    const QByteArray runtime = qgetenv("XDG_RUNTIME_DIR");
    if (!runtime.isEmpty())
        return QString::fromUtf8(runtime) + QStringLiteral("/symmetria-fm.sock");
    return QStringLiteral("/tmp/symmetria-fm.sock");
}

void printUsage()
{
    std::cerr << "usage: symmetria-fm-cli <method> [<arg>]\n"
              << "  methods:\n"
              << "    open <path>\n"
              << "    openOverlay <path>\n"
              << "    createPicker '<json>'\n";
}

} // namespace

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    const QStringList args = QCoreApplication::arguments();

    if (args.size() < 2) {
        printUsage();
        return 2;
    }

    const QString method = args.at(1);

    QJsonObject argsObj;
    if (method == QStringLiteral("open") || method == QStringLiteral("openOverlay")) {
        argsObj.insert(QStringLiteral("initialPath"),
                       args.size() > 2 ? args.at(2) : QString());
    } else if (method == QStringLiteral("createPicker")) {
        if (args.size() < 3) {
            std::cerr << "createPicker requires a JSON argument\n";
            return 2;
        }
        QJsonParseError err{};
        const QJsonDocument doc = QJsonDocument::fromJson(args.at(2).toUtf8(), &err);
        if (err.error != QJsonParseError::NoError) {
            std::cerr << "invalid JSON: " << err.errorString().toStdString() << "\n";
            return 2;
        }
        argsObj = doc.object();
    } else {
        std::cerr << "unknown method: " << method.toStdString() << "\n";
        printUsage();
        return 2;
    }

    QJsonObject envelope;
    envelope.insert(QStringLiteral("method"), method);
    envelope.insert(QStringLiteral("args"), argsObj);
    const QByteArray line = QJsonDocument(envelope).toJson(QJsonDocument::Compact) + '\n';

    QLocalSocket socket;
    socket.connectToServer(socketPath());
    if (!socket.waitForConnected(kConnectTimeoutMs)) {
        std::cerr << "symmetria-fm-cli: cannot connect to symmetria-fm at "
                  << socketPath().toStdString() << ": "
                  << socket.errorString().toStdString() << "\n"
                  << "Is symmetria-fm running?\n";
        return 1;
    }

    socket.write(line);
    socket.flush();

    if (!socket.waitForReadyRead(kReadTimeoutMs)) {
        std::cerr << "symmetria-fm-cli: no response from server\n";
        return 1;
    }
    const QByteArray reply = socket.readAll().trimmed();

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(reply, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        std::cerr << "symmetria-fm-cli: malformed reply: " << reply.toStdString() << "\n";
        return 1;
    }
    const QJsonObject obj = doc.object();
    if (!obj.value(QStringLiteral("ok")).toBool()) {
        std::cerr << "symmetria-fm-cli: server rejected: "
                  << obj.value(QStringLiteral("error")).toString().toStdString() << "\n";
        return 1;
    }

    return 0;
}

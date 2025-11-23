#include <QCoreApplication>
#include <QSettings>
#include <QVariant>
#include <QByteArray>
#include <QString>
#include <QRegularExpression>
#include <QTextStream>
#include <QDebug>

static QByteArray tryDecodePayload(const QString &payload)
{
    QString p = payload.trimmed();
    // strip trailing/leading nulls
    int nul = p.indexOf('\0');
    if (nul >= 0)
        p = p.left(nul);

    // base64 check
    QRegularExpression re_b64("^[A-Za-z0-9+/=]+$");
    if (re_b64.match(p).hasMatch() && (p.size() % 4) == 0) {
        QByteArray b = QByteArray::fromBase64(p.toUtf8());
        if (!b.isEmpty()) return b;
    }
    // hex check
    QRegularExpression re_hex("^[0-9A-Fa-f]+$");
    if (re_hex.match(p).hasMatch() && (p.size() % 2) == 0) {
        QByteArray b = QByteArray::fromHex(p.toUtf8());
        if (!b.isEmpty()) return b;
    }
    // fallback: return raw utf8 bytes
    return p.toUtf8();
}

static QByteArray decodeSettingValue(const QSettings &settings, const QString &key)
{
    QVariant v = settings.value(key);
    QByteArray raw;
    if (v.canConvert(QMetaType::QByteArray))
        raw = v.toByteArray();

    // If QVariant gave a QByteArray of length 16 already, return it
    if (raw.size() == 16)
        return raw;

    // If QVariant can be converted to QString, take that route
    if (v.canConvert(QMetaType::QString)) {
        QString s = v.toString();
        // Typical Qt textual serialization: @ByteArray(<payload>)
        QRegularExpression re("@ByteArray\\((.*)\\)$", QRegularExpression::DotMatchesEverythingOption);
        QRegularExpressionMatch m = re.match(s);
        if (m.hasMatch()) {
            QString payload = m.captured(1);
            QByteArray dec = tryDecodePayload(payload);
            if (!dec.isEmpty()) return dec;
        }
        // maybe it's stored directly as base64/hex string
        QByteArray dec2 = tryDecodePayload(s);
        if (!dec2.isEmpty()) return dec2;
    }

    // Some registry entries may be stored as UTF-16LE bytes for the string "@ByteArray(...)".
    // Try decoding raw as UTF-16LE text and parse it.
    if ((raw.size() % 2) == 0 && raw.size() >= 4) {
        // quick heuristic: many zero bytes in odd positions indicate UTF-16LE
        int zeroCount = 0;
        for (int i = 1; i < raw.size(); i += 2)
            if (raw.at(i) == 0) ++zeroCount;
        if (zeroCount > raw.size() / 4) {
            // interpret as UTF-16LE
            const ushort *u16 = reinterpret_cast<const ushort *>(raw.constData());
            int len = raw.size() / 2;
            QString s = QString::fromUtf16(u16, len);
            QRegularExpression re("@ByteArray\\((.*)\\)$", QRegularExpression::DotMatchesEverythingOption);
            QRegularExpressionMatch m = re.match(s);
            if (m.hasMatch()) {
                QString payload = m.captured(1);
                QByteArray dec = tryDecodePayload(payload);
                if (!dec.isEmpty()) return dec;
            }
            QByteArray dec2 = tryDecodePayload(s);
            if (!dec2.isEmpty()) return dec2;
        }
    }

    // Last resort: return raw as-is
    return raw;
}

int main(int argc, char **argv)
{
    QCoreApplication a(argc, argv);
    QTextStream out(stdout);

    QString profile;
    if (argc >= 2) profile = QString::fromUtf8(argv[1]);

    // application name: "Chiaki" or "Chiaki-<profile>"
    QString appName = profile.isEmpty() ? QStringLiteral("Chiaki") : QStringLiteral("Chiaki-%1").arg(profile);

    QSettings settings(QSettings::NativeFormat, QSettings::UserScope, QStringLiteral("Chiaki"), appName);

    // try to read registered_hosts array
    int count = settings.beginReadArray("registered_hosts");
    if (count == 0) {
        out << "No registered hosts found in QSettings for application '" << appName << "'\n";
    }

    for (int i = 0; i < count; ++i) {
        settings.setArrayIndex(i);
        QString nickname = settings.value("server_nickname").toString();
        QString mac = QString::fromUtf8(settings.value("server_mac").toByteArray().toHex());
        QByteArray rp_regist = decodeSettingValue(settings, QStringLiteral("rp_regist_key"));
        QByteArray rp_key = decodeSettingValue(settings, QStringLiteral("rp_key"));

        out << "Host[" << i << "] nickname='" << nickname << "' mac='" << mac << "'\n";

        if (rp_regist.size() == 16) {
            out << "  rp_regist_key = " << QString::fromUtf8(rp_regist.toHex()) << "\n";
        } else if (!rp_regist.isEmpty()) {
            out << "  rp_regist_key (decoded len=" << rp_regist.size() << ") = " << QString::fromUtf8(rp_regist.toHex()) << "\n";
            out << "  WARNING: rp_regist_key is not 16 bytes; chiaki_session_init expects 16 bytes.\n";
        } else {
            out << "  rp_regist_key = <missing>\n";
        }

        if (rp_key.size() == 16) {
            out << "  rp_key        = " << QString::fromUtf8(rp_key.toHex()) << "\n";
        } else if (!rp_key.isEmpty()) {
            out << "  rp_key (decoded len=" << rp_key.size() << ") = " << QString::fromUtf8(rp_key.toHex()) << "\n";
            out << "  WARNING: rp_key is not 16 bytes; chiaki_session_init expects 16 bytes.\n";
        } else {
            out << "  rp_key = <missing>\n";
        }

        out << Qt::endl;
    }

    settings.endArray();
    return 0;
}


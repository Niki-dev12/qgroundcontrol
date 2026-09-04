/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "GetacJoystickDebugger.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QIODevice>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtSerialPort/QSerialPort>
#include <QtSerialPort/QSerialPortInfo>

namespace {
constexpr int kBaudRate = 115200;
constexpr int kMaxBufferSize = 4096;
constexpr int kWrappedPacketSize = 35;
constexpr int kShortWrappedPacketSize = 31;
constexpr int kSBusFrameSize = 25;
constexpr int kSBusOffsetInSamplePacket = 8;
constexpr int kSBusOffsetWithoutPrefix = 4;
constexpr int kMinChannelValue = 995;
constexpr int kCenterChannelValue = 1500;
constexpr int kMaxChannelValue = 1995;
constexpr int kPlausibleChannelMargin = 80;
constexpr int kSwitchThreshold = 100;

const QByteArray kInitCommand1 = QByteArray::fromHex("EB90020080FF629000003C2A");
const QByteArray kInitCommand2 = QByteArray::fromHex("EB90020080FF621102006D62");
const QByteArray kAck = QByteArray::fromHex("EB9004FFFF80629000000000FC97");
const char *kSettingsGroup = "GetacJoystick";
const char *kSettingsKeyEnabled = "Enabled";
const char *kSettingsKeyForcedPort = "ForcedPort";
}

GetacJoystickDebugger::GetacJoystickDebugger(QObject *parent)
    : QObject(parent)
{
    _resetDecodedState();
    _loadJoystickBackendSettings();
    refreshPorts();
    _setStatus(tr("Disconnected"));
    _setPacketStatus(tr("No packets"));
}

void GetacJoystickDebugger::setJoystickBackendEnabled(bool enabled)
{
    if (_joystickBackendEnabled == enabled) {
        return;
    }

    _joystickBackendEnabled = enabled;
    _saveJoystickBackendSettings();
    emit joystickBackendSettingsChanged();
}

void GetacJoystickDebugger::setForcedJoystickPort(const QString &portName)
{
    const QString cleanPortName = portName.section(QStringLiteral(" - "), 0, 0).trimmed();
    if (_forcedJoystickPort == cleanPortName) {
        return;
    }

    _forcedJoystickPort = cleanPortName;
    _saveJoystickBackendSettings();
    emit joystickBackendSettingsChanged();
}

GetacJoystickDebugger::~GetacJoystickDebugger()
{
    disconnectPort();
}

void GetacJoystickDebugger::setSelectedPort(const QString &selectedPort)
{
    if (_selectedPort == selectedPort) {
        return;
    }

    _selectedPort = selectedPort;
    emit selectedPortChanged();
}

bool GetacJoystickDebugger::connected() const
{
    return _port && _port->isOpen();
}

void GetacJoystickDebugger::refreshPorts()
{
    QStringList ports;
    for (const QSerialPortInfo &portInfo : QSerialPortInfo::availablePorts()) {
        QString label = portInfo.portName();
        const QString description = portInfo.description();
        if (!description.isEmpty()) {
            label += QStringLiteral(" - %1").arg(description);
        }
        ports.append(label);
    }

    if (_availablePorts != ports) {
        _availablePorts = ports;
        emit availablePortsChanged();
    }

    if (_selectedPort.isEmpty() && !_availablePorts.isEmpty()) {
        setSelectedPort(_availablePorts.first().section(QStringLiteral(" - "), 0, 0));
    }
}

bool GetacJoystickDebugger::connectPort()
{
    if (connected()) {
        return true;
    }

    const QString portName = _selectedPort.section(QStringLiteral(" - "), 0, 0).trimmed();
    if (portName.isEmpty()) {
        _setStatus(tr("No COM port selected"));
        return false;
    }

    _port = new QSerialPort(this);
    _port->setPortName(portName);
    _port->setBaudRate(kBaudRate);
    _port->setDataBits(QSerialPort::Data8);
    _port->setParity(QSerialPort::NoParity);
    _port->setStopBits(QSerialPort::OneStop);
    _port->setFlowControl(QSerialPort::NoFlowControl);

    if (!_port->open(QIODevice::ReadWrite)) {
        _setStatus(tr("Open failed: %1").arg(_port->errorString()));
        _port->deleteLater();
        _port = nullptr;
        return false;
    }

    connect(_port, &QSerialPort::readyRead, this, &GetacJoystickDebugger::_readAvailableData);
    _rxBuffer.clear();
    _ackReceived = false;
    emit ackReceivedChanged();
    emit connectedChanged();
    _setStatus(tr("Connected to %1").arg(portName));
    return true;
}

void GetacJoystickDebugger::disconnectPort()
{
    if (!_port) {
        return;
    }

    if (_port->isOpen()) {
        _port->close();
    }
    _port->deleteLater();
    _port = nullptr;
    _ackReceived = false;
    emit ackReceivedChanged();
    emit connectedChanged();
    _setStatus(tr("Disconnected"));
}

bool GetacJoystickDebugger::sendInitialization()
{
    if (!connected() && !connectPort()) {
        return false;
    }

    _port->clear();
    const QList<QByteArray> commands = { kInitCommand1, kInitCommand2 };
    for (const QByteArray &command : commands) {
        if (_port->write(command) != command.size()) {
            _setStatus(tr("Initialization write failed"));
            return false;
        }
        if (!_port->waitForBytesWritten(150)) {
            _setStatus(tr("Initialization write timed out"));
            return false;
        }
    }

    _setStatus(tr("Initialization sent"));
    return true;
}

void GetacJoystickDebugger::clearLog()
{
    _rxBuffer.clear();
    _rawLog.clear();
    _rawBytes.clear();
    _validPackets = 0;
    _crcErrors = 0;
    _ackReceived = false;
    _lastPacketTime.clear();
    _resetDecodedState();
    _setPacketStatus(tr("No packets"));
    emit rawBytesChanged();
    emit countersChanged();
    emit ackReceivedChanged();
    emit lastPacketTimeChanged();
}

bool GetacJoystickDebugger::saveRawLog()
{
    QString directory = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (directory.isEmpty()) {
        directory = QDir::homePath();
    }

    const QString filename = QStringLiteral("%1/getac-joystick-%2.bin")
        .arg(directory, QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-hhmmss")));
    QFile file(filename);
    if (!file.open(QIODevice::WriteOnly)) {
        _setStatus(tr("Log save failed: %1").arg(file.errorString()));
        return false;
    }

    file.write(_rawLog);
    _setStatus(tr("Saved raw log: %1").arg(filename));
    return true;
}

void GetacJoystickDebugger::useSelectedPortForJoystick()
{
    setForcedJoystickPort(_selectedPort);
}

void GetacJoystickDebugger::_readAvailableData()
{
    if (!connected()) {
        return;
    }

    const QByteArray bytes = _port->readAll();
    if (bytes.isEmpty()) {
        return;
    }

    _rxBuffer.append(bytes);
    _rawLog.append(bytes);
    if (_rxBuffer.size() > kMaxBufferSize) {
        _rxBuffer.remove(0, _rxBuffer.size() - kMaxBufferSize);
    }

    _rawBytes = _bytesToHex(_rxBuffer);
    emit rawBytesChanged();

    if (_rxBuffer.contains(kAck)) {
        _ackReceived = true;
        emit ackReceivedChanged();
        const int ackIndex = _rxBuffer.indexOf(kAck);
        _rxBuffer.remove(ackIndex, kAck.size());
    }

    while (true) {
        ParsedPacket packet = _parseNextPacket(_rxBuffer);
        if (packet.packetSize == 0) {
            break;
        }

        if (!packet.crcOk) {
            _crcErrors++;
            emit countersChanged();
            _setPacketStatus(packet.status);
            continue;
        }

        QVariantList channels;
        QVariantList buttons;
        bool frameLost = false;
        bool failsafe = false;
        if (!packet.valid) {
            _setPacketStatus(packet.status);
            continue;
        }

        if (!_decodeSBusFrame(packet.sbusFrame, channels, buttons, frameLost, failsafe)) {
            _setPacketStatus(tr("Wrapper CRC OK, S.BUS decode failed"));
            continue;
        }

        _channelValues = channels;
        _buttonValues = buttons;
        _frameLost = frameLost;
        _failsafe = failsafe;
        _validPackets++;
        _lastPacketTime = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
        emit channelValuesChanged();
        emit buttonValuesChanged();
        emit flagsChanged();
        emit countersChanged();
        emit lastPacketTimeChanged();
        _setPacketStatus(tr("Valid packet, S.BUS offset %1").arg(packet.sbusOffset));
    }
}

QString GetacJoystickDebugger::_bytesToHex(const QByteArray &bytes, int maxBytes)
{
    const QByteArray tail = bytes.right(maxBytes);
    QStringList hex;
    hex.reserve(tail.size());
    for (const char byte : tail) {
        hex.append(QStringLiteral("%1").arg(static_cast<quint8>(byte), 2, 16, QLatin1Char('0')).toUpper());
    }
    return hex.join(QLatin1Char(' '));
}

quint16 GetacJoystickDebugger::_crc16Modbus(const QByteArray &bytes)
{
    quint16 crc = 0xFFFF;
    for (const char byte : bytes) {
        crc ^= static_cast<quint8>(byte);
        for (int bit = 0; bit < 8; bit++) {
            crc = (crc & 0x0001) ? ((crc >> 1) ^ 0xA001) : (crc >> 1);
        }
    }
    return crc;
}

GetacJoystickDebugger::ParsedPacket GetacJoystickDebugger::_parseNextPacket(QByteArray &buffer)
{
    ParsedPacket result;

    while (buffer.size() >= kShortWrappedPacketSize) {
        const int header = buffer.indexOf(QByteArray::fromHex("EB90"));
        if (header < 0) {
            buffer.clear();
            return result;
        }
        if (header > 0) {
            buffer.remove(0, header);
        }

        const QList<int> candidateSizes = { kWrappedPacketSize, kShortWrappedPacketSize };
        for (const int packetSize : candidateSizes) {
            if (buffer.size() < packetSize) {
                continue;
            }

            const QByteArray candidate = buffer.left(packetSize);
            const quint16 expected = static_cast<quint8>(candidate[packetSize - 2]) |
                                     (static_cast<quint8>(candidate[packetSize - 1]) << 8);
            const quint16 actual = _crc16Modbus(candidate.left(packetSize - 2));
            result.packetSize = packetSize;
            if (actual != expected) {
                result.crcOk = false;
                result.status = tr("CRC failed: expected %1, got %2")
                    .arg(expected, 4, 16, QLatin1Char('0'))
                    .arg(actual, 4, 16, QLatin1Char('0'));
                continue;
            }

            const QList<int> sbusOffsets = { kSBusOffsetInSamplePacket, kSBusOffsetWithoutPrefix, 3 };
            for (const int offset : sbusOffsets) {
                if ((offset + kSBusFrameSize) <= packetSize - 2 &&
                    static_cast<quint8>(candidate[offset]) == 0x0F &&
                    static_cast<quint8>(candidate[offset + kSBusFrameSize - 1]) == 0x00) {
                    result.valid = true;
                    result.crcOk = true;
                    result.sbusOffset = offset;
                    result.sbusFrame = candidate.mid(offset, kSBusFrameSize);
                    result.status = tr("CRC OK");
                    buffer.remove(0, packetSize);
                    return result;
                }
            }

            result.crcOk = true;
            result.status = tr("CRC OK, no 25-byte S.BUS frame found");
        }

        buffer.remove(0, 1);
        return result;
    }

    return result;
}

bool GetacJoystickDebugger::_decodeSBusFrame(const QByteArray &frame, QVariantList &channels, QVariantList &buttons, bool &frameLost, bool &failsafe)
{
    if (frame.size() != kSBusFrameSize ||
        static_cast<quint8>(frame[0]) != 0x0F ||
        static_cast<quint8>(frame[24]) != 0x00) {
        return false;
    }

    const quint8 *data = reinterpret_cast<const quint8*>(frame.constData());
    int decoded[16];
    decoded[0] = ((data[1] | data[2] << 8) & 0x07FF);
    decoded[1] = ((data[2] >> 3 | data[3] << 5) & 0x07FF);
    decoded[2] = ((data[3] >> 6 | data[4] << 2 | data[5] << 10) & 0x07FF);
    decoded[3] = ((data[5] >> 1 | data[6] << 7) & 0x07FF);
    decoded[4] = ((data[6] >> 4 | data[7] << 4) & 0x07FF);
    decoded[5] = ((data[7] >> 7 | data[8] << 1 | data[9] << 9) & 0x07FF);
    decoded[6] = ((data[9] >> 2 | data[10] << 6) & 0x07FF);
    decoded[7] = ((data[10] >> 5 | data[11] << 3) & 0x07FF);
    decoded[8] = ((data[12] | data[13] << 8) & 0x07FF);
    decoded[9] = ((data[13] >> 3 | data[14] << 5) & 0x07FF);
    decoded[10] = ((data[14] >> 6 | data[15] << 2 | data[16] << 10) & 0x07FF);
    decoded[11] = ((data[16] >> 1 | data[17] << 7) & 0x07FF);
    decoded[12] = ((data[17] >> 4 | data[18] << 4) & 0x07FF);
    decoded[13] = ((data[18] >> 7 | data[19] << 1 | data[20] << 9) & 0x07FF);
    decoded[14] = ((data[20] >> 2 | data[21] << 6) & 0x07FF);
    decoded[15] = ((data[21] >> 5 | data[22] << 3) & 0x07FF);

    channels.clear();
    for (const int channel : decoded) {
        if ((channel < (kMinChannelValue - kPlausibleChannelMargin)) ||
            (channel > (kMaxChannelValue + kPlausibleChannelMargin))) {
            return false;
        }
        channels.append(channel);
    }

    const quint8 flags = data[23];
    frameLost = (flags & 0x20) != 0;
    failsafe = (flags & 0x10) != 0;

    const bool buttonStates[10] = {
        decoded[10] < (kCenterChannelValue - kSwitchThreshold),
        decoded[10] > (kCenterChannelValue + kSwitchThreshold),
        decoded[11] < (kCenterChannelValue - kSwitchThreshold),
        decoded[11] > (kCenterChannelValue + kSwitchThreshold),
        decoded[12] > kCenterChannelValue,
        decoded[13] > kCenterChannelValue,
        decoded[14] < kCenterChannelValue,
        decoded[15] > kCenterChannelValue,
        (flags & 0x80) != 0,
        (flags & 0x40) != 0,
    };

    buttons.clear();
    for (const bool pressed : buttonStates) {
        buttons.append(pressed);
    }

    return true;
}

void GetacJoystickDebugger::_setStatus(const QString &status)
{
    if (_status == status) {
        return;
    }
    _status = status;
    emit statusChanged();
}

void GetacJoystickDebugger::_setPacketStatus(const QString &packetStatus)
{
    if (_packetStatus == packetStatus) {
        return;
    }
    _packetStatus = packetStatus;
    emit packetStatusChanged();
}

void GetacJoystickDebugger::_resetDecodedState()
{
    _channelValues.clear();
    for (int i = 0; i < 16; i++) {
        _channelValues.append(kCenterChannelValue);
    }

    _buttonValues.clear();
    for (int i = 0; i < 10; i++) {
        _buttonValues.append(false);
    }

    _frameLost = false;
    _failsafe = false;
    emit channelValuesChanged();
    emit buttonValuesChanged();
    emit flagsChanged();
}

void GetacJoystickDebugger::_loadJoystickBackendSettings()
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    _joystickBackendEnabled = settings.value(QLatin1String(kSettingsKeyEnabled), true).toBool();
    _forcedJoystickPort = settings.value(QLatin1String(kSettingsKeyForcedPort)).toString();
    settings.endGroup();
    emit joystickBackendSettingsChanged();
}

void GetacJoystickDebugger::_saveJoystickBackendSettings()
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    settings.setValue(QLatin1String(kSettingsKeyEnabled), _joystickBackendEnabled);
    settings.setValue(QLatin1String(kSettingsKeyForcedPort), _forcedJoystickPort);
    settings.endGroup();
}

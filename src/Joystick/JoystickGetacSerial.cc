/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "JoystickGetacSerial.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QElapsedTimer>
#include <QtCore/QIODevice>
#include <QtCore/QSettings>
#include <QtCore/QThread>
#include <QtSerialPort/QSerialPort>
#include <QtSerialPort/QSerialPortInfo>

QGC_LOGGING_CATEGORY(JoystickGetacSerialLog, "qgc.joystick.getacserial")

namespace {
constexpr int kAxisCount = 16;
constexpr int kButtonCount = 10;
constexpr int kHatCount = 0;
constexpr int kSBusFrameSize = 25;
constexpr int kWrappedPacketSize = 35;
constexpr int kSBusOffsetInWrappedPacket = 8;
constexpr int kMaxBufferedBytes = 512;
constexpr int kReadTimeoutMs = 5;
constexpr int kAckTimeoutMs = 600;
constexpr int kMinChannelValue = 995;
constexpr int kCenterChannelValue = 1500;
constexpr int kMaxChannelValue = 1995;
constexpr int kPlausibleChannelMargin = 80;

const QByteArray kInitCommand1 = QByteArray::fromHex("EB90020080FF629000003C2A");
const QByteArray kInitCommand2 = QByteArray::fromHex("EB90020080FF621102006D62");
const QByteArray kAck = QByteArray::fromHex("EB9004FFFF80629000000000FC97");
const char *kSettingsGroup = "GetacJoystick";
const char *kSettingsKeyEnabled = "Enabled";
const char *kSettingsKeyForcedPort = "ForcedPort";
}

JoystickGetacSerial::JoystickGetacSerial(const QString &portName, QObject *parent)
    : Joystick(QStringLiteral("Getac Serial Controller (%1)").arg(portName), kAxisCount, kButtonCount, kHatCount, parent)
    , _portName(portName)
{
    _channels.fill(kCenterChannelValue);

    for (int axis = 0; axis < kAxisCount; axis++) {
        Calibration_t calibration;
        calibration.min = kMinChannelValue;
        calibration.center = kCenterChannelValue;
        calibration.max = kMaxChannelValue;
        calibration.deadband = deadbandFromPercent(3.0f, calibration.min, calibration.max);
        calibration.reversed = (axis == 1) || (axis == 3);
        setCalibration(axis, calibration);
    }

    setFunctionAxis(rollFunction, 0);
    setFunctionAxis(pitchFunction, 1);
    setFunctionAxis(yawFunction, 2);
    setFunctionAxis(throttleFunction, 3);
    setFunctionAxis(gimbalPitchFunction, -1);
    setFunctionAxis(gimbalYawFunction, -1);

    setCalibration(0, getCalibration(0));
}

JoystickGetacSerial::~JoystickGetacSerial()
{
    _close();
}

QMap<QString, Joystick*> JoystickGetacSerial::discover()
{
    static QMap<QString, Joystick*> ret;
    QMap<QString, Joystick*> newRet;

    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    const bool enabled = settings.value(QLatin1String(kSettingsKeyEnabled), true).toBool();
    QString forcedPort = settings.value(QLatin1String(kSettingsKeyForcedPort)).toString().trimmed();
    settings.endGroup();

    if (!enabled) {
        ret.clear();
        return newRet;
    }

    const QString envForcedPort = qEnvironmentVariable("QGC_GETAC_SERIAL_PORT").trimmed();
    if (!envForcedPort.isEmpty()) {
        forcedPort = envForcedPort;
    }

    if (!forcedPort.isEmpty()) {
        const QString name = QStringLiteral("Getac Serial Controller (%1)").arg(forcedPort);
        newRet[name] = ret.take(name);
        if (!newRet[name]) {
            newRet[name] = new JoystickGetacSerial(forcedPort);
        }
    }

    for (const QSerialPortInfo &portInfo : QSerialPortInfo::availablePorts()) {
        if (!_isGetacPort(portInfo)) {
            continue;
        }

        const QString portName = portInfo.portName();
        const QString name = QStringLiteral("Getac Serial Controller (%1)").arg(portName);
        if (newRet.contains(name)) {
            continue;
        }

        newRet[name] = ret.take(name);
        if (!newRet[name]) {
            newRet[name] = new JoystickGetacSerial(portName);
        }
    }

    ret = newRet;
    return ret;
}

bool JoystickGetacSerial::_open()
{
    if (_port) {
        return _port->isOpen();
    }

    _rxBuffer.clear();
    _port = new QSerialPort();
    _port->setPortName(_portName);
    _port->setBaudRate(115200);
    _port->setDataBits(QSerialPort::Data8);
    _port->setParity(QSerialPort::NoParity);
    _port->setStopBits(QSerialPort::OneStop);
    _port->setFlowControl(QSerialPort::NoFlowControl);

    if (!_port->open(QIODevice::ReadWrite)) {
        qCWarning(JoystickGetacSerialLog) << "Failed to open Getac serial controller" << _portName << _port->errorString();
        delete _port;
        _port = nullptr;
        return false;
    }

    if (!_sendInitialization()) {
        qCWarning(JoystickGetacSerialLog) << "Getac serial controller did not acknowledge initialization" << _portName;
        _close();
        return false;
    }

    qCInfo(JoystickGetacSerialLog) << "Opened Getac serial controller" << _portName;
    return true;
}

void JoystickGetacSerial::_close()
{
    if (!_port) {
        return;
    }

    if (_port->isOpen()) {
        _port->close();
    }

    delete _port;
    _port = nullptr;
    _rxBuffer.clear();
}

bool JoystickGetacSerial::_update()
{
    if (!_port || !_port->isOpen()) {
        return false;
    }

    if (_port->bytesAvailable() == 0) {
        _port->waitForReadyRead(kReadTimeoutMs);
    }

    const QByteArray bytes = _port->readAll();
    if (!bytes.isEmpty()) {
        _rxBuffer.append(bytes);
        if (_rxBuffer.size() > kMaxBufferedBytes) {
            _rxBuffer.remove(0, _rxBuffer.size() - kMaxBufferedBytes);
        }
    }

    QByteArray frame;
    bool updated = false;
    while (_extractNextSBusFrame(frame)) {
        _applySBusFrame(frame);
        updated = true;
    }

    return updated;
}

bool JoystickGetacSerial::_getButton(int i) const
{
    if ((i < 0) || (i >= kButtonCount)) {
        return false;
    }

    return (_buttons & (1u << i)) != 0;
}

int JoystickGetacSerial::_getAxis(int i) const
{
    if ((i < 0) || (i >= kAxisCount)) {
        return kCenterChannelValue;
    }

    return _channels[static_cast<size_t>(i)];
}

bool JoystickGetacSerial::_getHat(int hat, int i) const
{
    Q_UNUSED(hat)
    Q_UNUSED(i)
    return false;
}

bool JoystickGetacSerial::_isGetacPort(const QSerialPortInfo &portInfo)
{
    const QString haystack = QStringLiteral("%1 %2 %3")
        .arg(portInfo.description(), portInfo.manufacturer(), portInfo.serialNumber());
    return haystack.contains(QStringLiteral("Getac"), Qt::CaseInsensitive);
}

quint16 JoystickGetacSerial::_crc16Modbus(const QByteArray &bytes)
{
    quint16 crc = 0xFFFF;
    for (const char byte : bytes) {
        crc ^= static_cast<quint8>(byte);
        for (int bit = 0; bit < 8; bit++) {
            if ((crc & 0x0001) != 0) {
                crc = (crc >> 1) ^ 0xA001;
            } else {
                crc >>= 1;
            }
        }
    }
    return crc;
}

bool JoystickGetacSerial::_decodeSBusFrame(const QByteArray &frame, std::array<int, 16> &channels, quint16 &buttons)
{
    if ((frame.size() != kSBusFrameSize) ||
        (static_cast<quint8>(frame[0]) != 0x0F) ||
        (static_cast<quint8>(frame[24]) != 0x00)) {
        return false;
    }

    const quint8 *data = reinterpret_cast<const quint8*>(frame.constData());
    channels[0] = ((data[1] | data[2] << 8) & 0x07FF);
    channels[1] = ((data[2] >> 3 | data[3] << 5) & 0x07FF);
    channels[2] = ((data[3] >> 6 | data[4] << 2 | data[5] << 10) & 0x07FF);
    channels[3] = ((data[5] >> 1 | data[6] << 7) & 0x07FF);
    channels[4] = ((data[6] >> 4 | data[7] << 4) & 0x07FF);
    channels[5] = ((data[7] >> 7 | data[8] << 1 | data[9] << 9) & 0x07FF);
    channels[6] = ((data[9] >> 2 | data[10] << 6) & 0x07FF);
    channels[7] = ((data[10] >> 5 | data[11] << 3) & 0x07FF);
    channels[8] = ((data[12] | data[13] << 8) & 0x07FF);
    channels[9] = ((data[13] >> 3 | data[14] << 5) & 0x07FF);
    channels[10] = ((data[14] >> 6 | data[15] << 2 | data[16] << 10) & 0x07FF);
    channels[11] = ((data[16] >> 1 | data[17] << 7) & 0x07FF);
    channels[12] = ((data[17] >> 4 | data[18] << 4) & 0x07FF);
    channels[13] = ((data[18] >> 7 | data[19] << 1 | data[20] << 9) & 0x07FF);
    channels[14] = ((data[20] >> 2 | data[21] << 6) & 0x07FF);
    channels[15] = ((data[21] >> 5 | data[22] << 3) & 0x07FF);

    if (!_channelsPlausible(channels)) {
        return false;
    }

    const quint8 flags = data[23];
    if ((flags & 0x30) != 0) {
        return false;
    }

    static constexpr int switchThreshold = 100;

    buttons = 0;
    if (channels[10] < (kCenterChannelValue - switchThreshold)) { buttons |= 1u << 0; } // CH11 low
    if (channels[10] > (kCenterChannelValue + switchThreshold)) { buttons |= 1u << 1; } // CH11 high
    if (channels[11] < (kCenterChannelValue - switchThreshold)) { buttons |= 1u << 2; } // CH12 low
    if (channels[11] > (kCenterChannelValue + switchThreshold)) { buttons |= 1u << 3; } // CH12 high
    if (channels[12] > kCenterChannelValue) { buttons |= 1u << 4; } // CH13
    if (channels[13] > kCenterChannelValue) { buttons |= 1u << 5; } // CH14
    if (channels[14] < kCenterChannelValue) { buttons |= 1u << 6; } // CH15 center-off active
    if (channels[15] > kCenterChannelValue) { buttons |= 1u << 7; } // CH16
    if ((flags & 0x80) != 0) {
        buttons |= 1u << 8;
    }
    if ((flags & 0x40) != 0) {
        buttons |= 1u << 9;
    }

    return true;
}

bool JoystickGetacSerial::_channelsPlausible(const std::array<int, 16> &channels)
{
    for (const int channel : channels) {
        if ((channel < (kMinChannelValue - kPlausibleChannelMargin)) ||
            (channel > (kMaxChannelValue + kPlausibleChannelMargin))) {
            return false;
        }
    }
    return true;
}

bool JoystickGetacSerial::_sendInitialization()
{
    _port->clear();

    for (const QByteArray &command : { kInitCommand1, kInitCommand2 }) {
        if (_port->write(command) != command.size()) {
            return false;
        }
        if (!_port->waitForBytesWritten(100)) {
            return false;
        }
    }

    QByteArray ackBuffer;
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < kAckTimeoutMs) {
        if (_port->waitForReadyRead(50)) {
            ackBuffer.append(_port->readAll());
            if (ackBuffer.contains(kAck)) {
                _rxBuffer.append(ackBuffer);
                return true;
            }
        }
    }

    _rxBuffer.append(ackBuffer);
    return false;
}

bool JoystickGetacSerial::_extractNextSBusFrame(QByteArray &frame)
{
    while (_rxBuffer.size() >= kSBusFrameSize) {
        const int wrappedHeader = _rxBuffer.indexOf(QByteArray::fromHex("EB90"));
        if (wrappedHeader > 0) {
            const int rawSBusStart = _rxBuffer.indexOf('\x0F');
            if ((rawSBusStart < 0) || (wrappedHeader < rawSBusStart)) {
                _rxBuffer.remove(0, wrappedHeader);
            }
        }

        if (_rxBuffer.startsWith(QByteArray::fromHex("EB90"))) {
            if (_rxBuffer.size() < kWrappedPacketSize) {
                return false;
            }

            const QByteArray candidate = _rxBuffer.left(kWrappedPacketSize);
            const quint16 expectedCrc = static_cast<quint8>(candidate[kWrappedPacketSize - 2]) |
                                        (static_cast<quint8>(candidate[kWrappedPacketSize - 1]) << 8);
            const quint16 actualCrc = _crc16Modbus(candidate.left(kWrappedPacketSize - 2));
            if (actualCrc == expectedCrc) {
                const QByteArray candidateFrame = candidate.mid(kSBusOffsetInWrappedPacket, kSBusFrameSize);
                std::array<int, 16> channels;
                quint16 buttons = 0;
                if (_decodeSBusFrame(candidateFrame, channels, buttons)) {
                    frame = candidateFrame;
                    _rxBuffer.remove(0, kWrappedPacketSize);
                    return true;
                }
            }

            _rxBuffer.remove(0, 1);
            continue;
        }

        const int start = _rxBuffer.indexOf('\x0F');
        if (start < 0) {
            _rxBuffer.clear();
            return false;
        }
        if (start > 0) {
            _rxBuffer.remove(0, start);
        }
        if (_rxBuffer.size() < kSBusFrameSize) {
            return false;
        }

        const QByteArray candidate = _rxBuffer.left(kSBusFrameSize);
        std::array<int, 16> channels;
        quint16 buttons = 0;
        if (_decodeSBusFrame(candidate, channels, buttons)) {
            frame = candidate;
            _rxBuffer.remove(0, kSBusFrameSize);
            return true;
        }

        _rxBuffer.remove(0, 1);
    }

    return false;
}

void JoystickGetacSerial::_applySBusFrame(const QByteArray &frame)
{
    std::array<int, 16> channels;
    quint16 buttons = 0;
    if (!_decodeSBusFrame(frame, channels, buttons)) {
        return;
    }

    _channels = channels;
    _buttons = buttons;
}

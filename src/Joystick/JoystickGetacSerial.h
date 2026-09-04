/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "Joystick.h"

#include <QtCore/QByteArray>
#include <QtCore/QLoggingCategory>

#include <array>

class QSerialPort;
class QSerialPortInfo;

Q_DECLARE_LOGGING_CATEGORY(JoystickGetacSerialLog)

class JoystickGetacSerial : public Joystick
{
public:
    explicit JoystickGetacSerial(const QString &portName, QObject *parent = nullptr);
    ~JoystickGetacSerial();

    bool requiresCalibration() const final { return false; }

    static QMap<QString, Joystick*> discover();

private:
    bool _open() final;
    void _close() final;
    bool _update() final;

    bool _getButton(int i) const final;
    int _getAxis(int i) const final;
    bool _getHat(int hat, int i) const final;

    static bool _isGetacPort(const QSerialPortInfo &portInfo);
    static quint16 _crc16Modbus(const QByteArray &bytes);
    static bool _decodeSBusFrame(const QByteArray &frame, std::array<int, 16> &channels, quint16 &buttons);
    static bool _channelsPlausible(const std::array<int, 16> &channels);

    bool _sendInitialization();
    bool _extractNextSBusFrame(QByteArray &frame);
    void _applySBusFrame(const QByteArray &frame);

    QString _portName;
    QSerialPort *_port = nullptr;
    QByteArray _rxBuffer;
    std::array<int, 16> _channels{};
    quint16 _buttons = 0;
};

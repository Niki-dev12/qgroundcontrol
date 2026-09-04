/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariantList>

class QSerialPort;

class GetacJoystickDebugger : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)
    Q_PROPERTY(QString selectedPort READ selectedPort WRITE setSelectedPort NOTIFY selectedPortChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool ackReceived READ ackReceived NOTIFY ackReceivedChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString packetStatus READ packetStatus NOTIFY packetStatusChanged)
    Q_PROPERTY(QString lastPacketTime READ lastPacketTime NOTIFY lastPacketTimeChanged)
    Q_PROPERTY(QString rawBytes READ rawBytes NOTIFY rawBytesChanged)
    Q_PROPERTY(QVariantList channelValues READ channelValues NOTIFY channelValuesChanged)
    Q_PROPERTY(QVariantList buttonValues READ buttonValues NOTIFY buttonValuesChanged)
    Q_PROPERTY(bool frameLost READ frameLost NOTIFY flagsChanged)
    Q_PROPERTY(bool failsafe READ failsafe NOTIFY flagsChanged)
    Q_PROPERTY(int validPackets READ validPackets NOTIFY countersChanged)
    Q_PROPERTY(int crcErrors READ crcErrors NOTIFY countersChanged)
    Q_PROPERTY(bool joystickBackendEnabled READ joystickBackendEnabled WRITE setJoystickBackendEnabled NOTIFY joystickBackendSettingsChanged)
    Q_PROPERTY(QString forcedJoystickPort READ forcedJoystickPort WRITE setForcedJoystickPort NOTIFY joystickBackendSettingsChanged)

public:
    explicit GetacJoystickDebugger(QObject *parent = nullptr);
    ~GetacJoystickDebugger();

    QStringList availablePorts() const { return _availablePorts; }
    QString selectedPort() const { return _selectedPort; }
    void setSelectedPort(const QString &selectedPort);
    bool connected() const;
    bool ackReceived() const { return _ackReceived; }
    QString status() const { return _status; }
    QString packetStatus() const { return _packetStatus; }
    QString lastPacketTime() const { return _lastPacketTime; }
    QString rawBytes() const { return _rawBytes; }
    QVariantList channelValues() const { return _channelValues; }
    QVariantList buttonValues() const { return _buttonValues; }
    bool frameLost() const { return _frameLost; }
    bool failsafe() const { return _failsafe; }
    int validPackets() const { return _validPackets; }
    int crcErrors() const { return _crcErrors; }
    bool joystickBackendEnabled() const { return _joystickBackendEnabled; }
    void setJoystickBackendEnabled(bool enabled);
    QString forcedJoystickPort() const { return _forcedJoystickPort; }
    void setForcedJoystickPort(const QString &portName);

    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE bool connectPort();
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE bool sendInitialization();
    Q_INVOKABLE void clearLog();
    Q_INVOKABLE bool saveRawLog();
    Q_INVOKABLE void useSelectedPortForJoystick();

signals:
    void availablePortsChanged();
    void selectedPortChanged();
    void connectedChanged();
    void ackReceivedChanged();
    void statusChanged();
    void packetStatusChanged();
    void lastPacketTimeChanged();
    void rawBytesChanged();
    void channelValuesChanged();
    void buttonValuesChanged();
    void flagsChanged();
    void countersChanged();
    void joystickBackendSettingsChanged();

private slots:
    void _readAvailableData();

private:
    struct ParsedPacket {
        bool valid = false;
        bool crcOk = false;
        int packetSize = 0;
        int sbusOffset = -1;
        QByteArray sbusFrame;
        QString status;
    };

    static QString _bytesToHex(const QByteArray &bytes, int maxBytes = 512);
    static quint16 _crc16Modbus(const QByteArray &bytes);
    static ParsedPacket _parseNextPacket(QByteArray &buffer);
    static bool _decodeSBusFrame(const QByteArray &frame, QVariantList &channels, QVariantList &buttons, bool &frameLost, bool &failsafe);
    void _setStatus(const QString &status);
    void _setPacketStatus(const QString &packetStatus);
    void _resetDecodedState();
    void _loadJoystickBackendSettings();
    void _saveJoystickBackendSettings();

    QStringList _availablePorts;
    QString _selectedPort;
    QSerialPort *_port = nullptr;
    QByteArray _rxBuffer;
    QByteArray _rawLog;
    QString _status;
    QString _packetStatus;
    QString _lastPacketTime;
    QString _rawBytes;
    QVariantList _channelValues;
    QVariantList _buttonValues;
    bool _ackReceived = false;
    bool _frameLost = false;
    bool _failsafe = false;
    int _validPackets = 0;
    int _crcErrors = 0;
    bool _joystickBackendEnabled = true;
    QString _forcedJoystickPort;
};

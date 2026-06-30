// GeopixelDetection.h
#pragma once

#include <QObject>
#include <QGeoCoordinate>

class GeopixelDetection : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QGeoCoordinate coordinate READ coordinate NOTIFY coordinateChanged)
    Q_PROPERTY(int            objectId   READ objectId   NOTIFY changed)
    Q_PROPERTY(int            classId    READ classId    NOTIFY changed)
    Q_PROPERTY(double         altitude   READ altitude   NOTIFY changed)
    Q_PROPERTY(quint64        timestamp  READ timestamp  NOTIFY changed)

public:
    explicit GeopixelDetection(QObject* parent = nullptr)
        : QObject(parent)
    {}

    QGeoCoordinate coordinate() const { return _coordinate; }
    int            objectId()   const { return _objectId; }
    int            classId()    const { return _classId; }
    double         altitude()   const { return _altitude; }
    quint64        timestamp()  const { return _timestamp; }

    void setCoordinate(const QGeoCoordinate& c) {
        if (_coordinate != c) {
            _coordinate = c;
            emit coordinateChanged();
            emit changed();
        }
    }

    void setObjectId(int id) {
        if (_objectId != id) {
            _objectId = id;
            emit changed();
        }
    }

    void setClassId(int id) {
        if (_classId != id) {
            _classId = id;
            emit changed();
        }
    }

    void setAltitude(double alt) {
        if (!qFuzzyCompare(_altitude, alt)) {
            _altitude = alt;
            emit changed();
        }
    }

    void setTimestamp(quint64 ts) {
        if (_timestamp != ts) {
            _timestamp = ts;
            emit changed();
        }
    }

signals:
    void coordinateChanged();
    void changed();

private:
    QGeoCoordinate _coordinate;
    int            _objectId  = -1;
    int            _classId   = -1;
    double         _altitude  = qQNaN();
    quint64        _timestamp = 0;
};

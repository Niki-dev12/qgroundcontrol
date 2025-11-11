#pragma once
#include <QObject>
#include <QVariant>
#include <QtPositioning/QGeoCoordinate>

#include "TerrainQuery.h"

class TerrainAheadSampler : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject*     vehicle            READ vehicle            WRITE setVehicle            NOTIFY vehicleChanged)
    Q_PROPERTY(double       aheadDistanceMeters READ aheadDistanceMeters WRITE setAheadDistanceMeters NOTIFY aheadDistanceMetersChanged)
    Q_PROPERTY(double       stepMeters         READ stepMeters         WRITE setStepMeters         NOTIFY stepMetersChanged)
    Q_PROPERTY(int          hz                 READ hz                 WRITE setHz                 NOTIFY hzChanged)
    Q_PROPERTY(QVariantList points             READ points             NOTIFY pointsChanged)
    Q_PROPERTY(double       terrainNowAMSL     READ terrainNowAMSL     NOTIFY terrainNowAMSLChanged)

public:
    explicit TerrainAheadSampler(QObject* parent=nullptr);

    // Properties
    QObject* vehicle() const { return _vehicle; }
    void setVehicle(QObject* v);

    double aheadDistanceMeters() const { return _aheadM; }
    void setAheadDistanceMeters(double v);

    double stepMeters() const { return _stepM; }
    void setStepMeters(double v);

    int hz() const { return _hz; }
    void setHz(int v);

    QVariantList points() const { return _points; }
    double terrainNowAMSL() const;

    Q_INVOKABLE void resample();
    Q_INVOKABLE void sample(const QGeoCoordinate& from, double headingDeg);

signals:
    void vehicleChanged();
    void aheadDistanceMetersChanged();
    void stepMetersChanged();
    void hzChanged();
    void pointsChanged();
    void terrainNowAMSLChanged();

private slots:
    void _onPath(bool ok, const TerrainPathQuery::PathHeightInfo_t& info);

private:
    static QGeoCoordinate _forward(const QGeoCoordinate& c, double distM, double azDeg);
    static bool _readNumber(QObject* root, const char* name, double& out);
    bool _extractPose(QGeoCoordinate& from, double& headingDeg, double& altAmsl) const;

private:
    QObject*          _vehicle{nullptr};
    double            _aheadM{500.0};
    double            _stepM{25.0};
    int               _hz{4};

    TerrainPathQuery* _path{nullptr};

    QVariantList      _points;
    double            _terrainNowAMSL{qQNaN()};
    double            _altAMSLNow{qQNaN()};
};

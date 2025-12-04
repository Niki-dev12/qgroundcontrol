#include "TerrainAheadSampler.h"
#include <QtMath>
#include <QVariant>
#include <QMetaProperty>
#include <QDebug>

TerrainAheadSampler::TerrainAheadSampler(QObject* p)
    : QObject(p)
    , _path(new TerrainPathQuery(false, this))
{
    connect(_path, &TerrainPathQuery::terrainDataReceived,
            this,  &TerrainAheadSampler::_onPath);
}

void TerrainAheadSampler::setVehicle(QObject* v) {
    if (_vehicle == v) return;
    _vehicle = v;
    emit vehicleChanged();
}

void TerrainAheadSampler::setAheadDistanceMeters(double v) {
    if (!qIsFinite(v)) return;
    if (_aheadM == v) return;
    _aheadM = v;
    emit aheadDistanceMetersChanged();
}

void TerrainAheadSampler::setStepMeters(double v) {
    if (!qIsFinite(v)) return;
    if (_stepM == v) return;
    _stepM = v;
    emit stepMetersChanged();
}

void TerrainAheadSampler::setHz(int v) {
    if (_hz == v) return;
    _hz = v;
    emit hzChanged();
}

double TerrainAheadSampler::terrainNowAMSL() const { return _terrainNowAMSL; }

void TerrainAheadSampler::resample() {
    QGeoCoordinate from;
    double hdgDeg = qQNaN();
    double altAmsl = qQNaN();
    if (!_extractPose(from, hdgDeg, altAmsl)) {
        _points.clear();
        if (!qIsNaN(_terrainNowAMSL)) {
            _terrainNowAMSL = qQNaN();
            emit terrainNowAMSLChanged();
        }
        emit pointsChanged();
        return;
    }
    _altAMSLNow = altAmsl;
    sample(from, hdgDeg);
}

void TerrainAheadSampler::sample(const QGeoCoordinate& from, double headingDeg) {
    if (!from.isValid() || !qIsFinite(headingDeg)) return;
    const auto to = _forward(from, _aheadM, headingDeg);
    _path->requestData(from, to);
}

void TerrainAheadSampler::_onPath(bool ok, const TerrainPathQuery::PathHeightInfo_t& info) {
    _points.clear();
    if (!ok || info.heights.isEmpty()) {
        emit pointsChanged();
        return;
    }

    // Height under the drone
    const double nowElev = info.heights.first();
    if (!qFuzzyCompare(nowElev, _terrainNowAMSL)) {
        _terrainNowAMSL = nowElev;
        emit terrainNowAMSLChanged();
    }

    // Build cumulative distances using distanceBetween
    const int n = info.heights.count();
    double d = 0.0;
    for (int i = 0; i < n; ++i) {
        QVariantMap m;
        m.insert(QStringLiteral("d"), d);
        m.insert(QStringLiteral("elevAMSL"), info.heights[i]);
        _points.push_back(m);

        if (i < n - 2) {
            d += info.distanceBetween;
        } else if (i == n - 2) {
            d += info.finalDistanceBetween;
        }
    }

    emit pointsChanged();
}

QGeoCoordinate TerrainAheadSampler::_forward(const QGeoCoordinate& c, double d, double az) {
    constexpr double R = 6371000.0;
    const double br = qDegreesToRadians(c.latitude());
    const double lr = qDegreesToRadians(c.longitude());
    const double ar = qDegreesToRadians(az);
    const double dr = d / R;

    const double br2 = asin(sin(br) * cos(dr) + cos(br) * sin(dr) * cos(ar));
    const double lr2 = lr + atan2(sin(ar) * sin(dr) * cos(br), cos(dr) - sin(br) * sin(br2));

    return { qRadiansToDegrees(br2), qRadiansToDegrees(lr2), c.altitude() };
}

static bool readFromFact(QObject* fact, double& out) {
    if (!fact) return false;
    QVariant v = fact->property("rawValue");
    if (!v.isValid()) v = fact->property("value");
    if (!v.isValid()) return false;
    bool ok=false;
    const double d = v.toDouble(&ok);
    if (ok) { out = d; return true; }
    return false;
}

bool TerrainAheadSampler::_readNumber(QObject* root, const char* name, double& out) {
    if (!root) return false;
    QVariant v = root->property(name);
    if (!v.isValid())
        return false;

    if (v.canConvert<QObject*>()) {
        return readFromFact(v.value<QObject*>(), out);
    } else {
        bool ok=false;
        const double d = v.toDouble(&ok);
        if (ok) { out = d; return true; }
    }
    return false;
}

bool TerrainAheadSampler::_extractPose(QGeoCoordinate& from, double& headingDeg, double& altAmsl) const {
    if (!_vehicle) return false;

    double lat= qQNaN(), lon= qQNaN(), amsl= qQNaN(), hdg= qQNaN();
    const bool okLat = _readNumber(_vehicle, "latitude",       lat);
    const bool okLon = _readNumber(_vehicle, "longitude",      lon);
    const bool okAlt = _readNumber(_vehicle, "altitudeAMSL",   amsl);
    const bool okHdg = _readNumber(_vehicle, "heading",        hdg);

    if (!okLat || !okLon || !okHdg)
        return false;

    from = QGeoCoordinate(lat, lon, amsl);
    headingDeg = hdg;
    altAmsl = amsl;
    return true;
}

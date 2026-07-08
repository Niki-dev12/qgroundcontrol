/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "QGCCameraManager.h"
#include "JoystickManager.h"
#include "SimulatedCameraControl.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "FirmwarePlugin.h"
#include "QGCLoggingCategory.h"
#include "Joystick.h"
#include "CameraMetaData.h"
#include "JsonHelper.h"
#include "QGCVideoStreamInfo.h"

#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtQml/QQmlEngine>


#include <cmath>
#include <cstdint>
#include "GimbalControllerSettings.h"
#include "SettingsManager.h"

static constexpr double kPi = M_PI;
static constexpr double kDefaultCameraAspect = 9.0 / 16.0;
static constexpr double kMinUsableCameraAspect = 0.1;
static constexpr double kMaxUsableCameraAspect = 10.0;
static constexpr double kMinUsableFovDeg = 1.0;
static constexpr double kMaxUsableFovDeg = 179.0;
static constexpr double kDefaultCameraHFovDeg = 70.0;
static constexpr double kDefaultCameraVFovDeg = 70.0;

static bool _isUsableFovDeg(double fovDeg)
{
    return std::isfinite(fovDeg) && fovDeg > kMinUsableFovDeg && fovDeg < kMaxUsableFovDeg;
}

static int _fovSourceKey(int compId, uint8_t cameraDeviceId)
{
    return ((compId & 0xFF) << 8) | cameraDeviceId;
}

static double _usableCameraAspect(double aspect)
{
    return (std::isfinite(aspect) && aspect >= kMinUsableCameraAspect && aspect <= kMaxUsableCameraAspect)
               ? aspect
               : kDefaultCameraAspect;
}

static double _calculatedVfovDeg(double hfovDeg, double aspect)
{
    const double hfovRad = hfovDeg * kPi / 180.0;
    const double vfovRad = 2.0 * std::atan(std::tan(hfovRad * 0.5) * aspect);
    return vfovRad * 180.0 / kPi;
}

static double _usableOrDefaultFovDeg(double fovDeg, double defaultFovDeg)
{
    return _isUsableFovDeg(fovDeg) ? fovDeg : defaultFovDeg;
}

static double _settingsCameraHFovDeg()
{
    return _usableOrDefaultFovDeg(
        SettingsManager::instance()->gimbalControllerSettings()->CameraHFov()->rawValue().toDouble(),
        kDefaultCameraHFovDeg);
}

static double _settingsCameraVFovDeg()
{
    return _usableOrDefaultFovDeg(
        SettingsManager::instance()->gimbalControllerSettings()->CameraVFov()->rawValue().toDouble(),
        kDefaultCameraVFovDeg);
}

static void _cameraFovStatusRequestHandler(
    void* resultHandlerData,
    MAV_RESULT result,
    Vehicle::RequestMessageResultHandlerFailureCode_t failureCode,
    const mavlink_message_t& message)
{
    std::unique_ptr<QPointer<QGCCameraManager>> cameraManagerGuard(
        static_cast<QPointer<QGCCameraManager>*>(resultHandlerData));

    if (!cameraManagerGuard || cameraManagerGuard->isNull()) {
        return;
    }

    QGCCameraManager* const cameraManager = cameraManagerGuard->data();

    if (result != MAV_RESULT_ACCEPTED) {
        qCDebug(CameraManagerLog)
            << "CAMERA_FOV_STATUS request failed. result:" << result
            << "failureCode:" << failureCode;
        return;
    }

    if (message.msgid != MAVLINK_MSG_ID_CAMERA_FOV_STATUS) {
        qCDebug(CameraManagerLog) << "Unexpected message id:" << message.msgid;
        return;
    }

    cameraManager->handleCameraFovStatusFromRequest(message);
}

QGC_LOGGING_CATEGORY(CameraManagerLog, "qgc.camera.qgccameramanager")

QVariantList QGCCameraManager::_cameraList;
//-----------------------------------------------------------------------------
QGCCameraManager::CameraStruct::CameraStruct(QObject* parent, uint8_t compID_, Vehicle* vehicle_)
    : QObject   (parent)
    , compID    (compID_)
    , vehicle   (vehicle_)
{
    backoffTimer = new QTimer(this);
    backoffTimer->setSingleShot(true);
}

//-----------------------------------------------------------------------------
QGCCameraManager::QGCCameraManager(Vehicle *vehicle)
    : _vehicle                  (vehicle)
    , _simulatedCameraControl   (new SimulatedCameraControl(vehicle, this))
{
    qCDebug(CameraManagerLog) << "QGCCameraManager Created";

    (void) qRegisterMetaType<CameraMetaData>("CameraMetaData");

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);

    _addCameraControlToLists(_simulatedCameraControl);

    connect(MultiVehicleManager::instance(), &MultiVehicleManager::parameterReadyVehicleAvailableChanged, this, &QGCCameraManager::_vehicleReady);
    connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &QGCCameraManager::_mavlinkMessageReceived);
    connect(&_camerasLostHeartbeatTimer, &QTimer::timeout, this, &QGCCameraManager::_checkForLostCameras);
    connect(this, &QGCCameraManager::streamChanged, this, [this]() {
        if (auto* cam = currentCameraInstance()) {
            requestCameraFovForComp(cam->compID());
        }
        _syncCurrentCameraFovToSettings();
        emit currentCameraFovChanged();
    });

    _camerasLostHeartbeatTimer.setSingleShot(false);
    _lastZoomChange.start();
    _lastCameraChange.start();
    _camerasLostHeartbeatTimer.start(500);
}

QGCCameraManager::~QGCCameraManager()
{
    // Stop all camera info request timers and clean up
    for (auto* cameraInfo : _cameraInfoRequest) {
        if (cameraInfo->backoffTimer) {
            cameraInfo->backoffTimer->stop();
            QObject::disconnect(cameraInfo->backoffTimer, nullptr, nullptr, nullptr);
        }
        delete cameraInfo;
    }
    _cameraInfoRequest.clear();

    // Stop the main heartbeat timer
    _camerasLostHeartbeatTimer.stop();
}

void QGCCameraManager::registerQmlTypes()
{
    qmlRegisterUncreatableType<MavlinkCameraControl>("QGroundControl.Vehicle", 1, 0, "MavlinkCameraControl", "Reference only");
    qmlRegisterUncreatableType<QGCCameraManager>    ("QGroundControl.Vehicle", 1, 0, "QGCCameraManager",     "Reference only");
    qmlRegisterUncreatableType<QGCVideoStreamInfo>  ("QGroundControl.Vehicle", 1, 0, "QGCVideoStreamInfo",   "Reference only");
}

void QGCCameraManager::setCurrentCamera(int sel)
{
    if(sel != _currentCameraIndex && sel >= 0 && sel < _cameras.count()) {
        _currentCameraIndex = sel;
        emit currentCameraChanged();
        emit streamChanged();
        emit currentCameraFovChanged();
    }

    _syncCurrentCameraFovToSettings();

    if (auto* cam = currentCameraInstance()) {
        requestCameraFovForComp(cam->compID());
    }
}

void QGCCameraManager::_vehicleReady(bool ready)
{
    qCDebug(CameraManagerLog) << "_vehicleReady(" << ready << ")";
    if(ready) {
        if(MultiVehicleManager::instance()->activeVehicle() == _vehicle) {
            _vehicleReadyState = true;
            _activeJoystickChanged(JoystickManager::instance()->activeJoystick());
            connect(JoystickManager::instance(), &JoystickManager::activeJoystickChanged, this, &QGCCameraManager::_activeJoystickChanged);
        }
    }
}

void QGCCameraManager::_mavlinkMessageReceived(const mavlink_message_t& message)
{
    //-- Only pay attention to the camera components, as identified by their compId,
    //   as well as the autopilot, as it might have a non-MAVLink camera connected.
    if(message.sysid == _vehicle->id() && (message.compid == MAV_COMP_ID_AUTOPILOT1 ||
        (message.compid >= MAV_COMP_ID_CAMERA && message.compid <= MAV_COMP_ID_CAMERA6))) {
        switch (message.msgid) {
            case MAVLINK_MSG_ID_CAMERA_CAPTURE_STATUS:
                _handleCaptureStatus(message);
                break;
            case MAVLINK_MSG_ID_STORAGE_INFORMATION:
                _handleStorageInfo(message);
                break;
            case MAVLINK_MSG_ID_HEARTBEAT:
                _handleHeartbeat(message);
                break;
            case MAVLINK_MSG_ID_CAMERA_INFORMATION:
                _handleCameraInfo(message);
                break;
            case MAVLINK_MSG_ID_CAMERA_SETTINGS:
                _handleCameraSettings(message);
                break;
            case MAVLINK_MSG_ID_PARAM_EXT_ACK:
                _handleParamAck(message);
                break;
            case MAVLINK_MSG_ID_PARAM_EXT_VALUE:
                _handleParamValue(message);
                break;
            case MAVLINK_MSG_ID_VIDEO_STREAM_INFORMATION:
                _handleVideoStreamInfo(message);
                break;
            case MAVLINK_MSG_ID_VIDEO_STREAM_STATUS:
                _handleVideoStreamStatus(message);
                break;
            case MAVLINK_MSG_ID_BATTERY_STATUS:
                _handleBatteryStatus(message);
                break;
            case MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS:
                _handleTrackingImageStatus(message);
                break;
            case MAVLINK_MSG_ID_CAMERA_FOV_STATUS:
                _handleCameraFovStatus(message);
                break;
        }
    }
}

void QGCCameraManager::_handleHeartbeat(const mavlink_message_t &message)
{
    QString sCompID = QString::number(message.compid);

    if (!_cameraInfoRequest.contains(sCompID)) {
        // This is the first time we are heading from this camera
        qCDebug(CameraManagerLog) << "Hearbeat from " << message.compid;
        CameraStruct* pInfo = new CameraStruct(this, message.compid, _vehicle);
        pInfo->lastHeartbeat.start();
        _cameraInfoRequest[sCompID] = pInfo;
        _requestCameraInfo(pInfo);
    } else {
        if (_cameraInfoRequest[sCompID]) {
            CameraStruct* pInfo = _cameraInfoRequest[sCompID];
            //-- Check if we have indeed received the camera info
            if (pInfo->infoReceived) {
                //-- We have it. Just update the heartbeat timeout
                pInfo->lastHeartbeat.start();
            } else {
                //-- Camera info not received yet. Check if camera was silent and is now back
                if (pInfo->lastHeartbeat.elapsed() > 5000) {
                    qCDebug(CameraManagerLog) << "Camera" << message.compid << "reappeared after being silent. Resetting retry count and requesting info.";
                    pInfo->retryCount = 0;  // Reset retry count for fresh attempts
                    pInfo->backoffTimer->stop();  // Stop any pending backoff timer
                    pInfo->lastHeartbeat.start();
                    _requestCameraInfo(pInfo);
                } else {
                    //-- Just update heartbeat
                    pInfo->lastHeartbeat.start();
                }
            }
        } else {
            qWarning() << Q_FUNC_INFO << "_cameraInfoRequest[" << sCompID << "] is null";
        }
    }
}

MavlinkCameraControl* QGCCameraManager::currentCameraInstance()
{
    if(_currentCameraIndex < _cameras.count() && _cameras.count()) {
        auto pCamera = qobject_cast<MavlinkCameraControl*>(_cameras[_currentCameraIndex]);
        return pCamera;
    }
    return nullptr;
}

QGCVideoStreamInfo* QGCCameraManager::currentStreamInstance()
{
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        QGCVideoStreamInfo* pInfo = pCamera->currentStreamInstance();
        return pInfo;
    }
    return nullptr;
}

QGCVideoStreamInfo* QGCCameraManager::thermalStreamInstance()
{
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        QGCVideoStreamInfo* pInfo = pCamera->thermalStreamInstance();
        return pInfo;
    }
    return nullptr;
}

MavlinkCameraControl* QGCCameraManager::_findCamera(int id)
{
    for(int i = 0; i < _cameras.count(); i++) {
        if(_cameras[i]) {
            auto pCamera = qobject_cast<MavlinkCameraControl*>(_cameras[i]);
            if(pCamera) {
                if(pCamera->compID() == id) {
                    return pCamera;
                }
            } else {
                qCritical() << "Null MavlinkCameraControl instance";
            }
        }
    }
    //qWarning() << "Camera component id not found:" << id;
    return nullptr;
}

void QGCCameraManager::_addCameraControlToLists(MavlinkCameraControl* cameraControl)
{
    QQmlEngine::setObjectOwnership(cameraControl, QQmlEngine::CppOwnership);
    _cameras.append(cameraControl);
    _cameraLabels.append(cameraControl->modelName());
    emit camerasChanged();
    emit cameraLabelsChanged();

    // If the simulated camera is already in the list, remove it since we have a real camera now
    if (_cameras.count() == 2 && _cameras[0] == _simulatedCameraControl) {
        _cameras.removeAt(0);
        _cameraLabels.removeAt(0);
        emit camerasChanged();
        emit cameraLabelsChanged();
        emit currentCameraChanged();
    }
}

//-----------------------------------------------------------------------------
void QGCCameraManager::_handleCameraInfo(const mavlink_message_t& message)
{
    qCDebug(CameraManagerLog) << "_handleCameraInfo";

    // Decode first so 'info' is available for aspect/FOV calculations below
    mavlink_camera_information_t camInfo{};
    mavlink_msg_camera_information_decode(&message, &camInfo);

    //-- Have we requested it?
    const QString sCompID = QString::number(message.compid);

    if (_cameraInfoRequest.contains(sCompID) && !_cameraInfoRequest[sCompID]->infoReceived) {
        //-- Flag it as done
        _cameraInfoRequest[sCompID]->infoReceived = true;
        _cameraInfoRequest[sCompID]->retryCount = 0;         // Reset retry counter on success
        _cameraInfoRequest[sCompID]->backoffTimer->stop();   // Stop any pending backoff timer

        qCDebug(CameraManagerLog)
            << "_handleCameraInfo: Success for compId" << message.compid << "- reset retry counter";

        qCDebug(CameraManagerLog)
            << "_handleCameraInfo:"
            << reinterpret_cast<const char*>(camInfo.model_name)
            << reinterpret_cast<const char*>(camInfo.vendor_name)
            << "Comp ID:" << message.compid;

        auto* pCamera = _vehicle->firmwarePlugin()->createCameraControl(&camInfo, _vehicle, message.compid, this);
        if (pCamera) {
            _addCameraControlToLists(pCamera);
        }
    }

    double aspect = std::numeric_limits<double>::quiet_NaN();

    if (camInfo.resolution_h > 0 && camInfo.resolution_v > 0) {
        aspect = double(camInfo.resolution_v) / double(camInfo.resolution_h);
    } else if (camInfo.sensor_size_h > 0.f && camInfo.sensor_size_v > 0.f) {
        aspect = double(camInfo.sensor_size_v) / double(camInfo.sensor_size_h);
    }

    _aspectByCompId.insert(message.compid, aspect);

}

/// Called to check for cameras which are no longer sending a heartbeat
void QGCCameraManager::_checkForLostCameras()
{
    //-- Iterate cameras
    for (auto it = _cameraInfoRequest.constBegin(); it != _cameraInfoRequest.constEnd(); ++it) {
        const QString &sCompID = it.key();
        if (_cameraInfoRequest[sCompID]) {
            CameraStruct* pInfo = _cameraInfoRequest[sCompID];
            //-- Have we received a camera info message?
            if (pInfo->infoReceived) {
                //-- Has the camera stopped talking to us?
                if (pInfo->lastHeartbeat.elapsed() > 5000) {
                    auto pCamera = _findCamera(pInfo->compID);

                    if (pCamera) {
                        // Before removing the current camera from the list add the simulated camera back into the list if thera are no other cameras.
                        // This way we smaoothly transition from a real camera to the simulated camera.
                        if (_cameras.count() == 1) {
                            qCDebug(CameraManagerLog) << "Adding simulated camera back to list.";
                            _addCameraControlToLists(_simulatedCameraControl);
                        }

                        qWarning() << "Camera" << pCamera->modelName() << "stopped transmitting. Removing from list.";
                        _cameraLabels.removeOne(pCamera->modelName());
                        _cameras.removeOne(pCamera);
                        emit cameraLabelsChanged();
                        emit camerasChanged();

                        pCamera->deleteLater();
                        delete pInfo;

                        // There will always be at least one camera in the list, so we don't need to check if the list is empty.
                        // We specifically don't use setCurrentCamera since that checks for a index change. But in this case we may be using the same index.
                        _currentCameraIndex = 0;
                        emit currentCameraChanged();
                        emit streamChanged();
                    }

                    _cameraInfoRequest.remove(sCompID);

                    //-- Exit loop.
                    return;
                }
            }
        }
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleCaptureStatus(const mavlink_message_t &message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_capture_status_t cap;
        mavlink_msg_camera_capture_status_decode(&message, &cap);
        pCamera->handleCaptureStatus(cap);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleStorageInfo(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_storage_information_t st;
        mavlink_msg_storage_information_decode(&message, &st);
        pCamera->handleStorageInfo(st);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleCameraSettings(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_settings_t settings;
        mavlink_msg_camera_settings_decode(&message, &settings);
        pCamera->handleSettings(settings);
    }
    requestCameraFovForComp(message.compid);
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleParamAck(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_param_ext_ack_t ack;
        mavlink_msg_param_ext_ack_decode(&message, &ack);
        pCamera->handleParamAck(ack);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleParamValue(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_param_ext_value_t value;
        mavlink_msg_param_ext_value_decode(&message, &value);
        pCamera->handleParamValue(value);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleVideoStreamInfo(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_video_stream_information_t streamInfo;
        mavlink_msg_video_stream_information_decode(&message, &streamInfo);
        pCamera->handleVideoInfo(&streamInfo);
        emit streamChanged();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleVideoStreamStatus(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_video_stream_status_t streamStatus;
        mavlink_msg_video_stream_status_decode(&message, &streamStatus);
        pCamera->handleVideoStatus(&streamStatus);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleBatteryStatus(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_battery_status_t batteryStatus;
        mavlink_msg_battery_status_decode(&message, &batteryStatus);
        pCamera->handleBatteryStatus(batteryStatus);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleTrackingImageStatus(const mavlink_message_t& message)
{
    auto pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_tracking_image_status_t tis;
        mavlink_msg_camera_tracking_image_status_decode(&message, &tis);
        pCamera->handleTrackingImageStatus(&tis);
    }
}

// Forward declarations for mutually recursive handler functions
static void _requestCameraInfoCommandResultHandler(void* resultHandlerData, int compId, const mavlink_command_ack_t& ack, Vehicle::MavCmdResultFailureCode_t failureCode);
static void _requestCameraInfoMessageResultHandler(void* resultHandlerData, MAV_RESULT result, Vehicle::RequestMessageResultHandlerFailureCode_t failureCode, const mavlink_message_t& message);
static void _requestCameraInfoHelper(QGCCameraManager* manager, QGCCameraManager::CameraStruct* pInfo);


static void _handleCameraInfoRetry(QGCCameraManager::CameraStruct* cameraInfo)
{
    cameraInfo->retryCount++;
    auto manager = static_cast<QGCCameraManager*>(cameraInfo->parent());

    // For even attempts >= 2, use exponential backoff
    if (cameraInfo->retryCount >= 2 && cameraInfo->retryCount % 2 == 0) {
        // Calculate delay: 2^(retryCount/2) seconds
        int delaySeconds = 1 << (cameraInfo->retryCount / 2);
        int delayMs = delaySeconds * 1000;

        qCDebug(CameraManagerLog) << "Waiting" << delaySeconds << "seconds before retry for compId" << cameraInfo->compID;

        // Stop any existing timer and set up new one
        cameraInfo->backoffTimer->stop();
        QObject::disconnect(cameraInfo->backoffTimer, nullptr, nullptr, nullptr);
        QObject::connect(cameraInfo->backoffTimer, &QTimer::timeout, manager, [=]() {
            _requestCameraInfoHelper(manager, cameraInfo);
        });

        cameraInfo->backoffTimer->start(delayMs);
    } else {
        // Make immediate retry
        _requestCameraInfoHelper(manager, cameraInfo);
    }
}

static void _requestCameraInfoCommandResultHandler(void* resultHandlerData, int compId, const mavlink_command_ack_t& ack, Vehicle::MavCmdResultFailureCode_t failureCode)
{
    auto  cameraInfo = static_cast<QGCCameraManager::CameraStruct*>(resultHandlerData);

    if (ack.result != MAV_RESULT_ACCEPTED) {
        qCDebug(CameraManagerLog) << "MAV_CMD_REQUEST_CAMERA_INFORMATION failed. compId" << cameraInfo->compID << "Result:" << ack.result << "FailureCode:" << failureCode << "retryCount:" << cameraInfo->retryCount;

        _handleCameraInfoRetry(cameraInfo);
    }
}

static void _requestCameraInfoMessageResultHandler(void* resultHandlerData, MAV_RESULT result, Vehicle::RequestMessageResultHandlerFailureCode_t failureCode, [[maybe_unused]] const mavlink_message_t& message)
{
    auto cameraInfo = static_cast<QGCCameraManager::CameraStruct*>(resultHandlerData);

    if (result != MAV_RESULT_ACCEPTED) {
        qCDebug(CameraManagerLog) << "MAV_CMD_REQUEST_MESSAGE:MAVLINK_MSG_ID_CAMERA_INFORMATION failed. compId" << cameraInfo->compID << "Result:" << result << "FailureCode:" << failureCode << "retryCount:" << cameraInfo->retryCount;

        _handleCameraInfoRetry(cameraInfo);
    }
}

//-----------------------------------------------------------------------------
static void _requestCameraInfoHelper(QGCCameraManager* manager, QGCCameraManager::CameraStruct* pInfo)
{
    // Give up after 10 attempts
    if (pInfo->retryCount >= 10) {
        qCWarning(CameraManagerLog) << "Giving up requesting camera info after" << pInfo->retryCount << "attempts for compId" << pInfo->compID;
        return;
    }

    // Make immediate request - alternate between REQUEST_MESSAGE and REQUEST_CAMERA_INFORMATION
    if (pInfo->retryCount % 2 == 0) {
        qCDebug(CameraManagerLog) << "Using MAV_CMD_REQUEST_MESSAGE for compId" << pInfo->compID;
        manager->vehicle()->requestMessage(_requestCameraInfoMessageResultHandler, pInfo, pInfo->compID, MAVLINK_MSG_ID_CAMERA_INFORMATION);
    } else {
        qCDebug(CameraManagerLog) << "Using MAV_CMD_REQUEST_CAMERA_INFORMATION for compId" << pInfo->compID;

        Vehicle::MavCmdAckHandlerInfo_t ackHandlerInfo;
        ackHandlerInfo.resultHandler        = _requestCameraInfoCommandResultHandler;
        ackHandlerInfo.resultHandlerData    = pInfo;
        ackHandlerInfo.progressHandler      = nullptr;
        ackHandlerInfo.progressHandlerData  = nullptr;

        pInfo->vehicle->sendMavCommandWithHandler(&ackHandlerInfo, pInfo->compID, MAV_CMD_REQUEST_CAMERA_INFORMATION, 1 /* request camera capabilities */);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_requestCameraInfo(CameraStruct* pInfo)
{
    _requestCameraInfoHelper(this, pInfo);
}

//----------------------------------------------------------------------------------------
void
QGCCameraManager::_activeJoystickChanged(Joystick* joystick)
{
    qCDebug(CameraManagerLog) << "Joystick changed";
    if(_activeJoystick) {
        disconnect(_activeJoystick, &Joystick::stepZoom,            this, &QGCCameraManager::_stepZoom);
        disconnect(_activeJoystick, &Joystick::startContinuousZoom, this, &QGCCameraManager::_startZoom);
        disconnect(_activeJoystick, &Joystick::stopContinuousZoom,  this, &QGCCameraManager::_stopZoom);
        disconnect(_activeJoystick, &Joystick::stepCamera,          this, &QGCCameraManager::_stepCamera);
        disconnect(_activeJoystick, &Joystick::stepStream,          this, &QGCCameraManager::_stepStream);
        disconnect(_activeJoystick, &Joystick::triggerCamera,       this, &QGCCameraManager::_triggerCamera);
        disconnect(_activeJoystick, &Joystick::startVideoRecord,    this, &QGCCameraManager::_startVideoRecording);
        disconnect(_activeJoystick, &Joystick::stopVideoRecord,     this, &QGCCameraManager::_stopVideoRecording);
        disconnect(_activeJoystick, &Joystick::toggleVideoRecord,   this, &QGCCameraManager::_toggleVideoRecording);
    }
    _activeJoystick = joystick;
    if(_activeJoystick) {
        connect(_activeJoystick, &Joystick::stepZoom,               this, &QGCCameraManager::_stepZoom);
        connect(_activeJoystick, &Joystick::startContinuousZoom,    this, &QGCCameraManager::_startZoom);
        connect(_activeJoystick, &Joystick::stopContinuousZoom,     this, &QGCCameraManager::_stopZoom);
        connect(_activeJoystick, &Joystick::stepCamera,             this, &QGCCameraManager::_stepCamera);
        connect(_activeJoystick, &Joystick::stepStream,             this, &QGCCameraManager::_stepStream);
        connect(_activeJoystick, &Joystick::triggerCamera,          this, &QGCCameraManager::_triggerCamera);
        connect(_activeJoystick, &Joystick::startVideoRecord,       this, &QGCCameraManager::_startVideoRecording);
        connect(_activeJoystick, &Joystick::stopVideoRecord,        this, &QGCCameraManager::_stopVideoRecording);
        connect(_activeJoystick, &Joystick::toggleVideoRecord,      this, &QGCCameraManager::_toggleVideoRecording);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_triggerCamera()
{
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->takePhoto();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_startVideoRecording()
{
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->startVideoRecording();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stopVideoRecording()
{
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->stopVideoRecording();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_toggleVideoRecording()
{
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->toggleVideoRecording();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stepZoom(int direction)
{
    if(_lastZoomChange.elapsed() > 40) {
        _lastZoomChange.start();
        qCDebug(CameraManagerLog) << "Step Camera Zoom" << direction;
        auto pCamera = currentCameraInstance();
        if(pCamera) {
            pCamera->stepZoom(direction);
        }
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_startZoom(int direction)
{
    qCDebug(CameraManagerLog) << "Start Camera Zoom" << direction;
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->startZoom(direction);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stopZoom()
{
    qCDebug(CameraManagerLog) << "Stop Camera Zoom";
    auto pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->stopZoom();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stepCamera(int direction)
{
    if(_lastCameraChange.elapsed() > 1000) {
        _lastCameraChange.start();
        qCDebug(CameraManagerLog) << "Step Camera" << direction;
        int c = _currentCameraIndex + direction;
        if(c < 0) c = _cameras.count() - 1;
        if(c >= _cameras.count()) c = 0;
        setCurrentCamera(c);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stepStream(int direction)
{
    if(_lastCameraChange.elapsed() > 1000) {
        _lastCameraChange.start();
        auto pCamera = currentCameraInstance();
        if(pCamera) {
            qCDebug(CameraManagerLog) << "Step Camera Stream" << direction;
            int c = pCamera->currentStream() + direction;
            if(c < 0) c = pCamera->streams()->count() - 1;
            if(c >= pCamera->streams()->count()) c = 0;
            pCamera->setCurrentStream(c);
        }
    }
}

const QVariantList &QGCCameraManager::cameraList()
{
    if (_cameraList.isEmpty()) {
        const QList<CameraMetaData*> cams = _parseCameraMetaData(QStringLiteral(":/json/CameraMetaData.json"));
        _cameraList.reserve(cams.size());

        for (CameraMetaData* cam : cams) {
            _cameraList << QVariant::fromValue(cam);
        }
    }

    return _cameraList;
}

QList<CameraMetaData*> QGCCameraManager::_parseCameraMetaData(const QString &jsonFilePath)
{
    QList<CameraMetaData*> cameraList;

    QString errorString;
    int version;
    const QJsonObject jsonObject = JsonHelper::openInternalQGCJsonFile(jsonFilePath, "CameraMetaData", 1, 1, version, errorString);
    if (!errorString.isEmpty()) {
        qCWarning(CameraManagerLog) << "Internal Error:" << errorString;
        return cameraList;
    }

    static const QList<JsonHelper::KeyValidateInfo> rootKeyInfoList = {
        { "cameraMetaData", QJsonValue::Array, true }
    };
    if (!JsonHelper::validateKeys(jsonObject, rootKeyInfoList, errorString)) {
        qCWarning(CameraManagerLog) << errorString;
        return cameraList;
    }

    static const QList<JsonHelper::KeyValidateInfo> cameraKeyInfoList = {
        { "canonicalName", QJsonValue::String, true },
        { "brand", QJsonValue::String, true },
        { "model", QJsonValue::String, true },
        { "sensorWidth", QJsonValue::Double, true },
        { "sensorHeight", QJsonValue::Double, true },
        { "imageWidth", QJsonValue::Double, true },
        { "imageHeight", QJsonValue::Double, true },
        { "focalLength", QJsonValue::Double, true },
        { "landscape", QJsonValue::Bool, true },
        { "fixedOrientation", QJsonValue::Bool, true },
        { "minTriggerInterval", QJsonValue::Double, true },
        { "deprecatedTranslatedName", QJsonValue::String, true },
    };
    const QJsonArray cameraInfo = jsonObject["cameraMetaData"].toArray();
    for (const QJsonValue &jsonValue : cameraInfo) {
        if (!jsonValue.isObject()) {
            qCWarning(CameraManagerLog) << "Entry in CameraMetaData array is not object";
            return cameraList;
        }

        const QJsonObject obj = jsonValue.toObject();
        if (!JsonHelper::validateKeys(obj, cameraKeyInfoList, errorString)) {
            qCWarning(CameraManagerLog) << errorString;
            return cameraList;
        }

        const QString canonicalName = obj["canonicalName"].toString();
        const QString brand = obj["brand"].toString();
        const QString model = obj["model"].toString();
        const double sensorWidth = obj["sensorWidth"].toDouble();
        const double sensorHeight = obj["sensorHeight"].toDouble();
        const double imageWidth = obj["imageWidth"].toDouble();
        const double imageHeight = obj["imageHeight"].toDouble();
        const double focalLength = obj["focalLength"].toDouble();
        const bool landscape = obj["landscape"].toBool();
        const bool fixedOrientation = obj["fixedOrientation"].toBool();
        const double minTriggerInterval = obj["minTriggerInterval"].toDouble();
        const QString deprecatedTranslatedName = obj["deprecatedTranslatedName"].toString();

        CameraMetaData *const metaData = new CameraMetaData(
            canonicalName, brand, model, sensorWidth, sensorHeight,
            imageWidth, imageHeight, focalLength, landscape,
            fixedOrientation, minTriggerInterval, deprecatedTranslatedName);
        cameraList.append(metaData);
    }

    return cameraList;
}

void QGCCameraManager::handleCameraFovStatusFromRequest(const mavlink_message_t& message)
{
    _handleCameraFovStatus(message);
}

void QGCCameraManager::requestCameraFovForComp(int compId) {
    if (!_vehicle) {
        qCWarning(CameraManagerLog) << "requestCameraFovForComp: vehicle is null";
        return;
    }

    auto* const cameraManagerGuard = new QPointer<QGCCameraManager>(this);
    _vehicle->requestMessage(_cameraFovStatusRequestHandler, cameraManagerGuard, compId, MAVLINK_MSG_ID_CAMERA_FOV_STATUS);
}

//-----------------------------------------------------------------------------
double QGCCameraManager::aspectForComp(int compId) const {
    auto it = _aspectByCompId.constFind(compId);
    return (it == _aspectByCompId.cend())
           ? std::numeric_limits<double>::quiet_NaN()
           : it.value();
}

double QGCCameraManager::currentCameraAspect(){
    if (auto* cam = currentCameraInstance()) {
        return aspectForComp(cam->compID());
    }
    return std::numeric_limits<double>::quiet_NaN();
}

double QGCCameraManager::currentCameraHFov() const
{
    const double streamHFovDeg = _currentStreamHFovDeg();
    if (_isUsableFovDeg(streamHFovDeg)) {
        return streamHFovDeg;
    }

    const int fovSourceKey = _currentFovSourceKey();
    if (fovSourceKey < 0) {
        return _settingsCameraHFovDeg();
    }

    auto it = _fovBySourceKey.constFind(fovSourceKey);
    return (it == _fovBySourceKey.cend()) ? _settingsCameraHFovDeg() : it->hfovDeg;
}

double QGCCameraManager::currentCameraVFov() const
{
    const double streamHFovDeg = _currentStreamHFovDeg();
    if (_isUsableFovDeg(streamHFovDeg)) {
        const double streamAspect = _currentStreamAspectForVfov();
        return _calculatedVfovDeg(streamHFovDeg, _usableCameraAspect(streamAspect));
    }

    const int fovSourceKey = _currentFovSourceKey();
    if (fovSourceKey < 0) {
        return _settingsCameraVFovDeg();
    }

    auto it = _fovBySourceKey.constFind(fovSourceKey);
    return (it == _fovBySourceKey.cend()) ? _settingsCameraVFovDeg() : it->vfovDeg;
}

void QGCCameraManager::_handleCameraFovStatus(const mavlink_message_t& message)
{
    mavlink_camera_fov_status_t fov{};
    mavlink_msg_camera_fov_status_decode(&message, &fov);

    if (!_vehicle || MultiVehicleManager::instance()->activeVehicle() != _vehicle || message.sysid != _vehicle->id()) {
        return;
    }

    const int currentFovSourceKey = _currentFovSourceKey();
    const int messageFovSourceKey = _fovSourceKey(message.compid, fov.camera_device_id);
    if (currentFovSourceKey < 0 || messageFovSourceKey != currentFovSourceKey) {
        return;
    }

    const double hfovDeg = _isUsableFovDeg(fov.hfov)
                               ? fov.hfov
                               : _settingsCameraHFovDeg();

    if (!_isUsableFovDeg(hfovDeg)) {
        return;
    }

    const double aspect = _usableCameraAspect(aspectForComp(message.compid));
    const double calculatedVfovDeg = _calculatedVfovDeg(hfovDeg, aspect);
    const double vfovDeg = _isUsableFovDeg(fov.vfov) ? fov.vfov : calculatedVfovDeg;

    if (!_isUsableFovDeg(vfovDeg)) {
        qCWarning(CameraManagerLog) << "Invalid VFOV:" << vfovDeg
                                    << "hfov:" << fov.hfov
                                    << "fallback/calculated hfov:" << hfovDeg
                                    << "raw vfov:" << fov.vfov
                                    << "calculated vfov:" << calculatedVfovDeg
                                    << "aspect:" << aspect
                                    << "compId:" << message.compid;
        return;
    }
    _fovBySourceKey[messageFovSourceKey] = { hfovDeg, vfovDeg };

    _syncCurrentCameraFovToSettings();
    emit currentCameraFovChanged();
}

bool QGCCameraManager::_readFloatProperty(const QObject* object, const char* propertyName, float& valueOut)
{
    if (!object) {
        return false;
    }

    const QVariant propertyVariant = object->property(propertyName);
    if (!propertyVariant.isValid()) {
        return false;
    }

    bool convertOk = false;
    const float propertyValue = propertyVariant.toFloat(&convertOk);
    if (!convertOk) {
        return false;
    }

    valueOut = propertyValue;
    return true;
}

int QGCCameraManager::_currentFovSourceKey() const
{
    auto* manager = const_cast<QGCCameraManager*>(this);
    auto* cam = manager->currentCameraInstance();
    if (!cam) {
        return -1;
    }

    auto* stream = manager->currentStreamInstance();
    const uint8_t cameraDeviceId = stream ? stream->cameraDeviceID() : 0;
    return _fovSourceKey(cam->compID(), cameraDeviceId);
}

double QGCCameraManager::_currentStreamHFovDeg() const
{
    auto* manager = const_cast<QGCCameraManager*>(this);
    auto* stream = manager->currentStreamInstance();
    if (!stream) {
        return std::numeric_limits<double>::quiet_NaN();
    }

    return stream->hfov();
}

double QGCCameraManager::_currentStreamAspectForVfov() const
{
    auto* manager = const_cast<QGCCameraManager*>(this);
    auto* stream = manager->currentStreamInstance();
    if (!stream || !std::isfinite(stream->aspectRatio()) || stream->aspectRatio() <= 0.0) {
        auto* cam = manager->currentCameraInstance();
        return cam ? aspectForComp(cam->compID()) : std::numeric_limits<double>::quiet_NaN();
    }

    return 1.0 / stream->aspectRatio();
}

void QGCCameraManager::_syncCurrentCameraFovToSettings()
{
    auto* cam = currentCameraInstance();
    if (!cam) {
        return;
    }

    auto* settings = SettingsManager::instance()->gimbalControllerSettings();
    const double hfovDeg = currentCameraHFov();
    const double vfovDeg = currentCameraVFov();
    const int fovSourceKey = _currentFovSourceKey();
    const auto fovIt = _fovBySourceKey.constFind(fovSourceKey);
    const bool hasFovStatus =
        _isUsableFovDeg(_currentStreamHFovDeg()) ||
        (fovIt != _fovBySourceKey.cend() && _isUsableFovDeg(fovIt->hfovDeg));

    if (_isUsableFovDeg(hfovDeg) && _isUsableFovDeg(vfovDeg)) {
        settings->CameraHFov()->setRawValue(hfovDeg);
        settings->CameraVFov()->setRawValue(vfovDeg);
    }

    const float zoomMaxSpeed = settings->zoomMaxSpeed()->rawValue().toFloat();
    const float zoomMinSpeed = settings->zoomMinSpeed()->rawValue().toFloat();

    float zoom = 1.f;
    bool  hasZoom = false;

    if (hasFovStatus) {
        hasZoom =
            _readFloatProperty(cam, "zoomLevel", zoom) ||
            _readFloatProperty(cam, "zoom", zoom);

        if (!hasZoom) {
            settings->gimbalSpeed()->setRawValue(zoomMaxSpeed);
            return;
        }
    } else {
        zoom = 1.f;
        hasZoom = true;
    }

    zoom = std::clamp(zoom, 1.f, 100.f);
    const float zoomNormalized = (zoom - 1.f) / 99.f;
    const float resultSpeed = zoomMaxSpeed + zoomNormalized * (zoomMinSpeed - zoomMaxSpeed);

    settings->gimbalSpeed()->setRawValue(resultSpeed);
}

void QGCCameraManager::_setCurrentZoomLevel(int level)
{
    if (_zoomValueCurrent == level) {
        return;
    }
    _zoomValueCurrent = level;
    emit currentZoomLevelChanged();
}

int QGCCameraManager::currentZoomLevel() const
{
    return _zoomValueCurrent;
}

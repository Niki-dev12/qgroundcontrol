/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ComponentInformationManager.h"
#include "ComponentInformationTranslation.h"
#include "ComponentInformationCache.h"
#include "Vehicle.h"
#include "FTPManager.h"
#include "QGCLZMA.h"
#include "CompInfoGeneral.h"
#include "CompInfoParam.h"
#include "CompInfoEvents.h"
#include "CompInfoActuators.h"
#include "QGCApplication.h"
#include "QGCCachedFileDownload.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QStandardPaths>

#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonValue>
#include <QtCore/QJsonParseError>

QGC_LOGGING_CATEGORY(ComponentInformationManagerLog, "qgc.vehicle.components.componentinformationmanager")

#define VEHICLE_IDENTIFICATION 39

void ComponentInformationManager::_ensureCompInfoSet(uint8_t compId)
{
    if (!_compInfoMap.contains(compId)) {
        _compInfoMap[compId][COMP_METADATA_TYPE_GENERAL]    = new CompInfoGeneral(compId, _vehicle, this);
        _compInfoMap[compId][COMP_METADATA_TYPE_PARAMETER]  = new CompInfoParam(compId, _vehicle, this);
        _compInfoMap[compId][COMP_METADATA_TYPE_EVENTS]     = new CompInfoEvents(compId, _vehicle, this);
        _compInfoMap[compId][COMP_METADATA_TYPE_ACTUATORS]  = new CompInfoActuators(compId, _vehicle, this);
    }
}

ComponentInformationManager::ComponentInformationManager(Vehicle *vehicle, QObject *parent)
    : StateMachine(parent)
    , _vehicle(vehicle)
    , _requestTypeStateMachine(this, this)
    , _cachedFileDownload(new QGCCachedFileDownload(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QLatin1String("/QGCCompInfoFileDownloadCache"), this))
    , _fileCache(ComponentInformationCache::defaultInstance())
    , _translation(new ComponentInformationTranslation(this, _cachedFileDownload))
{
    _ensureCompInfoSet(MAV_COMP_ID_AUTOPILOT1);
}

ComponentInformationManager::~ComponentInformationManager()
{
    // qCDebug(ComponentInformationManagerLog) << Q_FUNC_INFO << this;
}

int ComponentInformationManager::stateCount(void) const
{
    return _cStates;
}

const ComponentInformationManager::StateFn* ComponentInformationManager::rgStates(void) const
{
    return &_rgStates[0];
}

float ComponentInformationManager::progress() const
{
    if (!_active)
        return 1.f;
    // here we could compute a more fine-grained progress, based on ftp download progress
    return _stateIndex / (float)_cStates;
}

void ComponentInformationManager::advance()
{
    StateMachine::advance();
    emit progressUpdate(progress());
}

void ComponentInformationManager::requestAllComponentInformation(RequestAllCompleteFn requestAllCompletFn, void * requestAllCompleteFnData)
{
    _requestAllCompleteFn       = requestAllCompletFn;
    _requestAllCompleteFnData   = requestAllCompleteFnData;

    _pendingGeneralCompIds.clear();
    _pendingGeneralCompIds.append(MAV_COMP_ID_AUTOPILOT1);

    // Component metadata
    _pendingGeneralCompIds.append(VEHICLE_IDENTIFICATION);

    for (uint8_t compId : _pendingGeneralCompIds) {
        _ensureCompInfoSet(compId);
    }

    _currentGeneralCompIndex = -1;

    start();
    emit progressUpdate(progress());
}

void ComponentInformationManager::_stateRequestCompInfoGeneral(StateMachine* stateMachine)
{
    ComponentInformationManager* compMgr = static_cast<ComponentInformationManager*>(stateMachine);

    compMgr->_currentGeneralCompIndex = 0;

    if (compMgr->_pendingGeneralCompIds.isEmpty()) {
        qCDebug(ComponentInformationManagerLog) << "No components queued for general metadata request";
        compMgr->advance();
        return;
    }

    const uint8_t compId = compMgr->_pendingGeneralCompIds[compMgr->_currentGeneralCompIndex];
    compMgr->_ensureCompInfoSet(compId);

    qCDebug(ComponentInformationManagerLog)
        << "Starting general metadata request"
        << "compId:" << compId;

    compMgr->_requestTypeStateMachine.request(compMgr->_compInfoMap[compId][COMP_METADATA_TYPE_GENERAL]);
}

void ComponentInformationManager::_stateRequestCompInfoGeneralComplete(StateMachine* stateMachine)
{
    ComponentInformationManager* compMgr = static_cast<ComponentInformationManager*>(stateMachine);

    if (compMgr->_requestTypeStateMachine.compInfo() &&
        compMgr->_requestTypeStateMachine.compInfo()->type == COMP_METADATA_TYPE_GENERAL) {
        compMgr->_updateAllUri(compMgr->_requestTypeStateMachine.compInfo()->compId);
    }

    compMgr->_currentGeneralCompIndex++;

    if (compMgr->_currentGeneralCompIndex < compMgr->_pendingGeneralCompIds.count()) {
        const uint8_t compId = compMgr->_pendingGeneralCompIds[compMgr->_currentGeneralCompIndex];
        compMgr->_ensureCompInfoSet(compId);

        qCDebug(ComponentInformationManagerLog)
            << "Starting next general metadata request"
            << "compId:" << compId;

        compMgr->_requestTypeStateMachine.request(compMgr->_compInfoMap[compId][COMP_METADATA_TYPE_GENERAL]);
        return;
    }

    compMgr->advance();
}

void ComponentInformationManager::_updateAllUri(uint8_t compId)
{
    if (!_compInfoMap.contains(compId)) {
        return;
    }

    CompInfoGeneral* general = qobject_cast<CompInfoGeneral*>(_compInfoMap[compId][COMP_METADATA_TYPE_GENERAL]);
    if (!general) {
        return;
    }

    for (auto& compInfo : _compInfoMap[compId]) {
        general->setUris(*compInfo);
    }
}

void ComponentInformationManager::requestComponentGeneralInformation(uint8_t compId)
{
    _ensureCompInfoSet(compId);
    _requestTypeStateMachine.request(_compInfoMap[compId][COMP_METADATA_TYPE_GENERAL]);
}

void ComponentInformationManager::_stateRequestCompInfoComplete(void)
{
    advance();
}

void ComponentInformationManager::_stateRequestCompInfoParam(StateMachine* stateMachine)
{
    ComponentInformationManager* compMgr = static_cast<ComponentInformationManager*>(stateMachine);

    if (compMgr->_isCompTypeSupported(COMP_METADATA_TYPE_PARAMETER)) {
        compMgr->_requestTypeStateMachine.request(compMgr->_compInfoMap[MAV_COMP_ID_AUTOPILOT1][COMP_METADATA_TYPE_PARAMETER]);
    } else {
        qCDebug(ComponentInformationManagerLog) << "_stateRequestCompInfoParam skipping, not supported";
        compMgr->advance();
    }
}

void ComponentInformationManager::_stateRequestCompInfoEvents(StateMachine* stateMachine)
{
    ComponentInformationManager* compMgr = static_cast<ComponentInformationManager*>(stateMachine);

    if (compMgr->_isCompTypeSupported(COMP_METADATA_TYPE_EVENTS)) {
        compMgr->_requestTypeStateMachine.request(compMgr->_compInfoMap[MAV_COMP_ID_AUTOPILOT1][COMP_METADATA_TYPE_EVENTS]);
    } else {
        qCDebug(ComponentInformationManagerLog) << "_stateRequestCompInfoEvents skipping, not supported";
        compMgr->advance();
    }
}

void ComponentInformationManager::_stateRequestCompInfoActuators(StateMachine* stateMachine)
{
    ComponentInformationManager* compMgr = static_cast<ComponentInformationManager*>(stateMachine);

    if (compMgr->_isCompTypeSupported(COMP_METADATA_TYPE_ACTUATORS)) {
        compMgr->_requestTypeStateMachine.request(compMgr->_compInfoMap[MAV_COMP_ID_AUTOPILOT1][COMP_METADATA_TYPE_ACTUATORS]);
    } else {
        qCDebug(ComponentInformationManagerLog) << "_stateRequestCompInfoActuators skipping, not supported";
        compMgr->advance();
    }
}

void ComponentInformationManager::_stateRequestAllCompInfoComplete(StateMachine* stateMachine)
{
    ComponentInformationManager* compMgr = static_cast<ComponentInformationManager*>(stateMachine);
    (*compMgr->_requestAllCompleteFn)(compMgr->_requestAllCompleteFnData);
    compMgr->_requestAllCompleteFn      = nullptr;
    compMgr->_requestAllCompleteFnData  = nullptr;
}

bool ComponentInformationManager::_isCompTypeSupported(COMP_METADATA_TYPE type)
{
    return qobject_cast<CompInfoGeneral*>(_compInfoMap[MAV_COMP_ID_AUTOPILOT1][COMP_METADATA_TYPE_GENERAL])->isMetaDataTypeSupported(type);
}

CompInfoParam* ComponentInformationManager::compInfoParam(uint8_t compId)
{
    _ensureCompInfoSet(compId);
    return qobject_cast<CompInfoParam*>(_compInfoMap[compId][COMP_METADATA_TYPE_PARAMETER]);
}

CompInfoGeneral* ComponentInformationManager::compInfoGeneral(uint8_t compId)
{
    _ensureCompInfoSet(compId);
    return qobject_cast<CompInfoGeneral*>(_compInfoMap[compId][COMP_METADATA_TYPE_GENERAL]);
}

QString ComponentInformationManager::_getFileCacheTag(int compInfoType, uint32_t crc, bool isTranslation)
{
    return QString::asprintf("%08x_%02i_%i", crc, compInfoType, (int)isTranslation);
}


RequestMetaDataTypeStateMachine::RequestMetaDataTypeStateMachine(ComponentInformationManager *compMgr, QObject *parent)
    : StateMachine(parent)
    , _compMgr(compMgr)
{
    // qCDebug(RequestMetaDataTypeStateMachineLog) << Q_FUNC_INFO << this;
}

RequestMetaDataTypeStateMachine::~RequestMetaDataTypeStateMachine()
{
    // qCDebug(RequestMetaDataTypeStateMachineLog) << Q_FUNC_INFO << this;
}

void RequestMetaDataTypeStateMachine::request(CompInfo* compInfo)
{
    _compInfo   = compInfo;
    _stateIndex = -1;
    _jsonMetadataFileName.clear();
    _jsonTranslationFileName.clear();

    start();
}

int RequestMetaDataTypeStateMachine::stateCount(void) const
{
    return _cStates;
}

const RequestMetaDataTypeStateMachine::StateFn* RequestMetaDataTypeStateMachine::rgStates(void) const
{
    return &_rgStates[0];
}

void RequestMetaDataTypeStateMachine::statesCompleted(void) const
{
    _compMgr->_stateRequestCompInfoComplete();
}

QString RequestMetaDataTypeStateMachine::typeToString(void)
{
    switch (_compInfo->type) {
        case COMP_METADATA_TYPE_GENERAL: return "COMP_METADATA_TYPE_GENERAL";
        case COMP_METADATA_TYPE_PARAMETER: return "COMP_METADATA_TYPE_PARAMETER";
        case COMP_METADATA_TYPE_COMMANDS: return "COMP_METADATA_TYPE_COMMANDS";
        case COMP_METADATA_TYPE_PERIPHERALS: return "COMP_METADATA_TYPE_PERIPHERALS";
        case COMP_METADATA_TYPE_EVENTS: return "COMP_METADATA_TYPE_EVENTS";
        case COMP_METADATA_TYPE_ACTUATORS: return "COMP_METADATA_TYPE_ACTUATORS";
        default: break;
    }
    return "Unknown";
}

static void _requestMessageResultHandler(void* resultHandlerData, MAV_RESULT result,
    [[maybe_unused]] Vehicle::RequestMessageResultHandlerFailureCode_t failureCode, const mavlink_message_t &message)
{
    RequestMetaDataTypeStateMachine* requestMachine = static_cast<RequestMetaDataTypeStateMachine*>(resultHandlerData);

    if (result == MAV_RESULT_ACCEPTED) {
        mavlink_component_metadata_t componentMetadata;
        mavlink_msg_component_metadata_decode(&message, &componentMetadata);

        qDebug() << "COMPONENT_METADATA accepted"
                 << "compId:" << requestMachine->compInfo()->compId
                 << "uri:" << componentMetadata.uri
                 << "crc:" << componentMetadata.file_crc;

        requestMachine->compInfo()->setUriMetaData(componentMetadata.uri, componentMetadata.file_crc);
    } else {
        qDebug() << "COMPONENT_METADATA rejected"
                 << "compId:" << requestMachine->compInfo()->compId
                 << "result:" << result;
    }

    requestMachine->advance();
}

// static void _requestMessageResultHandler(void* resultHandlerData, MAV_RESULT result,
//     [[maybe_unused]] Vehicle::RequestMessageResultHandlerFailureCode_t failureCode, const mavlink_message_t &message)
// {
//     RequestMetaDataTypeStateMachine* requestMachine = static_cast<RequestMetaDataTypeStateMachine*>(resultHandlerData);

//     if (result == MAV_RESULT_ACCEPTED) {
//         mavlink_component_metadata_t componentMetadata;
//         mavlink_msg_component_metadata_decode(&message, &componentMetadata);
//         requestMachine->compInfo()->setUriMetaData(componentMetadata.uri, componentMetadata.file_crc);
//     } // else: try deprecated COMPONENT_INFORMATION

//     requestMachine->advance();
// }

static void _requestMessageResultHandlerDeprecated(void* resultHandlerData, MAV_RESULT result, Vehicle::RequestMessageResultHandlerFailureCode_t failureCode, const mavlink_message_t &message)
{
    RequestMetaDataTypeStateMachine* requestMachine = static_cast<RequestMetaDataTypeStateMachine*>(resultHandlerData);

    if (result == MAV_RESULT_ACCEPTED) {
        mavlink_component_information_t componentInformation;
        mavlink_msg_component_information_decode(&message, &componentInformation);
        requestMachine->compInfo()->setUriMetaData(componentInformation.general_metadata_uri, componentInformation.general_metadata_file_crc);
    } else {
        switch (failureCode) {
        case Vehicle::RequestMessageFailureCommandError:
            qCDebug(ComponentInformationManagerLog) << QStringLiteral("MAV_CMD_REQUEST_MESSAGE COMPONENT_INFORMATION %1 error(%2)").arg(requestMachine->typeToString()).arg(QGCMAVLink::mavResultToString(result));
            break;
        case Vehicle::RequestMessageFailureCommandNotAcked:
            qCDebug(ComponentInformationManagerLog) << QStringLiteral("MAV_CMD_REQUEST_MESSAGE COMPONENT_INFORMATION %1 no response to command from vehicle").arg(requestMachine->typeToString());
            break;
        case Vehicle::RequestMessageFailureMessageNotReceived:
            qCDebug(ComponentInformationManagerLog) << QStringLiteral("MAV_CMD_REQUEST_MESSAGE COMPONENT_INFORMATION %1 vehicle did not send requested message").arg(requestMachine->typeToString());
            break;
        default:
            break;
        }
    }
    requestMachine->advance();
}

void RequestMetaDataTypeStateMachine::_stateRequestCompInfo(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    Vehicle*                            vehicle         = requestMachine->_compMgr->vehicle();

    if (requestMachine->_compInfo->type != COMP_METADATA_TYPE_GENERAL) {
        requestMachine->advance();
        return;
    }

    SharedLinkInterfacePtr sharedLink = vehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        if (sharedLink->linkConfiguration()->isHighLatency() || sharedLink->isLogReplay()) {
            qCDebug(ComponentInformationManagerLog) << QStringLiteral("_stateRequestCompInfo Skipping component information %1 request due to link type").arg(requestMachine->typeToString());
            stateMachine->advance();
        } else {
            qCDebug(ComponentInformationManagerLog) << "Requesting component metadata" << requestMachine->typeToString();
            qDebug()
    << "Requesting component metadata"
    << "compId:" << requestMachine->_compInfo->compId
    << "type:" << requestMachine->typeToString()
    << "msgId:" << MAVLINK_MSG_ID_COMPONENT_METADATA;
            vehicle->requestMessage(
                        _requestMessageResultHandler,
                        stateMachine,
                        requestMachine->_compInfo->compId,
                        MAVLINK_MSG_ID_COMPONENT_METADATA);
        }
    } else {
        qCDebug(ComponentInformationManagerLog) << QStringLiteral("_stateRequestCompInfo Skipping component information %1 request due to no primary link").arg(requestMachine->typeToString());
        stateMachine->advance();
    }
}

void RequestMetaDataTypeStateMachine::_stateRequestCompInfoDeprecated(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    Vehicle*                            vehicle         = requestMachine->_compMgr->vehicle();

    if (requestMachine->_compInfo->type != COMP_METADATA_TYPE_GENERAL) {
        requestMachine->advance();
        return;
    }
    if (requestMachine->_compInfo->crcMetaDataValid()) {
        qCDebug(ComponentInformationManagerLog) << "COMPONENT_METADATA available, skipping COMPONENT_INFORMATION";
        requestMachine->advance();
        return;
    }

    SharedLinkInterfacePtr sharedLink = vehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        if (sharedLink->linkConfiguration()->isHighLatency() || sharedLink->isLogReplay()) {
            qCDebug(ComponentInformationManagerLog) << QStringLiteral("_stateRequestCompInfo Skipping component information %1 request due to link type").arg(requestMachine->typeToString());
            stateMachine->advance();
        } else {
            qCDebug(ComponentInformationManagerLog) << "Requesting component information" << requestMachine->typeToString();
            qDebug()
                << "Requesting deprecated component information"
                << "compId:" << requestMachine->_compInfo->compId
                << "type:" << requestMachine->typeToString()
                << "msgId:" << MAVLINK_MSG_ID_COMPONENT_INFORMATION;
            vehicle->requestMessage(
                        _requestMessageResultHandlerDeprecated,
                        stateMachine,
                        requestMachine->_compInfo->compId,
                        MAVLINK_MSG_ID_COMPONENT_INFORMATION);
        }
    } else {
        qCDebug(ComponentInformationManagerLog) << QStringLiteral("_stateRequestCompInfo Skipping component information %1 request due to no primary link").arg(requestMachine->typeToString());
        stateMachine->advance();
    }
}

QString RequestMetaDataTypeStateMachine::_downloadCompleteJsonWorker(const QString& fileName)
{
    QString outputFileName = fileName;

    //FPV
    qDebug() << "_downloadCompleteJsonWorker input fileName:" << fileName
             << "cacheTag:" << _currentCacheFileTag
             << "currentFileValidCrc:" << _currentFileValidCrc;

    if (fileName.endsWith(".lzma", Qt::CaseInsensitive) || fileName.endsWith(".xz", Qt::CaseInsensitive)) {
        outputFileName = (QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation)).absoluteFilePath(_currentCacheFileTag));
        qDebug() << "_downloadCompleteJsonWorker inflating to:" << outputFileName;

        if (QGCLZMA::inflateLZMAFile(fileName, outputFileName)) {
            QFile(fileName).remove();
            qDebug() << "_downloadCompleteJsonWorker inflate OK:" << outputFileName;
        } else {
            qWarning() << "_downloadCompleteJsonWorker inflate FAILED"
                       << "input:" << fileName
                       << "output:" << outputFileName;
            outputFileName.clear();
        }
    } else {
        qDebug() << "_downloadCompleteJsonWorker no inflate needed:" << outputFileName;
    }

    if (_currentFileValidCrc && !outputFileName.isEmpty()) {
        const QString originalOutputFileName = outputFileName;
        const QString cachedPath = _compMgr->fileCache().insert(_currentCacheFileTag, outputFileName);

        qDebug() << "_downloadCompleteJsonWorker cache insert"
                << "input:" << originalOutputFileName
                << "cachedPath:" << cachedPath;

        if (!cachedPath.isEmpty()) {
            outputFileName = cachedPath;
        } else {
            qWarning() << "_downloadCompleteJsonWorker cache insert failed, using uncached file:"
                    << originalOutputFileName;
            outputFileName = originalOutputFileName;
        }
    }

    qDebug() << "_downloadCompleteJsonWorker returning:" << outputFileName;
    //FPV
    return outputFileName;
}

void RequestMetaDataTypeStateMachine::_ftpDownloadComplete(const QString& fileName, const QString& errorMsg)
{
    qDebug() << "_ftpDownloadComplete"
             << "compId:" << _compInfo->compId
             << "fileName:" << fileName
             << "errorMsg:" << errorMsg;
    qCDebug(ComponentInformationManagerLog) << "RequestMetaDataTypeStateMachine::_ftpDownloadComplete fileName:errorMsg" << fileName << errorMsg;

    disconnect(_compInfo->vehicle->ftpManager(), &FTPManager::downloadComplete, this, &RequestMetaDataTypeStateMachine::_ftpDownloadComplete);
    disconnect(_compInfo->vehicle->ftpManager(), &FTPManager::commandProgress, this, &RequestMetaDataTypeStateMachine::_ftpDownloadProgress);
    if (errorMsg.isEmpty()) {
        if (_currentFileName) {
            *_currentFileName = _downloadCompleteJsonWorker(fileName);
            qDebug() << "_ftpDownloadComplete assigned current file name:" << *_currentFileName;
        }
    } else if (qgcApp()->runningUnitTests()) {
        // Unit test should always succeed
        qCWarning(ComponentInformationManagerLog) << "RequestMetaDataTypeStateMachine::_ftpDownloadComplete failed filename:errorMsg" << fileName << errorMsg;
    }

    advance();
}

void RequestMetaDataTypeStateMachine::_ftpDownloadProgress(float progress)
{
    int elapsedSec = _downloadStartTime.elapsed() / 1000;
    float totalDownloadTime = elapsedSec / progress;
    // abort download if it's too slow (e.g. over telemetry link) and use the fallback.
    // (we could also check if there's a http fallback)
    const int maxDownloadTimeSec = 40;
    if (elapsedSec > 10 && progress < 0.5 && totalDownloadTime > maxDownloadTimeSec) {
        qCDebug(ComponentInformationManagerLog) << "Slow download, aborting. Total time (s):" << totalDownloadTime;
        _compInfo->vehicle->ftpManager()->cancelDownload();
    }
}

void RequestMetaDataTypeStateMachine::_httpDownloadComplete(QString remoteFile, QString localFile, QString errorMsg)
{

    qDebug() << "_httpDownloadComplete"
             << "compId:" << _compInfo->compId
             << "remoteFile:" << remoteFile
             << "localFile:" << localFile
             << "errorMsg:" << errorMsg;
    qCDebug(ComponentInformationManagerLog) << "RequestMetaDataTypeStateMachine::_httpDownloadComplete remoteFile:localFile:errorMsg" << remoteFile << localFile << errorMsg;

    disconnect(qobject_cast<QGCCachedFileDownload*>(sender()), &QGCCachedFileDownload::downloadComplete, this, &RequestMetaDataTypeStateMachine::_httpDownloadComplete);
    if (errorMsg.isEmpty()) {
        if (_currentFileName) {
            *_currentFileName = _downloadCompleteJsonWorker(localFile);
        }
    } else if (qgcApp()->runningUnitTests()) {
        // Unit test should always succeed
        qCWarning(ComponentInformationManagerLog) << "RequestMetaDataTypeStateMachine::_httpDownloadCompleteMetaDataJson failed remoteFile:localFile:errorMsg" << remoteFile << localFile << errorMsg;
    }

    advance();
}

void RequestMetaDataTypeStateMachine::_requestFile(const QString& cacheFileTag, bool crcValid, const QString& uri, QString& outputFileName)
{
    //FPV
    qDebug() << "_requestFile"
             << "compId" << _compInfo->compId
             << "available" << _compInfo->available()
             << "uri" << uri
             << "cacheTag" << cacheFileTag
             << "crcValid" << crcValid;

    FTPManager* ftpManager = _compInfo->vehicle->ftpManager();
    _currentCacheFileTag = cacheFileTag;
    _currentFileName = &outputFileName;
    _currentFileValidCrc = crcValid;
    outputFileName.clear();

    if (_compInfo->available() && !uri.isEmpty()) {
        const QString cachedFile = crcValid ? _compMgr->fileCache().access(cacheFileTag) : "";

        qDebug() << "_requestFile cachedFile =" << cachedFile;

        if (cachedFile.isEmpty()) {
            qDebug() << "Downloading json" << uri;

            if (_uriIsMAVLinkFTP(uri)) {
                connect(ftpManager, &FTPManager::downloadComplete,
                        this, &RequestMetaDataTypeStateMachine::_ftpDownloadComplete);

                QString ftpPath = uri;
                ftpPath.remove(QStringLiteral("mftp://"));
                if (ftpPath.startsWith(QStringLiteral("///"))) {
                    ftpPath.remove(0, 2);
                }

                qDebug() << "Normalized FTP path:" << ftpPath;

                if (ftpManager->download(_compInfo->compId,
                                         ftpPath,
                                         QStandardPaths::writableLocation(QStandardPaths::TempLocation))) {
                    _downloadStartTime.start();
                    connect(ftpManager, &FTPManager::commandProgress,
                            this, &RequestMetaDataTypeStateMachine::_ftpDownloadProgress);
                } else {
                    qDebug() << "RequestMetaDataTypeStateMachine::_requestFile FTPManager::download returned failure";
                    disconnect(ftpManager, &FTPManager::downloadComplete,
                               this, &RequestMetaDataTypeStateMachine::_ftpDownloadComplete);
                    advance();
                }
            } else {
                connect(_compMgr->_cachedFileDownload, &QGCCachedFileDownload::downloadComplete,
                        this, &RequestMetaDataTypeStateMachine::_httpDownloadComplete);

                if (_compMgr->_cachedFileDownload->download(uri, crcValid ? 0 : ComponentInformationManager::cachedFileMaxAgeSec)) {
                    _downloadStartTime.start();
                } else {
                    qDebug() << "RequestMetaDataTypeStateMachine::_requestFile QGCCachedFileDownload::download returned failure";
                    disconnect(_compMgr->_cachedFileDownload, &QGCCachedFileDownload::downloadComplete,
                               this, &RequestMetaDataTypeStateMachine::_httpDownloadComplete);
                    advance();
                }
            }
        } else {
            qDebug() << "Using cached file" << cachedFile;
            outputFileName = cachedFile;
            advance();
        }
    } else {
        qDebug() << "Skipping download. Component information not available for" << _currentCacheFileTag;
        advance();
    }
    //FPV
}

void RequestMetaDataTypeStateMachine::_stateRequestMetaDataJson(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    CompInfo*                           compInfo        = requestMachine->compInfo();
    const QString                       fileTag         = ComponentInformationManager::_getFileCacheTag(
            compInfo->type, compInfo->crcMetaData(), false);
    const QString                       uri             = compInfo->uriMetaData();

    qDebug() << "_stateRequestMetaDataJson"
             << "compId:" << compInfo->compId
             << "available:" << compInfo->available()
             << "uri:" << compInfo->uriMetaData()
             << "crcValid:" << compInfo->crcMetaDataValid()
             << "crc:" << compInfo->crcMetaData();

    requestMachine->_jsonMetadataCrcValid = compInfo->crcMetaDataValid();
    requestMachine->_requestFile(fileTag, compInfo->crcMetaDataValid(), uri, requestMachine->_jsonMetadataFileName);
}

// void RequestMetaDataTypeStateMachine::_stateRequestMetaDataJson(StateMachine* stateMachine)
// {
//     RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
//     CompInfo*                           compInfo        = requestMachine->compInfo();
//     const QString                       fileTag         = ComponentInformationManager::_getFileCacheTag(
//             compInfo->type, compInfo->crcMetaData(), false);
//     const QString                       uri             = compInfo->uriMetaData();
//     requestMachine->_jsonMetadataCrcValid               = compInfo->crcMetaDataValid();
//     requestMachine->_requestFile(fileTag, compInfo->crcMetaDataValid(), uri, requestMachine->_jsonMetadataFileName);
// }

void RequestMetaDataTypeStateMachine::_stateRequestMetaDataJsonFallback(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    if (!requestMachine->_jsonMetadataFileName.isEmpty()) {
        requestMachine->advance();
        return;
    }
    qCDebug(ComponentInformationManagerLog) << "RequestMetaDataTypeStateMachine::_stateRequestMetaDataJsonFallback: trying fallback download";

    CompInfo*                           compInfo        = requestMachine->compInfo();
    const QString                       fileTag         = ComponentInformationManager::_getFileCacheTag(
            compInfo->type, compInfo->crcMetaDataFallback(), false);
    const QString                       uri             = compInfo->uriMetaDataFallback();
    requestMachine->_jsonMetadataCrcValid               = compInfo->crcMetaDataFallbackValid();
    requestMachine->_requestFile(fileTag, compInfo->crcMetaDataFallbackValid(), uri, requestMachine->_jsonMetadataFileName);
}

void RequestMetaDataTypeStateMachine::_stateRequestTranslationJson(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    CompInfo*                           compInfo        = requestMachine->compInfo();
    const QString                       uri             = compInfo->uriTranslation();
    requestMachine->_requestFile("", false, uri, requestMachine->_jsonTranslationFileName);
}

void RequestMetaDataTypeStateMachine::_stateRequestTranslate(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine*    requestMachine  = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    requestMachine->_jsonMetadataTranslatedFileName = "";
    if (requestMachine->_jsonTranslationFileName.isEmpty()) {
        requestMachine->advance();
    } else {
        connect(requestMachine->_compMgr->translation(), &ComponentInformationTranslation::downloadComplete,
                requestMachine, &RequestMetaDataTypeStateMachine::_downloadAndTranslationComplete);
        if (!requestMachine->_compMgr->translation()->downloadAndTranslate(requestMachine->_jsonTranslationFileName,
                                                                           requestMachine->_jsonMetadataFileName,
                                                                           ComponentInformationManager::cachedFileMaxAgeSec)) {
            disconnect(requestMachine->_compMgr->translation(), &ComponentInformationTranslation::downloadComplete,
                       requestMachine, &RequestMetaDataTypeStateMachine::_downloadAndTranslationComplete);
            qCDebug(ComponentInformationManagerLog) << "downloadAndTranslate() failed";
            requestMachine->advance();
        }
    }
}

void RequestMetaDataTypeStateMachine::_downloadAndTranslationComplete(QString translatedJsonTempFile, QString errorMsg)
{
    disconnect(_compMgr->translation(), &ComponentInformationTranslation::downloadComplete,
               this, &RequestMetaDataTypeStateMachine::_downloadAndTranslationComplete);
    _jsonMetadataTranslatedFileName = translatedJsonTempFile;
    if (!errorMsg.isEmpty()) {
        qCWarning(ComponentInformationManagerLog) << "Metadata translation failed:" << errorMsg;
    }
    advance();
}

void RequestMetaDataTypeStateMachine::_stateRequestComplete(StateMachine* stateMachine)
{
    RequestMetaDataTypeStateMachine* requestMachine = static_cast<RequestMetaDataTypeStateMachine*>(stateMachine);
    CompInfo* compInfo = requestMachine->compInfo();
    //FPV
    qDebug() << "_stateRequestComplete"
             << "jsonMetadataFileName" << requestMachine->_jsonMetadataFileName
             << "jsonMetadataTranslatedFileName" << requestMachine->_jsonMetadataTranslatedFileName;

    QString jsonFile;
    const bool usingTranslatedFile = !requestMachine->_jsonMetadataTranslatedFileName.isEmpty();

    if (usingTranslatedFile) {
        jsonFile = requestMachine->_jsonMetadataTranslatedFileName;
    } else {
        jsonFile = requestMachine->_jsonMetadataFileName;
    }

    // Let the normal QGC parser run first
    compInfo->setJson(jsonFile);

    if (!jsonFile.isEmpty()) {
        QFile file(jsonFile);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray jsonData = file.readAll();
            file.close();

            qDebug() << "----- COMPONENT METADATA JSON BEGIN -----";
            qDebug().noquote() << jsonData;
            qDebug() << "----- COMPONENT METADATA JSON END -----";

            QJsonParseError parseError;
            const QJsonDocument doc = QJsonDocument::fromJson(jsonData, &parseError);

            if (parseError.error == QJsonParseError::NoError && doc.isObject()) {
                const QJsonObject obj = doc.object();

                const QString modelName = obj.value(QStringLiteral("modelName")).toString();
                const QString vendorName = obj.value(QStringLiteral("vendorName")).toString();
                const QString softwareVersion = obj.value(QStringLiteral("softwareVersion")).toString();

                qDebug() << "Parsed metadata"
                         << "compId:" << compInfo->compId
                         << "vendorName:" << vendorName
                         << "modelName:" << modelName
                         << "softwareVersion:" << softwareVersion;

                // Only use your custom component metadata for auto-layout detection
                if (compInfo->compId == VEHICLE_IDENTIFICATION && !modelName.isEmpty()) {
                    compInfo->vehicle->setComponentModelName(modelName);

                    qDebug() << "Vehicle componentModelName updated from metadata:"
                             << modelName
                             << "isAVFPV:"
                             << (modelName == QStringLiteral("AV_FPV"));
                }
            } else {
                qWarning() << "Failed to parse metadata JSON for compId"
                           << compInfo->compId
                           << ":"
                           << parseError.errorString();
            }
        } else {
            qWarning() << "Failed to open metadata JSON:" << jsonFile;
        }
    }

    if (usingTranslatedFile && !requestMachine->_jsonMetadataTranslatedFileName.isEmpty()) {
        QFile(requestMachine->_jsonMetadataTranslatedFileName).remove();
    }
    //FPV

    if (!requestMachine->_jsonMetadataCrcValid && !requestMachine->_jsonMetadataFileName.isEmpty()) {
        QFile(requestMachine->_jsonMetadataFileName).remove();
    }
    if (!requestMachine->_jsonMetadataCrcValid && !requestMachine->_jsonTranslationFileName.isEmpty()) {
        QFile(requestMachine->_jsonTranslationFileName).remove();
    }

    requestMachine->advance();
}

bool RequestMetaDataTypeStateMachine::_uriIsMAVLinkFTP(const QString& uri)
{
    return uri.startsWith(QStringLiteral("%1://").arg(FTPManager::mavlinkFTPScheme), Qt::CaseInsensitive);
}

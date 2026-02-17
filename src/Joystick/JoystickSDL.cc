/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "JoystickSDL.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QFile>
#include <QtCore/QIODevice>
#include <QtCore/QTextStream>

#include <SDL.h>

QGC_LOGGING_CATEGORY(JoystickSDLLog, "qgc.joystick.joysticksdl")

static bool _isT20Name(const QString& n)
{
    return n.contains("T20", Qt::CaseInsensitive);
}

JoystickSDL::JoystickSDL(const QString &name, int axisCount, int buttonCount, int hatCount, int index, bool isGameController, QObject *parent)
    : Joystick(name, axisCount, buttonCount, hatCount, parent)
    , _isGameController(isGameController)
    , _index(index)
{
    // qCDebug(JoystickSDLLog) << Q_FUNC_INFO << this;

    if (_isGameController) {
        _setDefaultCalibration();
    }
}

JoystickSDL::~JoystickSDL()
{
    // qCDebug(JoystickSDLLog) << Q_FUNC_INFO << this;
}

bool JoystickSDL::init()
{
    SDL_SetMainReady();
    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK) < 0) {
        (void) SDL_JoystickEventState(SDL_DISABLE);
        qCWarning(JoystickSDLLog) << "Failed to initialize SDL:" << SDL_GetError();
        return false;
    }

    _loadGameControllerMappings();
    return true;
}

QMap<QString, Joystick*> JoystickSDL::discover()
{
    static QMap<QString, Joystick*> ret;

    QMap<QString, Joystick*> newRet;

    qCDebug(JoystickSDLLog) << "Discovering joysticks";

    for (int i = 0; i < SDL_NumJoysticks(); i++) {
        QString name = SDL_JoystickNameForIndex(i);
        if (ret.contains(name)) {
            newRet[name] = ret[name];
            JoystickSDL *const joystick = static_cast<JoystickSDL*>(newRet[name]);
            if (joystick->index() != i) {
                joystick->setIndex(i); // This joystick index has been remapped by SDL
            }

            // Anything left in ret after we exit the loop has been removed (unplugged) and needs to be cleaned up.
            // We will handle that in JoystickManager in case the removed joystick was in use.
            (void) ret.remove(name);

            qCDebug(JoystickSDLLog) << "Skipping duplicate" << name;
            continue;
        }

        SDL_Joystick *const sdlJoystick = SDL_JoystickOpen(i);
        if (!sdlJoystick) {
            qCWarning(JoystickSDLLog) << "SDL failed opening joystick" << qPrintable(name) << "error:" << SDL_GetError();
            continue;
        }

        SDL_ClearError();
        const int axisCount = SDL_JoystickNumAxes(sdlJoystick);
        const int buttonCount = SDL_JoystickNumButtons(sdlJoystick);
        const int hatCount = SDL_JoystickNumHats(sdlJoystick);
        if ((axisCount < 0) || (buttonCount < 0) || (hatCount < 0)) {
            qCWarning(JoystickSDLLog) << "SDL error parsing joystick features:" << SDL_GetError();
        }
        SDL_JoystickClose(sdlJoystick);

        bool isGameController = SDL_IsGameController(i);
        if (_isT20Name(name)) {
            isGameController = false;
        }

        // const bool isGameController = SDL_IsGameController(i);
        qCDebug(JoystickSDLLog) << name << "axes:" << axisCount << "buttons:" << buttonCount << "hats:" << hatCount << "isGC:" << isGameController;

        // Check for joysticks with duplicate names and differentiate the keys when necessary.
        // This is required when using an Xbox 360 wireless receiver that always identifies as
        // 4 individual joysticks, regardless of how many joysticks are actually connected to the
        // receiver. Using GUID does not help, all of these devices present the same GUID.
        const QString originalName = name;
        uint8_t duplicateIdx = 1;
        while (newRet[name]) {
            name = QString("%1 %2").arg(originalName).arg(duplicateIdx++);
        }

        newRet[name] = new JoystickSDL(name, qMax(0, axisCount), qMax(0, buttonCount), qMax(0, hatCount), i, isGameController);
    }

    if (newRet.isEmpty()) {
        qCDebug(JoystickSDLLog) << "None found";
    }

    ret = newRet;
    return ret;
}

bool JoystickSDL::_open()
{
    if (_isGameController) {
        _sdlController = SDL_GameControllerOpen(_index);
        _sdlJoystick = SDL_GameControllerGetJoystick(_sdlController);
    } else {
        _sdlJoystick = SDL_JoystickOpen(_index);
    }

    if (!_sdlJoystick) {
        qCWarning(JoystickSDLLog) << "SDL_JoystickOpen failed:" << SDL_GetError();
        return false;
    }

    qCDebug(JoystickSDLLog) << "Opened" << SDL_JoystickName(_sdlJoystick) << "joystick at" << _sdlJoystick;

    if (!_isGameController) {
        _detectAndSetupAxisMapping();
    }

    const SDL_JoystickGUID guid = SDL_JoystickGetGUID(_sdlJoystick);
    char guidStr[33] = {};
    SDL_JoystickGetGUIDString(guid, guidStr, sizeof(guidStr));
    qCInfo(JoystickSDLLog) << "Joystick GUID:" << guidStr;

    return true;
}

void JoystickSDL::_close()
{
    if (!_sdlJoystick) {
        qCWarning(JoystickSDLLog) << "Attempt to close null joystick!";
        return;
    }

    qCDebug(JoystickSDLLog) << "Closing" << SDL_JoystickName(_sdlJoystick) << "joystick at" << _sdlJoystick;

    if (_isGameController) {
        SDL_GameControllerClose(_sdlController);
    } else {
        SDL_JoystickClose(_sdlJoystick);
    }

    _sdlJoystick = nullptr;
    _sdlController = nullptr;

    _useAxisMap = false;
}

bool JoystickSDL::_update()
{
    if (_isGameController) {
        SDL_GameControllerUpdate();
    } else {
        SDL_JoystickUpdate();
    }

    return true;
}

bool JoystickSDL::_getButton(int i) const
{
    if (!_sdlJoystick || i < 0) {
        return false;
    }

    const int rawCount = SDL_JoystickNumButtons(_sdlJoystick);
    if (i >= rawCount) {
        return false;
    }

    return SDL_JoystickGetButton(_sdlJoystick, i) != 0;
}

int JoystickSDL::_getAxis(int i) const
{
    if (!_sdlJoystick || i < 0) {
        return 0;
    }

    if (_isGameController) {
        return SDL_GameControllerGetAxis(_sdlController, SDL_GameControllerAxis(i));
    }

    const int readIndex = _mapAxisIndex(i);

    const int rawCount = SDL_JoystickNumAxes(_sdlJoystick);
    if (readIndex < 0 || readIndex >= rawCount) {
        return 0;
    }

    return SDL_JoystickGetAxis(_sdlJoystick, readIndex);
}

void JoystickSDL::_detectAndSetupAxisMapping()
{
    _useAxisMap = false;

    _axisMap.fill(-1);
    for (int i = 0; i < _axisCount && i < static_cast<int>(_axisMap.size()); i++) {
        _axisMap[i] = i;
    }

    // Only apply to T20
    if (!_sdlJoystick) {
        return;
    }

    const QString devName = QString::fromUtf8(SDL_JoystickName(_sdlJoystick));
    if (!_isT20Name(devName)) {
        return;
    }

    const int rawAxes = SDL_JoystickNumAxes(_sdlJoystick);
    if (rawAxes > 4 && _axisMap.size() > 4) {
        _axisMap[3] = 4;
        _axisMap[4] = 3;
        _useAxisMap = true;

        qCInfo(JoystickSDLLog) << "T20 axis swap enabled (logical 3<->4)"
                                 << "dev:" << devName
                                 << "axisCount:" << _axisCount
                                 << "rawAxes:" << rawAxes;
    } else {
        qCWarning(JoystickSDLLog) << "T20 detected but not enough axes to swap 3<->4"
                                 << "dev:" << devName
                                 << "axisCount:" << _axisCount
                                 << "rawAxes:" << rawAxes;
    }
}

int JoystickSDL::_mapAxisIndex(int logicalAxis) const
{
    if (!_useAxisMap) {
        return logicalAxis;
    }
    if (logicalAxis < 0 || logicalAxis >= static_cast<int>(_axisMap.size())) {
        return logicalAxis;
    }
    const int mapped = _axisMap[logicalAxis];
    return mapped >= 0 ? mapped : logicalAxis;
}

bool JoystickSDL::_getHat(int hat, int i) const
{
    static constexpr uint8_t hatButtons[] = {SDL_HAT_UP, SDL_HAT_DOWN, SDL_HAT_LEFT, SDL_HAT_RIGHT};

    if (i >= std::size(hatButtons)) {
        return false;
    }

    return ((SDL_JoystickGetHat(_sdlJoystick, hat) & hatButtons[i]) != 0);
}

void JoystickSDL::_loadGameControllerMappings()
{
    QFile file(QStringLiteral(":/gamecontrollerdb.txt"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(JoystickSDLLog) << "Couldn't load GameController mapping database.";
        return;
    }

    QTextStream stream(&file);
    while (!stream.atEnd()) {
        const QString line = stream.readLine();
        if (line.startsWith('#') || line.isEmpty()) {
            continue;
        }
        if (SDL_GameControllerAddMapping(line.toStdString().c_str()) == -1) {
            qCWarning(JoystickSDLLog) << "Couldn't add GameController mapping:" << SDL_GetError();
        }
    }

    if (qEnvironmentVariableIsSet("SDL_GAMECONTROLLERCONFIG")) {
        const QString mappingsStr = qEnvironmentVariable("SDL_GAMECONTROLLERCONFIG");
        const QStringList mappingList = mappingsStr.split("\n", Qt::SkipEmptyParts);
        for (const QString &mapping : mappingList) {
            if (SDL_GameControllerAddMapping(qPrintable(mapping)) == -1) {
                qCWarning(JoystickSDLLog) << "Couldn't add GameController mapping:" << mapping << "Error:" << SDL_GetError();
            }
        }
    }
}

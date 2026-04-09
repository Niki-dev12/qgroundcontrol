# FPV and Stribog Compatibility Matrix

This page documents the feature delta between the upstream `master` branch and the merged FPV/Stribog `devel` branch.
It is based on the branch diff `master..devel`, and intentionally ignores unrelated local worktree edits.

## Scope

Compared with upstream QGroundControl on `master`, the merged branch adds an FPV-oriented operator workflow, custom video overlays, FPV action commands, terrain-aware AGL instrumentation, camera FOV integration, adaptive gimbal behavior, extra joystick actions, and custom Stribog build/version packaging.

For the matrix below:

- `FPV` means the AV FPV workflow, including the FPV-only side strips and FPV command set.
- `Stribog` means the merged application when used without the AV FPV-specific automatic layout path.
- `Required drone app/component` refers to the onboard service that must exist for the feature to work in practice.

## Usage labels

- `Yes`: Fully available and directly usable in that workflow.
- `Partial`: Present in that workflow, but with reduced behavior, narrower activation conditions, or missing some integration compared with the primary workflow.
- `Limited`: Technically available only in a constrained or dependency-heavy way, so it is not a first-class part of that workflow.
- `No by default`: Not shown or enabled in the normal workflow unless the operator explicitly forces it or changes configuration.
- `Platform-specific`: Applies only on matching hardware or controller conditions.

## Matrix

| Feature area | Added vs upstream `master` | FPV use | Stribog use | Required drone app/component | Limitations |
| --- | --- | --- | --- | --- | --- |
| UI layout selection | Added application setting for `Normal`, `Auto`, and `FPV` layouts. | Yes | Partial | None | The setting text describes `Default, Stribog, or FPV`, but the actual enum is `Normal, Auto, FPV`. `Auto` currently switches only when the detected vehicle model name is exactly `AV_FPV`. |
| FPV fly-view side strips | Added left/right vertical action strips around the video-centric fly view. | Yes | No by default | FPV control component `191` for command handling | Visible only when FPV layout is active. Stribog is not auto-detected as a separate layout in current code. |
| Fullscreen hotkey | Added fullscreen toggle on `F11`. | Yes | Yes | None | No limitation. |
| Custom video HUD overlay | Added `CustomHudOverlay.qml` with heading, pitch/roll, altitude, speed, compass, telemetry and gimbal cues. | Yes | Yes | Normal vehicle telemetry; video feed | Useful anywhere video is present, but operationally. Overlay quality depends on valid heading, attitude, speed and altitude telemetry. |
| HUD visibility control | Added HUD toggle from fly view and joystick actions, with backend state tracking. | Yes | Partial | FPV control component `191` | The toggle sends custom command `31059`. Without the FPV control service, the UI toggle has no effect on the vehicle-side workflow. |
| Click-to-designate target | Added single-click designation on the live video stream. | Yes | Limited | FPV vision component `100` (`av-fpv-vision`) | Sent as `MAV_CMD_USER_3` to component `100`. If that component is absent, nothing consumes the designation. |
| Drag-to-select target box | Added drag box targeting on live FPV video. | Yes | Limited | FPV vision component `100`; optionally camera tracking support | The branch sends the normalized box to component `100`. Standard camera tracking commands are also still present, so behavior depends on which onboard service is available. |
| Track / Engage / Cancel | Added dedicated FPV commands and UI buttons. | Yes | No by default | FPV control component `191` | Uses custom MAV_CMD values `31050` to `31052`; not part of upstream generic QGC behavior. |
| Tracker type / Select mode | Added toggle controls and joystick bindings. | Yes | No by default | FPV control component `191` | Uses custom MAV_CMD values `31053` and `31054`. The implementation only toggles two states. |
| AI Strike / Visual Nav / Auto Rec / Dataset Acq | Added FPV side-strip actions. | Yes | No by default | FPV control component `191` | These are custom commands `31055` to `31058`. Only `AI Strike` has explicit local state tracking; the others depend on the onboard implementation. |
| AGL instrument | Added `AGL` as a selectable fly-view instrument panel. | Yes | Yes | No special drone app; normal position/altitude telemetry | Falls back to relative altitude when terrain-under-vehicle data is unavailable. |
| Terrain-ahead profile and risk coloring | Added terrain-ahead sampling, under-vehicle clearance, and warning colors. | Yes | Yes | No special drone app; terrain source plus valid vehicle telemetry | Warning quality depends on terrain data availability, heading, and AMSL/relative altitude accuracy. |
| Camera FOV status support | Added `CAMERA_FOV_STATUS` handling and current HFOV/VFOV tracking. | Yes | Yes | Camera service publishing `CAMERA_FOV_STATUS` | If the camera does not publish FOV status, QGC falls back to configured FOV values. |
| Aspect-ratio-aware FOV | Added VFOV, derived from camera aspect ratio, and per-camera aspect tracking. | Yes | Yes | Camera information with usable aspect metadata | If camera aspect data is missing, the code falls back to `9:16`. |
| Multi-camera FOV sync into payload control | Added syncing of the selected camera FOV into gimbal settings and zoom-derived speed. | Yes | Yes | Camera service with FOV and, ideally, zoom telemetry | Best results require both current camera selection and zoom/FOV properties. |
| Click-to-point gimbal using live FOV | Replaced static-angle assumptions with FOV-based angular mapping. | Yes | Yes | Gimbal plus camera FOV data | If live FOV is missing, the behavior falls back to configured HFOV/VFOV values. |
| Zoom-adaptive gimbal speed | Added `zoomMinSpeed`, `zoomMaxSpeed`, and computed `gimbalSpeed`. | Yes | Yes | Camera zoom telemetry for full benefit | Without zoom telemetry, speed falls back to the configured max-speed side of the range. |
| FPV joystick button actions | Added joystick actions for HUD, track, engage, cancel, tracker type, AI strike and select mode. | Yes | Partial | FPV control component `191` | The bindings exist in QGC, but they only matter if the onboard FPV control app understands the custom commands. |
| Dynamic joystick gimbal rate control | Added adaptive gimbal speed use in joystick/on-screen control flow. | Yes | Yes | Gimbal service; camera zoom telemetry recommended | If zoom information is absent, adaptive scaling degrades to configured defaults. |
| T20-specific controller handling | Added T20 name detection, SDL controller treatment, and axis remapping safeguards. | Platform-specific | Platform-specific | None on the drone | Only applies when the detected joystick name matches `T20`. |
| Stribog build/version naming | Added custom version string based on `av3_1_2-<short git hash>` and packaging script changes. | Yes | Yes | None | This changes packaging/output identity, not in-flight behavior. |

## Required onboard apps/components

| Onboard app/component | Used by | Notes |
| --- | --- | --- |
| FPV control component `191` | FPV side-strip commands, HUD toggle, track/engage/cancel, tracker type, select mode, AI strike, visual nav, auto rec, dataset acquisition | This is the main dependency for the FPV-specific operator workflow. |
| FPV vision camera component `100` | Click target designation and drag-box designation | The code comment identifies this as `av-fpv-vision`. |
| Standard MAVLink camera service | Camera tracking, `CAMERA_FOV_STATUS`, active camera selection, zoom/FOV sync | Required for the generic tracking/FOV/gimbal improvements. |
| Standard MAVLink gimbal service | Click-to-point and rate-based gimbal control | Needed for the gimbal improvements to have effect. |

## Notes for FPV vs Stribog

- FPV gets the full specialized workflow when FPV layout is forced, or when `uiLayout=Auto` and the detected model name is `AV_FPV`.
- Stribog inherits the shared improvements such as terrain/AGL, FOV handling, adaptive gimbal behavior, and packaging changes.
- Stribog does not currently have its own detected layout path in code, so the dedicated FPV side strips are not automatically presented for Stribog vehicles.

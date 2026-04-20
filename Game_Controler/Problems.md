# Project Problems: Game_Controler (Flutter)

This document outlines technical issues, architectural weaknesses, and potential improvements identified during analysis.

## 1. Massive Code Duplication (FIXED)
- **Status**: Fixed by centralizing socket and communication logic in `GamepadProvider`.
- **Socket & Communication Logic**: `GamepadPage`, `Playstation_Controller`, `Xbox_Controller`, and `CustomController` now use the centralized provider.

## 2. Protocol Inconsistency (FIXED)
- **Status**: Fixed by standardizing on the binary protocol across all layouts and the backend.
- **Binary Everywhere**: All layouts now use the binary protocol with batching support.
- **Batching**: High-frequency joystick updates are now consistently batched in all layouts via `GamepadProvider`.

## 3. Configuration & Hardcoding
- **Hardcoded Port**: Port `8080` is still hardcoded in some places (now centralized in `GamepadProvider`, but should be a user setting).
- **Inconsistent Deadzones**: (Partially Fixed) Deadzone logic is now centralized in `GamepadProvider`.


## 4. Error Handling & Feedback
- **Silent Failures**: Socket initialization errors in `_initSocket` are often caught and ignored or just printed to the console. The user stays on a "Connecting..." screen indefinitely if the server is unreachable.
- **No Heartbeat/Timeout**: The app doesn't seem to detect if the server has stopped responding after the initial connection.

## 5. UI/Lifecycle Management
- **Orientation Handling**: Screen orientation is forced to landscape in `initState` and reset in `dispose`, but the reset values often include landscape as well, which might cause unexpected behavior when returning to the `StartPage`.
- **Redundant State**: `_pressedButtons` is managed manually in every controller layout to handle UI feedback.

## 6. Resource Management
- **Asset Declarations**: Several images in `assets/` (e.g., `Icon_save.png`) are not explicitly declared in `pubspec.yaml`, which may lead to runtime errors when trying to load them.
- **Dependency Versioning**: Some dependencies use `^` which might introduce breaking changes if not locked properly via `pubspec.lock`.

## 7. Features
- **Gyro Steering**: Only implemented in some layouts.
- **Haptic Feedback**: Inconsistently implemented or manually triggered in every button press handler instead of being centralized.

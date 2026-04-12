# Gemini Project Context: Cheaptroller (Game_Controler)

This project is a Flutter-based mobile application that transforms a smartphone into a versatile game controller for a PC. It communicates with a server application on the PC using UDP.

## Project Overview

- **Main Goal:** provide a low-latency, customizable game controller experience using mobile hardware (touchscreen, sensors).
- **Architecture:**
  - **Core Logic:** Uses `Provider` for state management and `SettingsProvider` for persistent user preferences.
  - **Communication Layer:** Employs UDP (`RawDatagramSocket`) on port `8080` to send real-time input data (joystick moves, button presses) to the server.
  - **UI Components:** Modular elements located in `lib/Elements/` (Joysticks, DPads, Buttons) are reused across different controller layouts.
  - **Controller Layouts:** Specific implementations for PlayStation, Xbox, and Custom controllers in `lib/Controller_Layouts/`.
- **Key Technologies:**
  - **Framework:** Flutter (Dart)
  - **Communication:** `dart:io` (UDP), `web_socket_channel` (though UDP is currently preferred for latency).
  - **Sensors:** `sensors_plus` for gyro-based steering.
  - **Haptics:** `vibration` for tactile feedback on button presses.
  - **Scanning:** `qr_code_scanner_plus` for easy connection to the server.

## Building and Running

### Prerequisites

- Flutter SDK (>=3.3.0 <4.0.0)
- Android Studio / Xcode (for mobile deployment)

### Key Commands

- **Install Dependencies:** `flutter pub get`
- **Run the App:** `flutter run`
- **Build Android APK:** `flutter build apk`
- **Generate Launcher Icons:** `dart run flutter_launcher_icons`

## Development Conventions

### Communication Protocol (UDP)

Inputs are sent as JSON-encoded strings over UDP to the configured IP on port `8080`.

- **Joystick Move:** `{"type": "move", "side": "left"|"right", "x": double, "y": double, "timestamp": int}`
- **Button Press:** `{"type": "button_down"|"button_up", "side": "left"|"right", "index": int, "timestamp": int}`

### Project Structure

- `lib/main.dart`: Entry point, routing, and global providers.
- `lib/Controller_Layouts/`: Individual controller UI and logic.
- `lib/Elements/`: Reusable UI primitives (DPad, Joystick, etc.).
- `lib/Settings/`: `SettingsProvider` for managing IP, theme, and haptics.
- `lib/Models/`: Data models for custom layouts.

### Coding Style

- Follows standard Flutter/Dart linting rules (configured in `analysis_options.yaml`).
- Uses `Provider` for reactive state management.
- Prefer surgical updates to UI elements to maintain performance during high-frequency input.

## TODOs / Roadmap

- [ ] Implement "WASD to Left Click" and "MouseMove to Right Click" logic.
- [x] Improve UI layout for better ergonomics.
- [ ] Enhance IP address input (e.g., auto-discovery or better validation).

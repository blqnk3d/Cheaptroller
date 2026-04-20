# Project Problems: Backend_controler

This document outlines technical issues, architectural weaknesses, and potential improvements identified during analysis.

## 1. Platform & Compatibility
- **Linux Exclusive Gamepad Support**: The `gamepad.cpp` addon uses the Linux `uinput` kernel module. The project is currently non-functional on Windows or macOS for gamepad emulation.
- **Permissions**: Direct access to `/dev/uinput` requires `root` privileges or specific `udev` rules, which are not documented or handled gracefully.

## 2. Security & Networking
- **No Authentication**: The UDP server and Web API are completely open. Anyone on the local network can control the virtual gamepads, change the server configuration, or shut down the process via `/api/shutdown`.
- **IP/Port Client Identification**: Clients are identified solely by their IP and source port (`${rinfo.address}:${rinfo.port}`). If a mobile device switches ports (common in UDP), it creates a new virtual controller, leaving the old one to timeout. A unique device ID should be used instead.
- **Lack of Input Validation**: UDP messages are parsed but not deeply validated before being passed to the C++ addon.

## 3. Reliability & Error Handling
- **C++ Addon Robustness**: `write` calls to the `uinput` file descriptor are not checked for success. Error handling in the addon is minimal.
- **Protocol Redundancy (FIXED)**: Standardized on a single custom binary protocol. JSON support for UDP has been removed to reduce complexity and overhead.


## 4. UI/UX (Admin Dashboard)
- **Static Assets**: Some assets might be missing or not served correctly if the `public/` folder is not in the expected location relative to the binary (when using `pkg`).
- **mDNS Visibility**: While the server advertises via Bonjour, there's no way for the server to "push" its IP to a client that isn't already listening.

## 5. Deployment
- **Dockerization**: The `Dockerfile` exists but relies on build-time tools for the C++ addon. If the host architecture doesn't match the container, issues may arise.

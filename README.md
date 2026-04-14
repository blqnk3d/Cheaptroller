# Cheaptroller

Cheaptroller is a **lightweight controller application** that transforms your mobile device into a versatile PC game controller. It eliminates the need for extra hardware by connecting your phone to a small, local **Node.js server** that bridges the mobile inputs to your PC using a custom **C++ library for input simulation**.

The project's goal is simple: provide an easy, zero-cost way to control PC games using a device you already own.

The **Cheaptroller** app is currently confirmed to be functional and tested only on **Linux systems** because its core C++ input simulation library is Linux-specific, and there is **no support** for **Windows or macOS** at this time.

## Table of Contents

1.  [Key Features](#1-key-features)
2.  [Installation & Setup](#2-installation--setup)
3.  [Screenshots and User Interface (UI)](#3-screenshots-and-user-interface-ui)
4.  [Technologies](#4-technologies)
5.  [Usage & Controls](#5-usage--controls)
6.  [Troubleshooting](#6-troubleshooting)
7.  [Roadmap / To-Do](#7-roadmap--to-do)
8.  [License](#8-license)
9.  [Acknowledgements / Credits](#9-acknowledgements--credits)

## 1. Key Features

- **Standard Layouts:** Choose between **PlayStation** and **Xbox** controller layouts.
- **Easy Connection:** Quickly connect the mobile app to the server using a **QR Code**.
- **True Simulation:** The app acts as a **real controller**, ensuring recognition by games and platforms like **Steam**.

## 2. Installation & Setup

### Mobile Application

1.  **Download:** Get the **APK** file on your phone.
2.  **Install:** Install the application.
3.  **Launch:** Open the app—it should be ready to connect.

### PC Server

1.  **Download:** Grab the server binary from the project's releases.
2.  **Permissions:** Give the file executable rights via the terminal:
    ```bash
    chmod +x Backend_controler
    ```
3.  **Setup uinput:** Install the udev rule to allow controller simulation without sudo:
    ```bash
    sudo cp 99-uinput.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    ```
    Then add your user to the `input` group:
    ```bash
    sudo usermod -aG input $USER
    # Log out and log back in for changes to take effect
    ```
4.  **Run:** Execute the file by double-clicking it or running it from the terminal. A browser with the configuration **dashboard** will automatically open.

**Important Notes:**

- Ensure your **firewall** is configured to allow **UDP traffic** for the server application.
- The udev rule is required for `/dev/uinput` access without root privileges.

## 3. Screenshots and User Interface (UI)

Cheaptroller's user interface is functional and designed to provide an authentic controller experience on the mobile device, while the backend allows for intuitive management.

| Description                                                                                                                                                                                                                             | Screenshot                                                                             |
| :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------- |
| **Main Page**                                                                                                                                                                                                                           | <img src="assets/MainPage.jpg" alt="Main Page" width="700">                            |
| The mobile app's start page serves as the central hub. Here, the connection to the PC server is established, either by entering the IP address or by using the quick QR code function.                                                  |
| **PlayStation Controller Layout**                                                                                                                                                                                                       | <img src="assets/Playstation_Controller.jpg" alt="Playstation Controller" width="700"> |
| The PlayStation layout reproduces the typical symbols (Cross, Square, Triangle, Circle), along with the D-pad and analog sticks. This layout offers familiar controls for PS-oriented gamers.                                           |
| **XBox Controller Layout**                                                                                                                                                                                                              | <img src="assets/XBox_Controller.jpg" alt="Xbox Controller" width="700">               |
| The Xbox layout provides the A, B, X, and Y buttons as well as the precise arrangement of the analog sticks to simulate the feel of a real Xbox controller.                                                                             |
| **Server Dashboard (Web-UI)**                                                                                                                                                                                                           | <img src="assets/Server_Dash_board.png" alt="Server Dashboard" width="700">            |
| The Dashboard opens in the browser after the Node.js server is started on the PC. It serves as a management interface for checking the connection status, IP address, and port, as well as for troubleshooting or future configuration. |

## 4. Technologies

| Component            | Technology             | Role                                                                           |
| :------------------- | :--------------------- | :----------------------------------------------------------------------------- |
| **Backend / Server** | **Node.js**            | Handles server communication and input translation using the **UDP protocol**. |
| **Frontend / App**   | **Flutter**            | Mobile application that captures and sends control data.                       |
| **PC Input Bridge**  | **Custom C++ Library** | Simulates controller input directly on the PC.                                 |

## 4.1 Communication Protocol

The Cheaptroller uses a custom **binary protocol** over UDP for low-latency communication between the mobile app and the server.

### Message Types

| Type         | Byte | Size  | Description                    |
| :----------- | :--- | :---- | :----------------------------- |
| **MOVE**     | 0x01 | 11 B  | Joystick movement              |
| **BUTTON_DOWN** | 0x02 | 7 B  | Button pressed                |
| **BUTTON_UP**  | 0x03 | 7 B  | Button released               |
| **HEARTBEAT**  | 0x04 | 5 B  | Connection keep-alive         |
| **BATCH**     | 0x05 | var   | Multiple events coalesced      |

### Message Structure

**MOVE** (11 bytes):
```
[0x01][side][x:int16][y:int16][timestamp:uint32]
 1 B    1 B     2 B     2 B           4 B
```

**BUTTON_DOWN / BUTTON_UP** (7 bytes):
```
[type][side][index][timestamp:uint32]
  1 B    1 B    1 B         4 B
```

**HEARTBEAT** (5 bytes):
```
[0x04][timestamp:uint32]
  1 B         4 B
```

**BATCH** (variable):
```
[0x05][count][event1][event2]...
  1 B     1 B     var        var
```

### Fields

| Field      | Type    | Values                      | Description                    |
| :--------- | :------ | :-------------------------- | :----------------------------- |
| **type**   | uint8   | 0x01-0x05                   | Message type identifier        |
| **side**   | uint8   | 0 = left, 1 = right         | Controller side                |
| **x**      | int16   | -32767 to 32767             | Horizontal axis (-1.0 to 1.0)  |
| **y**      | int16   | -32767 to 32767             | Vertical axis (-1.0 to 1.0)    |
| **index**  | uint8   | 0-13                        | Button index                   |
| **timestamp** | uint32 | Unix milliseconds          | For latency tracking           |

### Input Coalescing & Priority

The mobile app uses input coalescing to optimize network usage:

| Feature | Value | Description |
| :------ | :---- | :---------- |
| **Batch Window** | 5ms | Multiple joystick events batched together |
| **Max Batch Size** | 10 events | Maximum events per batch packet |
| **Joystick Rate** | 60 Hz | Max joystick update frequency |
| **Button Priority** | HIGH | Buttons sent immediately (no batching) |
| **Joystick Priority** | LOW | Joysticks are batched |

**Priority Order:** `Button > D-Pad > Joystick`

This ensures button presses have minimal latency while joystick movements are efficiently batched.

### Button Index Mapping

| Index | Button  | Index | Button  |
| :---- | :------ | :---- | :------ |
| 0     | A / X   | 7     | RStick  |
| 1     | B / O   | 8     | Select  |
| 2     | X / □   | 9     | Start   |
| 3     | Y / △   | 10    | D-Pad Up    |
| 4     | LB / L1 | 11    | D-Pad Down  |
| 5     | RB / R1 | 12    | D-Pad Left  |
| 6     | LStick  | 13    | D-Pad Right |

### Performance

| Metric         | JSON (Legacy) | Binary (Current) | Improvement |
| :------------- | :------------ | :--------------- | :---------- |
| Move packet    | ~55 bytes     | 11 bytes         | **78%**     |
| Button packet  | ~45 bytes     | 7 bytes          | **84%**     |
| Parse overhead | High          | Minimal          | Faster      |

## 5. Usage & Controls

The button mapping follows a standard, real-world controller configuration.

| Action                  | Mapping                                                    |
| :---------------------- | :--------------------------------------------------------- |
| **Standard Buttons**    | Normal controller mapping                                  |
| **Big Bumpers (L3/R3)** | Accessed by **double-clicking** the corresponding joystick |

## 6. Troubleshooting

| Issue                              | Solution                                                              |
| :--------------------------------- | :-------------------------------------------------------------------- |
| **Connection Issues**              | Check IP address and firewall settings.                              |
| **Cannot open /dev/uinput**        | Run `sudo udevadm control --reload-rules && sudo udevadm trigger` or install the udev rule from `99-uinput.rules`. |
| **Controller not detected by game**| Ensure the udev rule is installed and user is in the `input` group. |

## 7. Roadmap / To-Do

- Popup notifications for connection issues.
- Vibrational feedback on button press.

## 8. License

See the [LICENSE](LICENSE) file for details.

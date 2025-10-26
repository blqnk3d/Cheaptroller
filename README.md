# Cheaptroller

## 1. Project Overview

**Description:**  
Cheaptroller is a lightweight controller app that turns your mobile device into a versatile game controller. It connects your phone to a small local Node.js server that bridges inputs to your PC with a custom C++ lib for input simulation.

**Purpose / Motivation:**  
The project aims to provide an easy way to control your PC using a mobile device, enabling gaming without extra hardware.

**Problems Solved:**

- Eliminates the need for dedicated game controllers

---

## 2. Features

- Connecting via QR Code
- **2 Layouts**
  - Playstation
  - XBox
- **Simulation** : acts as a real controller so games with support / Steam recognice it

---

## UI

### App

<div style="text-align: center;">
  <img src="assets/MainPage.jpg" alt="Main Page" width="600">
</div>

---

<div style="text-align: center;">
  <img src="assets/Playstation_Controller.jpg" alt="Playstation_Controller" >
</div>

---

<div style="text-align: center;">
  <img src="assets/XBox_Controller.jpg" alt="XBox_Controller" >
</div>

### Server

<div style="text-align: center;">
  <img src="assets/Server_Dash_board.png" alt="Server_Dash_board" >
</div>

---

## 4. Technologies

- **Node.js Backend:** Handles server communication and input translation (UDP protocol)
- **Flutter Frontend:** Mobile app that sends control data
- Optional: Additional libraries or dependencies

---

## 5. Installation & Setup

### **Steps:**

#### **APP**

1. Download the apk on ur phone
2. Install it (u can scann it via Google play)
3. u can now open the app and it should start

#### **SERVER**

1. Download the binary from the releases
2. give it executable right via `chmod +x Backend_controler`
3. u can now run it by double click or through the terminal
4. a browser with the dashboard should appear

**Notes:**

- Ensure firewall allows UDP traffic
- Optional: Provide QR code or direct link for mobile app

---

## 6. Usage / Controls

Normal mapping like a real controller exept the Big bumpers are currently accesed via double clicking the joystick on the respected side

---

## 8. Troubleshooting

- Connection issues: Check IP, port, and firewall
- Minimal or no input: Ensure the app is running and joystick is active
- Debugging tips: Enable logs in server and app

---

## 9. Roadmap / To-Do

- Auto-reconnect after first manual connection
- Popup notifications for connection issues
- Vibrational feedback on button press
- Multi-device support

---

## 11. License

[License](LICENSE)

---

## 12. Acknowledgements / Credits

- Libraries, frameworks, or tools used
- Designers, testers, and contributors

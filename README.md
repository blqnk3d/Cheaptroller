# Cheaptroller

Cheaptroller is a lightweight controller app designed to turn your mobile device into a versatile game and mouse controller. It connects your phone to a small local Node.js server that acts as the bridge to your computer.

## Features

- Joystick 1: Controls WASD movement for gaming.
- Joystick 2: Controls mouse movement.
- Mouse buttons: Supports 3 mouse buttons.
- Settings: Adjustable mouse settings including speed, deadzone, smoothing, and update rate.

The mouse settings use the following parameters in the backend server:

## Default

const UDP_PORT = 8080;
let MAX_SPEED = 80;
let DEADZONE = 0.1;
let SMOOTH_FACTOR = 0.3;
let MOVE_THROTTLE = 1000 / 60;

## Technologies Used

- Node.js: Backend server that handles communication and input translation (planned to be compiled into an executable).
- Flutter: Mobile app frontend that runs on your phone and sends control data.

## Installation & Setup

Coming soon. Stay tuned for setup instructions!

## Usage

Connect your phone running the Flutter app to the Node.js server on your local network via UDP port 8080 to start controlling your PC with joysticks and mouse inputs.



#include <napi.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <cstring>
#include <string>
#include <unordered_map>

int fd = -1;

// ----------------------------------------------------
// 🧩 CREATE DEVICE
// ----------------------------------------------------
void create(const Napi::CallbackInfo &info)
{
    Napi::Env env = info.Env();

    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0)
    {
        Napi::TypeError::New(env, "Cannot open /dev/uinput. Check permissions (sudo or udev rule).")
            .ThrowAsJavaScriptException();
        return;
    }

    // --- 1. Event Types ---
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_ABS);

    // --- 2. Buttons ---
    ioctl(fd, UI_SET_KEYBIT, BTN_A);
    ioctl(fd, UI_SET_KEYBIT, BTN_B);
    ioctl(fd, UI_SET_KEYBIT, BTN_X);
    ioctl(fd, UI_SET_KEYBIT, BTN_Y);
    ioctl(fd, UI_SET_KEYBIT, BTN_TL);
    ioctl(fd, UI_SET_KEYBIT, BTN_TR);
    ioctl(fd, UI_SET_KEYBIT, BTN_SELECT);
    ioctl(fd, UI_SET_KEYBIT, BTN_START);
    ioctl(fd, UI_SET_KEYBIT, BTN_THUMBL);
    ioctl(fd, UI_SET_KEYBIT, BTN_THUMBR);

    // --- D-Pad keys (digital) ---
    ioctl(fd, UI_SET_KEYBIT, BTN_DPAD_UP);
    ioctl(fd, UI_SET_KEYBIT, BTN_DPAD_DOWN);
    ioctl(fd, UI_SET_KEYBIT, BTN_DPAD_LEFT);
    ioctl(fd, UI_SET_KEYBIT, BTN_DPAD_RIGHT);

    // --- 3. D-Pad (Hat Switch via ABS_HAT0X / ABS_HAT0Y) ---
    // Keep ABS_HAT bits if you still want hat axis support in addition to digital keys
    ioctl(fd, UI_SET_ABSBIT, ABS_HAT0X);
    ioctl(fd, UI_SET_ABSBIT, ABS_HAT0Y);

    // --- 4. Sticks ---
    ioctl(fd, UI_SET_ABSBIT, ABS_X);
    ioctl(fd, UI_SET_ABSBIT, ABS_Y);
    ioctl(fd, UI_SET_ABSBIT, ABS_RX);
    ioctl(fd, UI_SET_ABSBIT, ABS_RY);

    // --- 5. Device Setup ---
    struct uinput_user_dev uidev;
    memset(&uidev, 0, sizeof(uidev));
    snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "NodeVirtualGamepad");
    uidev.id.bustype = BUS_USB;
    uidev.id.vendor = 0x1234;
    uidev.id.product = 0x5678;
    uidev.id.version = 1;

    // --- Stick axis ranges ---
    uidev.absmin[ABS_X] = -32767;
    uidev.absmax[ABS_X] = 32767;
    uidev.absmin[ABS_Y] = -32767;
    uidev.absmax[ABS_Y] = 32767;
    uidev.absmin[ABS_RX] = -32767;
    uidev.absmax[ABS_RX] = 32767;
    uidev.absmin[ABS_RY] = -32767;
    uidev.absmax[ABS_RY] = 32767;

    // --- D-Pad axis ranges (-1 = left/up, 0 = neutral, 1 = right/down) ---
    uidev.absmin[ABS_HAT0X] = -1;
    uidev.absmax[ABS_HAT0X] = 1;
    uidev.absmin[ABS_HAT0Y] = -1;
    uidev.absmax[ABS_HAT0Y] = 1;

    // Create the device
    write(fd, &uidev, sizeof(uidev));
    ioctl(fd, UI_DEV_CREATE);
}

// ----------------------------------------------------
// 🎮 MOVE STICK
// ----------------------------------------------------
void moveStick(const Napi::CallbackInfo &info)
{
    Napi::Env env = info.Env();
    if (fd < 0)
        return;

    std::string side = info[0].As<Napi::String>();
    int x = info[1].As<Napi::Number>().Int32Value();
    int y = info[2].As<Napi::Number>().Int32Value();

    struct input_event ie;
    memset(&ie, 0, sizeof(ie));

    int x_code = -1, y_code = -1;

    if (side == "left")
    {
        x_code = ABS_X;
        y_code = ABS_Y;
    }
    else if (side == "right")
    {
        x_code = ABS_RX;
        y_code = ABS_RY;
    }
    else
    {
        std::string err = "Invalid stick side specified: " + side + ". Must be 'left' or 'right'.";
        Napi::TypeError::New(env, err).ThrowAsJavaScriptException();
        return;
    }

    ie.type = EV_ABS;
    ie.code = x_code;
    ie.value = x;
    write(fd, &ie, sizeof(ie));

    ie.code = y_code;
    ie.value = y;
    write(fd, &ie, sizeof(ie));

    // sync
    ie.type = EV_SYN;
    ie.code = SYN_REPORT;
    ie.value = 0;
    write(fd, &ie, sizeof(ie));
}

// ----------------------------------------------------
// 🎯 PRESS BUTTON
// ----------------------------------------------------
void pressButton(const Napi::CallbackInfo &info)
{
    Napi::Env env = info.Env();
    if (fd < 0)
        return;

    std::string button = info[0].As<Napi::String>();
    bool pressed = info[1].As<Napi::Boolean>();

    static const std::unordered_map<std::string, int> buttonMap = {
        {"A", BTN_A},
        {"B", BTN_B},
        {"X", BTN_X},
        {"Y", BTN_Y},
        {"LB", BTN_TL},
        {"RB", BTN_TR},
        {"Select", BTN_SELECT},
        {"Start", BTN_START},
        {"LStick", BTN_THUMBL},
        {"RStick", BTN_THUMBR},
        {"Up", BTN_DPAD_UP},
        {"Down", BTN_DPAD_DOWN},
        {"Left", BTN_DPAD_LEFT},
        {"Right", BTN_DPAD_RIGHT}};

    auto it = buttonMap.find(button);
    if (it == buttonMap.end())
    {
        std::string error_msg = "Button not found: " + button;
        Napi::TypeError::New(env, error_msg).ThrowAsJavaScriptException();
        return;
    }

    struct input_event ie;
    memset(&ie, 0, sizeof(ie));
    ie.type = EV_KEY;
    ie.code = it->second;
    ie.value = pressed ? 1 : 0;
    write(fd, &ie, sizeof(ie));

    // sync
    ie.type = EV_SYN;
    ie.code = SYN_REPORT;
    ie.value = 0;
    write(fd, &ie, sizeof(ie));
}

// ----------------------------------------------------
// 🧭 MOVE DPAD (Hat switch, analog -1/0/1)
// ----------------------------------------------------
void moveDpad(const Napi::CallbackInfo &info)
{
    Napi::Env env = info.Env();
    if (fd < 0)
        return;

    int x = info[0].As<Napi::Number>().Int32Value();
    int y = info[1].As<Napi::Number>().Int32Value();

    if (x < -1) x = -1;
    if (x > 1) x = 1;
    if (y < -1) y = -1;
    if (y > 1) y = 1;

    struct input_event ie;
    memset(&ie, 0, sizeof(ie));

    auto sendKey = [&](int code, int val) {
        ie.type = EV_KEY;
        ie.code = code;
        ie.value = val;
        write(fd, &ie, sizeof(ie));
    };

    // X axis: -1 = left, 0 = neutral, 1 = right
    if (x == -1) {
        sendKey(BTN_DPAD_LEFT, 1);
        sendKey(BTN_DPAD_RIGHT, 0);
    } else if (x == 1) {
        sendKey(BTN_DPAD_LEFT, 0);
        sendKey(BTN_DPAD_RIGHT, 1);
    } else {
        sendKey(BTN_DPAD_LEFT, 0);
        sendKey(BTN_DPAD_RIGHT, 0);
    }

    // Y axis: -1 = up, 0 = neutral, 1 = down
    if (y == -1) {
        sendKey(BTN_DPAD_UP, 1);
        sendKey(BTN_DPAD_DOWN, 0);
    } else if (y == 1) {
        sendKey(BTN_DPAD_UP, 0);
        sendKey(BTN_DPAD_DOWN, 1);
    } else {
        sendKey(BTN_DPAD_UP, 0);
        sendKey(BTN_DPAD_DOWN, 0);
    }

    // sync
    ie.type = EV_SYN;
    ie.code = SYN_REPORT;
    ie.value = 0;
    write(fd, &ie, sizeof(ie));
}

// ----------------------------------------------------
// ❌ CLOSE DEVICE
// ----------------------------------------------------
void closeDevice(const Napi::CallbackInfo &info)
{
    if (fd >= 0)
    {
        ioctl(fd, UI_DEV_DESTROY);
        close(fd);
        fd = -1;
    }
}

// ----------------------------------------------------
// 🧩 EXPORTS
// ----------------------------------------------------
Napi::Object Init(Napi::Env env, Napi::Object exports)
{
    exports.Set("create", Napi::Function::New(env, create));
    exports.Set("moveStick", Napi::Function::New(env, moveStick));
    exports.Set("pressButton", Napi::Function::New(env, pressButton));
    exports.Set("moveDpad", Napi::Function::New(env, moveDpad));
    exports.Set("close", Napi::Function::New(env, closeDevice));
    return exports;
}

NODE_API_MODULE(gamepad, Init)

#include <napi.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <cstring>
#include <string>

int fd = -1;

void create(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        // Throw exception if uinput device cannot be opened (often due to permissions)
        Napi::TypeError::New(env, "Cannot open /dev/uinput. Check permissions (sudo or udev rule).").ThrowAsJavaScriptException();
        return;
    }

    // --- 1. Set Event Types ---
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_ABS);

    // --- 2. Register Buttons (Keys) ---
    ioctl(fd, UI_SET_KEYBIT, BTN_A);
    ioctl(fd, UI_SET_KEYBIT, BTN_B);
    ioctl(fd, UI_SET_KEYBIT, BTN_X);
    ioctl(fd, UI_SET_KEYBIT, BTN_Y);
    ioctl(fd, UI_SET_KEYBIT, BTN_TL);      // LB (Left Bumper)
    ioctl(fd, UI_SET_KEYBIT, BTN_TR);      // RB (Right Bumper)
    ioctl(fd, UI_SET_KEYBIT, BTN_SELECT);  // Select/Back Button
    ioctl(fd, UI_SET_KEYBIT, BTN_START);   // Start Button
    ioctl(fd, UI_SET_KEYBIT, BTN_THUMBL);  // Left Stick Press (LStick)
    ioctl(fd, UI_SET_KEYBIT, BTN_THUMBR);  // Right Stick Press (RStick)

    // --- 3. Register Axes (Sticks) ---
    ioctl(fd, UI_SET_ABSBIT, ABS_X);   // Left Stick X
    ioctl(fd, UI_SET_ABSBIT, ABS_Y);   // Left Stick Y
    ioctl(fd, UI_SET_ABSBIT, ABS_RX);  // Right Stick X
    ioctl(fd, UI_SET_ABSBIT, ABS_RY);  // Right Stick Y

    // --- 4. Define Device and Axis Properties ---
    struct uinput_user_dev uidev;
    memset(&uidev, 0, sizeof(uidev));
    snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "NodeVirtualGamepad");
    uidev.id.bustype = BUS_USB;
    uidev.id.vendor  = 0x1234;
    uidev.id.product = 0x5678;
    uidev.id.version = 1;

    // Define the range for all registered axes (-32767 to 32767 for full precision)
    uidev.absmin[ABS_X] = -32767;
    uidev.absmax[ABS_X] = 32767;
    uidev.absflat[ABS_X] = 0; // Dead zone

    uidev.absmin[ABS_Y] = -32767;
    uidev.absmax[ABS_Y] = 32767;
    uidev.absflat[ABS_Y] = 0;

    uidev.absmin[ABS_RX] = -32767;
    uidev.absmax[ABS_RX] = 32767;
    uidev.absflat[ABS_RX] = 0;

    uidev.absmin[ABS_RY] = -32767;
    uidev.absmax[ABS_RY] = 32767;
    uidev.absflat[ABS_RY] = 0;

    // --- 5. Create Device ---
    write(fd, &uidev, sizeof(uidev));
    ioctl(fd, UI_DEV_CREATE);
}

void moveStick(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    if (fd < 0) return;

    std::string side = info[0].As<Napi::String>();
    int x = info[1].As<Napi::Number>().Int32Value();
    int y = info[2].As<Napi::Number>().Int32Value();

    struct input_event ie;
    memset(&ie, 0, sizeof(ie));

    int x_code = -1;
    int y_code = -1;

    // 🚨 Explicitly check and assign axis codes, or throw an error 🚨
    if (side == "left") {
        x_code = ABS_X;
        y_code = ABS_Y;
    } else if (side == "right") {
        x_code = ABS_RX;
        y_code = ABS_RY;
    } else {
        std::string error_msg = "Invalid stick side specified: " + side + ". Must be 'left' or 'right'.";
        Napi::TypeError::New(env, error_msg).ThrowAsJavaScriptException();
        return;
    }

    // Send X-axis event
    ie.type = EV_ABS;
    ie.code = x_code;
    ie.value = x;
    write(fd, &ie, sizeof(ie));

    // Send Y-axis event
    ie.code = y_code;
    ie.value = y;
    write(fd, &ie, sizeof(ie));

    // Send sync event
    ie.type = EV_SYN;
    ie.code = SYN_REPORT;
    ie.value = 0;
    write(fd, &ie, sizeof(ie));
}

void pressButton(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    if (fd < 0) return;

    std::string button = info[0].As<Napi::String>();
    bool pressed = info[1].As<Napi::Boolean>();

    struct input_event ie;
    memset(&ie, 0, sizeof(ie));
    ie.type = EV_KEY;

    int button_code = -1;

    // Map button string to uinput code
    if (button == "A") button_code = BTN_A;
    else if (button == "B") button_code = BTN_B;
    else if (button == "X") button_code = BTN_X;
    else if (button == "Y") button_code = BTN_Y;
    else if (button == "LB") button_code = BTN_TL;
    else if (button == "RB") button_code = BTN_TR;
    else if (button == "Select") button_code = BTN_SELECT;
    else if (button == "Start") button_code = BTN_START;
    else if (button == "LStick") button_code = BTN_THUMBL;
    else if (button == "RStick") button_code = BTN_THUMBR;

    // Throw error if button is not recognized
    if (button_code == -1) {
        std::string error_msg = "Button not found: " + button;
        Napi::TypeError::New(env, error_msg).ThrowAsJavaScriptException();
        return;
    }

    ie.code = button_code;
    ie.value = pressed ? 1 : 0;
    write(fd, &ie, sizeof(ie));

    // Send sync event
    ie.type = EV_SYN;
    ie.code = SYN_REPORT;
    ie.value = 0;
    write(fd, &ie, sizeof(ie));
}


void closeDevice(const Napi::CallbackInfo& info) {
    if (fd >= 0) {
        ioctl(fd, UI_DEV_DESTROY);
        close(fd);
        fd = -1;
    }
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
    exports.Set("create", Napi::Function::New(env, create));
    exports.Set("moveStick", Napi::Function::New(env, moveStick));
    exports.Set("pressButton", Napi::Function::New(env, pressButton));
    exports.Set("close", Napi::Function::New(env, closeDevice));
    return exports;
}

NODE_API_MODULE(gamepad, Init)
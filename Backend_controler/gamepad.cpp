#include <napi.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <cstring>

int fd = -1;

void create(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        Napi::TypeError::New(env, "Cannot open /dev/uinput").ThrowAsJavaScriptException();
        return;
    }

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_ABS);

    // Example buttons
    ioctl(fd, UI_SET_KEYBIT, BTN_A);
    ioctl(fd, UI_SET_KEYBIT, BTN_B);

    // Example axes
    ioctl(fd, UI_SET_ABSBIT, ABS_X);
    ioctl(fd, UI_SET_ABSBIT, ABS_Y);

    struct uinput_user_dev uidev;
    memset(&uidev, 0, sizeof(uidev));
    snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "NodeVirtualGamepad");
    uidev.id.bustype = BUS_USB;
    uidev.id.vendor  = 0x1234;
    uidev.id.product = 0x5678;
    uidev.id.version = 1;

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

    ie.type = EV_ABS;
    ie.code = (side == "left") ? ABS_X : ABS_RX;
    ie.value = x;
    write(fd, &ie, sizeof(ie));

    ie.code = (side == "left") ? ABS_Y : ABS_RY;
    ie.value = y;
    write(fd, &ie, sizeof(ie));

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

    if (button == "A") ie.code = BTN_A;
    else if (button == "B") ie.code = BTN_B;

    ie.value = pressed ? 1 : 0;
    write(fd, &ie, sizeof(ie));

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

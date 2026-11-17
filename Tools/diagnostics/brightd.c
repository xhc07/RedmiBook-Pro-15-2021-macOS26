// brightd: 监听键盘 F4/F5（以及 Consumer 亮度键），调整内屏亮度
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <mach/mach_time.h>

static io_service_t display(void) {
    io_iterator_t it;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplay"), &it) != KERN_SUCCESS) return 0;
    io_service_t s, good = 0;
    float tmp;
    while ((s = IOIteratorNext(it))) {
        if (IODisplayGetFloatParameter(s, 0, CFSTR(kIODisplayBrightnessKey), &tmp) == kIOReturnSuccess) { good = s; break; }
        IOObjectRelease(s);
    }
    IOObjectRelease(it);
    return good;
}

static void adjust(double delta) {
    io_service_t d = display();
    if (!d) return;
    float cur = 0;
    if (IODisplayGetFloatParameter(d, 0, CFSTR(kIODisplayBrightnessKey), &cur) == kIOReturnSuccess) {
        float nv = cur + (float)delta;
        if (nv < 0.02f) nv = 0.02f;
        if (nv > 1.0f) nv = 1.0f;
        IODisplaySetFloatParameter(d, 0, CFSTR(kIODisplayBrightnessKey), nv);
    }
    IOObjectRelease(d);
}

static uint64_t last = 0;
static void cb(void *ctx, IOReturn res, void *sender, IOHIDValueRef value) {
    IOHIDElementRef el = IOHIDValueGetElement(value);
    uint32_t up = IOHIDElementGetUsagePage(el);
    uint32_t us = IOHIDElementGetUsage(el);
    if (IOHIDValueGetIntegerValue(value) == 0) return;

    int dir = 0;
    if (up == 0x07 && us == 0x3D) dir = -1;        // 物理 F4 → 暗
    else if (up == 0x07 && us == 0x3E) dir = +1;   // 物理 F5 → 亮
    else if (up == 0x0C && us == 0x70) dir = -1;   // Consumer 亮度-
    else if (up == 0x0C && us == 0x6F) dir = +1;   // Consumer 亮度+
    if (!dir) return;

    uint64_t now = mach_absolute_time();
    if (now - last < 80000000ULL) return;          // 防抖 80ms
    last = now;
    adjust(dir * 0.0625);
}

int main(void) {
    IOHIDManagerRef m = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!m) return 1;
    IOHIDManagerSetDeviceMatching(m, NULL);
    IOHIDManagerRegisterInputValueCallback(m, cb, NULL);
    IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    if (IOHIDManagerOpen(m, kIOHIDOptionsTypeNone) != kIOReturnSuccess) return 1;
    CFRunLoopRun();
    return 0;
}

#include <IOKit/hid/IOHIDManager.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

static void dev_name(IOHIDElementRef el, char *buf, size_t n) {
    buf[0] = 0;
    IOHIDDeviceRef d = IOHIDElementGetDevice(el);
    if (!d) return;
    CFTypeRef p = IOHIDDeviceGetProperty(d, CFSTR(kIOHIDProductKey));
    if (p && CFGetTypeID(p) == CFStringGetTypeID())
        CFStringGetCString((CFStringRef)p, buf, (CFIndex)n, kCFStringEncodingUTF8);
}

static void cb(void *ctx, IOReturn res, void *sender, IOHIDValueRef value) {
    IOHIDElementRef el = IOHIDValueGetElement(value);
    uint32_t up = IOHIDElementGetUsagePage(el);
    uint32_t us = IOHIDElementGetUsage(el);
    long v = IOHIDValueGetIntegerValue(value);
    if (v == 0) return;

    char name[128]; dev_name(el, name, sizeof name);
    /* 过滤掉指针设备 */
    if (strstr(name, "Trackpad") || strstr(name, "Touchpad") || strstr(name, "Mouse") || strstr(name, "PS2Mouse")) return;

    /* 只关心：Consumer 页(0x0C) 或 Keyboard 页(0x07) 的 F 区/特殊键 */
    int interesting = 0;
    if (up == 0x0C) interesting = 1;
    else if (up == 0x07 && us >= 0x3A && us <= 0xE7) interesting = 1;
    if (!interesting) return;

    const char *what = "";
    if (up == 0x0C) {
        switch (us) {
            case 0x6F: what = "  <-- 亮度+ (Brightness Up)"; break;
            case 0x70: what = "  <-- 亮度- (Brightness Down)"; break;
            case 0xE2: what = "  (静音 Mute)"; break;
            case 0xE9: what = "  (音量+ Volume Up)"; break;
            case 0xEA: what = "  (音量- Volume Down)"; break;
            default: break;
        }
    }
    printf("PAGE=0x%02X USAGE=0x%04X VALUE=%ld DEV=%s%s\n", up, us, v, name, what);
    fflush(stdout);
}

int main(void) {
    IOHIDManagerRef m = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!m) return 1;
    IOHIDManagerSetDeviceMatching(m, NULL);
    IOHIDManagerRegisterInputValueCallback(m, cb, NULL);
    IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOReturn r = IOHIDManagerOpen(m, kIOHIDOptionsTypeNone);
    if (r != kIOReturnSuccess) { fprintf(stderr, "open failed 0x%x（可能需要权限）\n", r); return 1; }
    printf("=== HID 监听（只显示媒体键/F键）按 Ctrl+C 结束 ===\n");
    fflush(stdout);
    CFRunLoopRun();
    return 0;
}

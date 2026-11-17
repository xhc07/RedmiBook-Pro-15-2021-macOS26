#include <IOKit/hid/IOHIDManager.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

static const char *dev_name_of(IOHIDElementRef el) {
    static char buf[256];
    IOHIDDeviceRef d = IOHIDElementGetDevice(el);
    if (!d) return "?";
    CFTypeRef p = IOHIDDeviceGetProperty(d, CFSTR(kIOHIDProductKey));
    if (p && CFGetTypeID(p) == CFStringGetTypeID())
        CFStringGetCString((CFStringRef)p, buf, sizeof buf, kCFStringEncodingUTF8);
    else snprintf(buf, sizeof buf, "?");
    return buf;
}

static void cb(void *ctx, IOReturn res, void *sender, IOHIDValueRef value) {
    IOHIDElementRef el = IOHIDValueGetElement(value);
    uint32_t up = IOHIDElementGetUsagePage(el);
    uint32_t us = IOHIDElementGetUsage(el);
    long v = IOHIDValueGetIntegerValue(value);
    if (v == 0) return;
    if (us == 0 || us == 0xFFFF) return;
    printf("PAGE=0x%02X USAGE=0x%04X VALUE=%ld DEV=%s\n", up, us, v, dev_name_of(el));
    fflush(stdout);
}

int main(void) {
    IOHIDManagerRef m = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!m) return 1;
    IOHIDManagerSetDeviceMatching(m, NULL);   // 所有 HID 设备
    IOHIDManagerRegisterInputValueCallback(m, cb, NULL);
    IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOReturn r = IOHIDManagerOpen(m, kIOHIDOptionsTypeNone);
    if (r != kIOReturnSuccess) { fprintf(stderr, "open failed 0x%x\n", r); return 1; }
    printf("=== HID 监听中（按 Ctrl+C 结束）===\n");
    fflush(stdout);
    CFRunLoopRun();
    return 0;
}

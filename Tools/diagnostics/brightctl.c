#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s get|set <0-1>\n", argv[0]); return 2; }
    io_iterator_t iter;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplay"), &iter) != KERN_SUCCESS) {
        fprintf(stderr, "no IODisplay services\n"); return 1;
    }
    int found = 0; float v = 0;
    io_service_t s;
    while ((s = IOIteratorNext(iter))) {
        float tmp = 0;
        IOReturn gr = IODisplayGetFloatParameter(s, 0, CFSTR(kIODisplayBrightnessKey), &tmp);
        if (gr == kIOReturnSuccess) {
            found = 1; v = tmp;
            if (!strcmp(argv[1], "get")) {
                printf("%.4f\n", v);
            } else {
                float nv = (float)atof(argv[2]);
                IOReturn r = IODisplaySetFloatParameter(s, 0, CFSTR(kIODisplayBrightnessKey), nv);
                printf("set %.3f -> %s (old %.4f)\n", nv, r == kIOReturnSuccess ? "OK" : "FAIL", v);
            }
            IOObjectRelease(s);
            break;
        }
        IOObjectRelease(s);
    }
    IOObjectRelease(iter);
    if (!found) { fprintf(stderr, "brightness parameter not found\n"); return 1; }
    return 0;
}

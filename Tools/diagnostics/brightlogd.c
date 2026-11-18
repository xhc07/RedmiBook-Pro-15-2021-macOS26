// brightlogd: 每 200ms 采样显示亮度，变化时写日志（用于排查开机自动调亮）
// 日志: /var/log/brightness.log
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <string.h>
#include <sys/sysctl.h>

static double uptime_sec(void) {
    struct timeval tv; size_t len = sizeof(tv);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if (sysctl(mib, 2, &tv, &len, NULL, 0) != 0) return 0;
    return (double)(time(NULL) - tv.tv_sec);
}

static io_service_t findDisplay(void) {
    io_iterator_t it;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplay"), &it) != KERN_SUCCESS)
        return 0;
    io_service_t s = IOIteratorNext(it);
    IOObjectRelease(it);
    return s;
}

static int readBrightness(io_service_t s, float *out) {
    return IODisplayGetFloatParameter(s, 0, CFSTR(kIODisplayBrightnessKey), out) == kIOReturnSuccess;
}

int main(void) {
    FILE *f = fopen("/var/log/brightness.log", "a");
    if (!f) return 1;
    setvbuf(f, NULL, _IOLBF, 0);
    fprintf(f, "=== brightlogd start (uptime %.1fs) ===\n", uptime_sec());

    io_service_t svc = 0;
    float last = -1.0f;
    while (1) {
        if (!svc) svc = findDisplay();
        if (svc) {
            float v = 0;
            if (readBrightness(svc, &v)) {
                if (v < 0) v = 0;
                if (last < 0 || v != last) {
                    time_t t = time(NULL);
                    struct tm tmv; localtime_r(&t, &tmv);
                    fprintf(f, "%02d:%02d:%02d.%03d  uptime=%7.1fs  brightness=%.4f\n",
                            tmv.tm_hour, tmv.tm_min, tmv.tm_sec,
                            (int)((t * 1000) % 1000), uptime_sec(), v);
                    last = v;
                }
            } else {
                IOObjectRelease(svc); svc = 0;
            }
        }
        usleep(200 * 1000);
    }
    return 0;
}

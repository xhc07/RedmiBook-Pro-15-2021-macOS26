// mifskeysd: 轮询 MIFSKeys.kext 的事件属性，触发对应 macOS 动作
//   1 = 投屏（打开显示器设置）
//   2 = 区域截图（screencapture -i -c）
//   3 = 任务视图（Mission Control）
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <spawn.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>

extern char **environ;

static volatile sig_atomic_t gStop = 0;
static void onTerm(int s) { (void)s; gStop = 1; }

static void runCmd(char *const argv[])
{
    pid_t pid = 0;
    int rc = posix_spawn(&pid, argv[0], NULL, NULL, argv, environ);
    if (rc == 0) {
        printf("mifskeysd: spawn %s ok (pid %d)\n", argv[0], (int)pid);
    } else {
        printf("mifskeysd: spawn %s failed rc=%d\n", argv[0], rc);
    }
}

static unsigned readU32(io_service_t svc, CFStringRef key, int *ok)
{
    unsigned v = 0;
    CFTypeRef c = IORegistryEntryCreateCFProperty(svc, key, kCFAllocatorDefault, 0);
    if (c) {
        if (CFGetTypeID(c) == CFNumberGetTypeID()) {
            long long n = 0;
            CFNumberGetValue((CFNumberRef)c, kCFNumberLongLongType, &n);
            v = (unsigned)n;
            if (ok) *ok = 1;
        }
        CFRelease(c);
    }
    return v;
}

static void handle(unsigned code)
{
    printf("mifskeysd: event %u\n", code);
    switch (code) {
        case 1: {
            char *argv[] = { "/usr/bin/open",
                             "x-apple.systempreferences:com.apple.Displays-Settings.extension",
                             NULL };
            runCmd(argv);
            break;
        }
        case 2: {
            char *argv[] = { "/usr/sbin/screencapture", "-i", "-c", NULL };
            runCmd(argv);
            break;
        }
        case 3: {
            char *argv[] = { "/usr/bin/open", "-a",
                             "/System/Applications/Mission Control.app", NULL };
            runCmd(argv);
            break;
        }
        default:
            printf("mifskeysd: unknown event code %u\n", code);
            break;
    }
}

int main(void)
{
    signal(SIGTERM, onTerm);
    signal(SIGINT, onTerm);
    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("mifskeysd: start\n");
    unsigned lastCount = 0;
    int inited = 0;
    io_service_t svc = 0;

    while (!gStop) {
        if (!svc) {
            svc = IOServiceGetMatchingService(kIOMasterPortDefault,
                                              IOServiceMatching("MIFSKeys"));
            if (svc) {
                printf("mifskeysd: found MIFSKeys service\n");
                inited = 0;
            }
        }
        if (svc) {
            int ok = 0;
            unsigned count = readU32(svc, CFSTR("EventCount"), &ok);
            if (ok) {
                if (!inited) {
                    lastCount = count;
                    inited = 1;
                } else if (count != lastCount) {
                    unsigned code = readU32(svc, CFSTR("LastEvent"), NULL);
                    lastCount = count;
                    handle(code);
                }
            } else {
                IOObjectRelease(svc);
                svc = 0;
            }
        }
        usleep(100 * 1000);   /* 100 ms */
    }
    if (svc) IOObjectRelease(svc);
    printf("mifskeysd: exit\n");
    return 0;
}

// mifslidd: 合盖关屏守护进程
//   - 轮询 IOPMrootDomain 的 AppleClamshellState
//   - 合盖 → pmset displaysleepnow（关屏）
//   - 开盖 → caffeinate -u -t 1（唤醒屏幕）
// 背景：本机系统睡眠不可用（SleepDisabled=1），macOS 因此不走"合盖关屏"路径。
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
    if (rc != 0)
        fprintf(stderr, "mifslidd: spawn %s failed rc=%d\n", argv[0], rc);
}

/* 返回 1=合盖, 0=开盖, -1=读不到 */
static io_registry_entry_t fPM = 0;

static int readClamshell(void)
{
    if (!fPM) {
        fPM = IOServiceGetMatchingService(kIOMasterPortDefault,
                                          IOServiceMatching("IOPMrootDomain"));
        if (!fPM) return -1;
    }
    io_registry_entry_t pm = fPM;
    int closed = -1;
    CFTypeRef v = IORegistryEntryCreateCFProperty(pm, CFSTR("AppleClamshellState"),
                                                  kCFAllocatorDefault, 0);
    if (v) {
        if (CFGetTypeID(v) == CFBooleanGetTypeID())
            closed = CFBooleanGetValue((CFBooleanRef)v) ? 1 : 0;
        else if (CFGetTypeID(v) == CFStringGetTypeID())
            closed = CFStringCompare((CFStringRef)v, CFSTR("Yes"), 0) == kCFCompareEqualTo ? 1 : 0;
        CFRelease(v);
    }
    return closed;
}

int main(void)
{
    signal(SIGTERM, onTerm);
    signal(SIGINT, onTerm);
    setvbuf(stdout, NULL, _IOLBF, 0);
    printf("mifslidd: start\n");

    int last = -1;
    while (!gStop) {
        int cur = readClamshell();
        if (cur >= 0 && last < 0) {
            printf("mifslidd: initial clamshell=%d\n", cur);
        }
        if (cur >= 0 && cur != last) {
            if (last >= 0) {
                if (cur == 1) {
                    printf("mifslidd: lid closed -> displaysleepnow\n");
                    char *a1[] = { "/usr/bin/pmset", "displaysleepnow", NULL };
                    runCmd(a1);
                } else {
                    printf("mifslidd: lid opened -> wake display\n");
                    char *a2[] = { "/usr/bin/caffeinate", "-u", "-t", "1", NULL };
                    runCmd(a2);
                }
            }
            last = cur;
        }
        usleep(500 * 1000);   /* 500 ms */
    }
    printf("mifslidd: exit\n");
    return 0;
}

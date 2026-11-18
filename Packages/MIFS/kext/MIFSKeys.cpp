// MIFSKeys: 接收 SSDT-KEYS 发来的 ACPI 通知（HKEY 设备），把事件码写到 IORegistry，
//           由用户态 mifskeysd 读取并触发 macOS 动作。
#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>
#include <IOKit/acpi/IOACPITypes.h>

class MIFSKeys : public IOService
{
    OSDeclareDefaultStructors(MIFSKeys)

private:
    UInt32 fCount;
    UInt32 fLast;

public:
    virtual bool     start(IOService *provider) APPLE_KEXT_OVERRIDE;
    virtual void     stop(IOService *provider) APPLE_KEXT_OVERRIDE;
    virtual IOReturn message(UInt32 type, IOService *provider, void *argument) APPLE_KEXT_OVERRIDE;
};

OSDefineMetaClassAndStructors(MIFSKeys, IOService)

bool MIFSKeys::start(IOService *provider)
{
    if (!IOService::start(provider)) {
        return false;
    }
    fCount = 0;
    fLast  = 0;
    setProperty("MIFSKeysReady", kOSBooleanTrue);
    setProperty("EventCount", fCount, 32);
    setProperty("LastEvent",  fLast,  32);
    // 必须注册，否则 IOService 不会出现在 IORegistry，用户态也匹配不到
    registerService();
    IOLog("MIFSKeys: attached to %s, registered\n", provider ? provider->getName() : "?");
    return true;
}

void MIFSKeys::stop(IOService *provider)
{
    IOLog("MIFSKeys: stop\n");
    IOService::stop(provider);
}

IOReturn MIFSKeys::message(UInt32 type, IOService *provider, void *argument)
{
    if (type == kIOACPIMessageDeviceNotification) {
        UInt32 code = 0;
        if (argument) {
            code = *reinterpret_cast<UInt32 *>(argument);
        }
        fCount++;
        fLast = code;
        setProperty("EventCount", fCount, 32);
        setProperty("LastEvent",  code,   32);
        IOLog("MIFSKeys: ACPI notify code=%u count=%u\n", (unsigned)code, (unsigned)fCount);
        return kIOReturnSuccess;
    }
    return IOService::message(type, provider, argument);
}

// ---- kext 模块元数据（必须有，否则内核拒绝加载）----
#include <libkern/OSKextLib.h>

static kern_return_t MIFSKeys_start(kmod_info_t *ki, void *d)
{
    (void)ki; (void)d;
    return KERN_SUCCESS;
}

static kern_return_t MIFSKeys_stop(kmod_info_t *ki, void *d)
{
    (void)ki; (void)d;
    return KERN_SUCCESS;
}

__attribute__((visibility("default")))
KMOD_EXPLICIT_DECL(org.mifs.MIFSKeys, "1.0.0", MIFSKeys_start, MIFSKeys_stop)

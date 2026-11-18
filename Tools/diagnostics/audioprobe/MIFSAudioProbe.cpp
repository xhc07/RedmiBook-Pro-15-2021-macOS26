// MIFSAudioProbe: 只读探测显示音频可用性
//   1) 匹配 HDA 控制器（8086:A0C8）→ 读 STATESTS + 各 codec 的 VendorID
//   2) 匹配 iGPU（8086:9A49）→ dump 显示音频寄存器 0x65000 起
// 只读，不写任何寄存器。
#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>
#include <IOKit/pci/IOPCIDevice.h>
#include <IOKit/IOMemoryDescriptor.h>

#define HDA_GCAP     0x00
#define HDA_VMIN     0x02
#define HDA_VMAJ     0x03
#define HDA_STATESTS 0x0E
#define HDA_IC       0x60
#define HDA_IR       0x64
#define HDA_IRS      0x68

class MIFSAudioProbe : public IOService
{
    OSDeclareDefaultStructors(MIFSAudioProbe)
private:
    IOMemoryMap *fMap;
    volatile UInt32 *fRegs;
    UInt32 fDeviceID;
    bool   fIsHDA;
    UInt32 read32(UInt32 off);
    UInt16 read16(UInt32 off);
    UInt8  read8(UInt32 off);
    void   probeHDA(void);
    void   probeGPU(void);
public:
    virtual bool start(IOService *provider) APPLE_KEXT_OVERRIDE;
    virtual void stop(IOService *provider) APPLE_KEXT_OVERRIDE;
};

OSDefineMetaClassAndStructors(MIFSAudioProbe, IOService)

UInt32 MIFSAudioProbe::read32(UInt32 off)
{
    if (!fRegs) return 0;
    return fRegs[off >> 2];
}
UInt16 MIFSAudioProbe::read16(UInt32 off)
{
    if (!fRegs) return 0;
    volatile UInt16 *p = (volatile UInt16 *)((volatile UInt8 *)fRegs + off);
    return *p;
}
UInt8 MIFSAudioProbe::read8(UInt32 off)
{
    if (!fRegs) return 0;
    volatile UInt8 *p = (volatile UInt8 *)fRegs + off;
    return *p;
}

void MIFSAudioProbe::probeHDA(void)
{
    // 只读：不发送任何 verb、不写任何寄存器
    UInt16 gcap = read16(HDA_GCAP);
    UInt8 vmin = read8(HDA_VMIN), vmaj = read8(HDA_VMAJ);
    UInt16 statests = read16(HDA_STATESTS);
    setProperty("GCAP", gcap, 16);
    setProperty("STATESTS", statests, 16);
    UInt32 ver = ((UInt32)vmaj << 8) | vmin;
    setProperty("HDAVersion", ver, 32);
    if (gcap == 0xFFFF) {
        setProperty("Note", "GCAP=0xFFFF（控制器可能处于 D3 或映射无效）");
    }
}

void MIFSAudioProbe::probeGPU(void)
{
    static const UInt32 kBase = 0x65000;
    UInt32 vals[32];
    for (int i = 0; i < 32; i++) vals[i] = read32(kBase + i * 4);
    setProperty("AudioRegs65000", vals, sizeof(vals));
    UInt32 extra[4] = { read32(0x64000), read32(0x64010), read32(0x64020), read32(0x64030) };
    setProperty("AudioRegs64000", extra, sizeof(extra));
}

bool MIFSAudioProbe::start(IOService *provider)
{
    if (!IOService::start(provider)) return false;
    IOPCIDevice *pci = OSDynamicCast(IOPCIDevice, provider);
    if (!pci) { IOService::stop(provider); return false; }

    // device id 从 config space 读取（0x00 高 16 位）
    fDeviceID = 0;
    {
        UInt32 id = pci->configRead32(0x00);
        fDeviceID = id >> 16;
    }
    fIsHDA = (fDeviceID == 0xA0C8);

    fMap = pci->mapDeviceMemoryWithRegister(kIOPCIConfigBaseAddress0);
    if (!fMap) {
        IOLog("MIFSAudioProbe: map BAR0 失败 (dev=%04x)\n", fDeviceID);
        return true;
    }
    fRegs = (volatile UInt32 *)fMap->getVirtualAddress();

    IOLog("MIFSAudioProbe: dev=0x%04x BAR0=%p %s\n", fDeviceID, (void *)fRegs,
          fIsHDA ? "(HDA)" : "(GPU)");
    setProperty("ProbeDevice", fDeviceID, 32);

    if (fIsHDA) probeHDA(); else probeGPU();

    registerService();
    return true;
}

void MIFSAudioProbe::stop(IOService *provider)
{
    if (fMap) { fMap->release(); fMap = NULL; }
    fRegs = NULL;
    IOService::stop(provider);
}

#include <libkern/OSKextLib.h>
static kern_return_t MIFSAudioProbe_start(kmod_info_t *ki, void *d) { return KERN_SUCCESS; }
static kern_return_t MIFSAudioProbe_stop(kmod_info_t *ki, void *d) { return KERN_SUCCESS; }
__attribute__((visibility("default")))
KMOD_EXPLICIT_DECL(org.mifs.MIFSAudioProbe, "1.0.0", MIFSAudioProbe_start, MIFSAudioProbe_stop)

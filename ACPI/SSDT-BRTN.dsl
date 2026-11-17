// SSDT-BRTN: 让 EC 的亮度键查询真正通知到 macOS 的显示设备
//
// 背景：DSDT 里 _Q16 -> BRTN(0x86)、_Q15 -> BRTN(0x87)，
//       而 BRTN 只对 \_SB.PC00.GFX0.DD1F 发通知，且被 (DIDX & 0x0F0F)==0x0400 挡住。
//       Windows 靠这个通知调亮度；macOS 下该判断不成立，通知从未发出。
// 做法：重命名原方法 _Q15/_Q16 -> XQ15/XQ16（ACPI Patch），
//       本 SSDT 重新定义 _Q15/_Q16：先调用原方法，再直接通知 DD02 与 DD1F。
DefinitionBlock ("", "SSDT", 2, "OC", "BRTN", 0x00000000)
{
    External (_SB_.PC00.LPCB.H_EC, DeviceObj)
    External (_SB_.PC00.LPCB.H_EC.XQ15, MethodObj)
    External (_SB_.PC00.LPCB.H_EC.XQ16, MethodObj)
    External (_SB_.PC00.GFX0.DD02, DeviceObj)
    External (_SB_.PC00.GFX0.DD1F, DeviceObj)

    Scope (\_SB.PC00.LPCB.H_EC)
    {
        // 亮度 + (EC query 0x16)
        Method (_Q16, 0, NotSerialized)
        {
            XQ16 ()
            If (CondRefOf (\_SB.PC00.GFX0.DD02))
            {
                Notify (\_SB.PC00.GFX0.DD02, 0x86)
            }
            If (CondRefOf (\_SB.PC00.GFX0.DD1F))
            {
                Notify (\_SB.PC00.GFX0.DD1F, 0x86)
            }
        }

        // 亮度 - (EC query 0x15)
        Method (_Q15, 0, NotSerialized)
        {
            XQ15 ()
            If (CondRefOf (\_SB.PC00.GFX0.DD02))
            {
                Notify (\_SB.PC00.GFX0.DD02, 0x87)
            }
            If (CondRefOf (\_SB.PC00.GFX0.DD1F))
            {
                Notify (\_SB.PC00.GFX0.DD1F, 0x87)
            }
        }
    }
}

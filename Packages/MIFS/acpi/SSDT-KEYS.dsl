// SSDT-KEYS: 把 Fn+F6/F7/F8 的 EC 查询转发给自建 HKEY 设备
//   _Q2B → Notify(HKEY, 1)   投屏
//   _Q66 → Notify(HKEY, 2)   截图
//   _Q08 → Notify(HKEY, 3)   任务视图
// 配合 MIFSKeys.kext 接收通知并触发动作。
DefinitionBlock ("", "SSDT", 2, "OC", "KEYS", 0x00000001)
{
    External (_SB_.PC00.LPCB.H_EC, DeviceObj)
    External (_SB_.PC00.LPCB.H_EC.XQ2B, MethodObj)
    External (_SB_.PC00.LPCB.H_EC.XQ66, MethodObj)
    External (_SB_.PC00.LPCB.H_EC.XQ08, MethodObj)

    Scope (\_SB)
    {
        Device (HKEY)
        {
            Name (_HID, "MIFS0001")
            Name (_UID, One)
            Name (_STA, 0x0F)
        }
    }

    Scope (\_SB.PC00.LPCB.H_EC)
    {
        Method (_Q2B, 0, NotSerialized)
        {
            XQ2B ()
            Notify (\_SB.HKEY, 1)
        }
        Method (_Q66, 0, NotSerialized)
        {
            XQ66 ()
            Notify (\_SB.HKEY, 2)
        }
        Method (_Q08, 0, NotSerialized)
        {
            XQ08 ()
            Notify (\_SB.HKEY, 3)
        }
    }
}

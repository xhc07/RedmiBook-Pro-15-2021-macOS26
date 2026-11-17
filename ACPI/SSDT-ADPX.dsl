/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260930 (64-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of SSDT-ADPX.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x000000A7 (167)
 *     Revision         0x02
 *     Checksum         0x77
 *     OEM ID           "OC"
 *     OEM Table ID     "ADPX"
 *     OEM Revision     0x00000000 (0)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20260930 (539363632)
 */
DefinitionBlock ("", "SSDT", 2, "OC", "ADPX", 0x00000000)
{
    External (_SB_, DeviceObj)

    OperationRegion (ERMX, SystemMemory, 0xFE0B0300, 0xFF)
    Field (ERMX, ByteAcc, NoLock, Preserve)
    {
        Offset (0x80), 
        ACIN,   1, 
        BTIN,   1, 
        BTST,   4, 
        PWRV,   2
    }

    Scope (\_SB)
    {
        Device (ADPX)
        {
            Name (_HID, "ACPI0003" /* Power Source Device */)  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (0x0F)
            }

            Method (_PSR, 0, NotSerialized)  // _PSR: Power Source
            {
                Return (ACIN) /* \ACIN */
            }

            Method (_PCL, 0, NotSerialized)  // _PCL: Power Consumer List
            {
                Return (Package (0x01)
                {
                    \_SB, 
                })
            }
        }
    }
}


# Unresolved Altium Issues - 2026-07-08

Current active schematic:

```text
EG4S20BG256_CoreBoard_A0_NATIVE.SchDoc
```

Current status:

```text
Compile successful, no errors found.
```

## Current Warnings

These do not block schematic compile or PCB synchronization.

```text
Net SPI_CLK has no driving source (Pin U1-R11, Pin U2-6)
Net SPI_CS has no driving source (Pin U1-T3, Pin U2-1)
Net VIN_5V has no driving source (Pin J1-1, Pin J2-1, Pin U8-3)
VCC_3V3 contains IO Pin and Power Pin objects
```

## Resolved Since 2026-07-07

```text
JTAG_TDO / JTAG_TDI single-pin errors removed.
LED1_B14 / LED2_B15 / LED3_B16 / LED4_C15 single-pin errors removed.
SW1_A9 / SW2_A10 / SW3_B10 / SW4_A11 single-pin errors removed.
ADC_VDDA / FB1 net fixed.
U10-2 no longer blocks compile.
Floating USB_D+ and USB_D- labels removed/fixed.
PCB ECO executed successfully.
```

## Later Cleanup Options

Only do these after PCB placement starts to settle.

```text
SPI_CLK / SPI_CS:
  Can remain as warnings if FPGA/Flash connectivity is verified.
  Optional fix: adjust electrical pin type or place No ERC.

VIN_5V:
  External input net. Optional fix: use appropriate power input symbol or No ERC.

VCC_3V3:
  ERC type warning caused by IO and power pin objects sharing the net.
  Optional fix: review pin electrical types and power symbols.
```

## Next Work

```text
Start PCB component placement in EG4S20_CoreBoard.PcbDoc.
Do not route yet.
Prioritize J1/J2, U1, U2, Y1/Y2, then power and user IO.
```

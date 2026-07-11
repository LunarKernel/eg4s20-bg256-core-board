# Final Report: EG4S20 BG256 Physical Board Reconstruction

[Chinese report](README.md)

Date: July 10, 2026

## Abstract

This project reconstructs an EG4S20 FPGA teaching board in Altium Designer using the supplied schematic material, integrated component library, board documentation, pin map, and photographs of both sides of the physical board.

An earlier design contained only 24 physical components. It was useful for validating the schematic, ECO, placement, routing, and DRC workflow, but it did not reproduce the display, keypad, eight slide switches, LEDs, connectors, or rear-side support circuitry of the physical board. The complete project in `PCB_Project` has therefore replaced that simplified design as the only supported project entry point.

Final inspection found an extra FPGA footprint. The error originated in the multipart FPGA schematic symbol: Parts 1, 2, 3, 5, and 6 used `U7`, while Part 4 used `U?`. Altium consequently interpreted one logical FPGA as two physical components and generated both `U7` and `U?` FBGA256 footprints. The correct repair is to assign Part 4 to `U7` in the schematic and synchronize the PCB through ECO. Deleting only the PCB footprint would not remove the source of the error.

## Final Project Entry Point

```text
PCB_Project/PCB_Project.PrjPcb
```

Project files:

- `PCB_Project/Sheet1.SchDoc`: complete single-sheet schematic;
- `PCB_Project/PCB1.PcbDoc`: 100 mm by 68 mm two-sided PCB;
- `PCB_Project/PCB_Project.BomDoc`: BOM configuration;
- the integrated component library stored beside the project files.

Altium Designer 25.8.1 or a compatible version is recommended. Open the project entry point instead of loading the schematic or PCB as a free document.

## 1. Course Requirements and Source Material

The course assignment requires an independently completed schematic and PCB design. The repository retains:

- [the course plan, pin map, and physical-board photographs](references/%E5%8F%B2%E4%B8%87%E5%91%A8%E5%B0%8F%E5%AD%A6%E6%9C%9F%E4%B8%8A%E6%9C%BA2026%20%E7%BB%99%E5%AD%A6%E7%94%9F.doc);
- [the EG4S20BG256 core-board schematic](references/EG4S20BG256%E6%A0%B8%E5%BF%83%E6%9D%BF%20-%202023.pdf);
- [the board and development-tool introduction](references/%E5%A4%A7%E6%8B%87%E6%8C%87%E5%AE%89%E8%B7%AFEG4S20%20-%20%E6%9D%BF%E5%8D%A1%E5%92%8C%E5%BC%80%E5%8F%91%E5%B7%A5%E5%85%B7%E5%85%A5%E9%97%A8.pdf).

The front photograph shows one EG4S20 FPGA, a four-digit display, a 4-by-4 key matrix, eight slide switches, LEDs, a buzzer, and several edge connectors. The rear photograph shows power, configuration, and auxiliary control circuitry. The photographs establish the physical population and placement reference; electrical connectivity must still be verified from the schematic and Altium project.

## 2. Project Evolution

### 2.1 Legacy Simplified Design

The legacy design used an A0 schematic and a 24-component PCB. It completed an earlier compile, ECO, autorouting, and DRC workflow, but its component population was much smaller than the physical board.

The legacy values of 24 components and zero DRC violations apply only to that superseded PCB. They are not validation results for the complete reconstruction. The old files are available through Git history rather than being duplicated in the final source tree.

### 2.2 Complete Physical Reconstruction

The final baseline is the project rebuilt from the physical-board photographs:

- one complete schematic sheet;
- a 100 mm by 68 mm outline;
- Top and Bottom copper layers;
- components placed on both sides;
- complete FPGA, display, keypad, switch, LED, buzzer, USB, JTAG, UART, power, and expansion-interface sections.

Static analysis before repair found 244 PCB components: 148 on the top side and 96 on the bottom side. The PCB data also contained 316 nets, 1,411 pads, 4,943 tracks, and 13 vias.

After ECO and the final save, static analysis found 243 components: 147 on the top side and 96 on the bottom side. The current data contains 316 nets, 1,155 pads, 4,953 tracks, 13 vias, and 557 connection records; the latest DRC reports 550 unrouted connections. The reduction of 256 pads exactly matches the removed second FBGA256 footprint.

## 3. Functional Blocks

| Block | Main content |
|---|---|
| FPGA core | EG4S20BG256, multipart schematic symbol, FBGA256 footprint |
| Clock and configuration | Main clock, auxiliary crystal, SPI flash, configuration button |
| User input | Eight slide switches, 4-by-4 keypad, reset button |
| User output | LEDs, four-digit display, buzzer |
| Communication and debug | USB, UART, JTAG, and protection devices |
| Power | Input protection, regulators, inductors, diodes, filtering, indicators |
| Expansion | Edge headers and auxiliary connectors |

The top side primarily carries the FPGA, display, keypad, switches, LEDs, buzzer, and user connectors. The bottom side primarily carries power, configuration, and auxiliary circuitry.

## 4. Root Cause and Repair of the Extra FPGA

### 4.1 Symptom

Before repair, the PCB contained two FBGA256 components:

- `U7 / FBGA256`;
- `U? / FBGA256`.

The physical board contains only one EG4S20 FPGA, so the second footprint was an engineering-data error.

### 4.2 Root Cause

The placed EG4S20 symbol uses six schematic parts:

- Parts 1, 2, 3, 5, and 6: `U7`;
- Part 4, Unique ID `NZRUKKZJ`: `U?`.

The inconsistent designator caused Altium to interpret Part 4 as a separate physical device and create an additional footprint.

### 4.3 Repair Method

1. Change FPGA Part 4 from `U?` to `U7` in `Sheet1.SchDoc`.
2. Save and validate or compile the project.
3. Run `Design -> Update PCB Document PCB1.PcbDoc`.
4. Validate the ECO changes before executing every approved component, net, and pin update.
5. Confirm that the orphaned `U?` is removed and that the Part 4 pad nets are assigned to `U7`.
6. Compare the schematic and PCB again; no design differences should remain.
7. Run DRC again and record the actual result.

Deleting `U?` directly from the PCB would discard the Part 4 net assignment and allow the footprint to return during the next ECO. It is not an acceptable final repair.

## 5. Final Verification Record

| Check | Acceptance criterion | Current record |
|---|---|---|
| FPGA schematic designators | All six parts use `U7` | Passed; Parts 1 through 6 are `U7` |
| FPGA footprints | Exactly one `U7 / FBGA256` | Passed; static analysis found one |
| Unannotated FPGA | No second `U? / FBGA256` | Passed; exact PCB match count for `U?` is zero |
| Total physical components | 243 | Passed; 244 before repair and 243 after repair |
| Top and bottom counts | 147 and 96 | Passed; 148 and 96 before repair |
| Project validation or ERC | Record the complete-project result | 35 errors and 37 warnings, mainly existing single-pin-net issues |
| ECO synchronization | Component, pin, and net changes completed | Passed; the second comparison had no Component, Pin, or Net changes |
| Nonfunctional ECO proposals | Keep this repair narrowly scoped | One automatic component-class removal and ten automatic supply-rule additions were not executed |
| DRC | Actual result for the reconstructed PCB | 2,621 active violations and 12 documented waivers; see the category breakdown below |
| Project portability | Opens from the final path without missing files or libraries | Passed; every project document and the integrated library loaded |

The complete DRC was run in Altium Designer 25.8.1 with the stop limit raised to 10,000 so that the default 500-violation limit did not truncate the result. The pre-debug result was 2,640 violations. Comparison with the front and rear photographs in the course document showed that P2/P5 are populated front-side connectors while P3/P6 are corresponding unpopulated rear-side alternate solder footprints. Removing or moving either set would reduce fidelity to the physical board. The layout and global rules were therefore left unchanged, and only the twelve confirmed overlaps between these four designators were waived with a recorded reason.

Without moving any component, seven endpoints confirmed by net name and pad identity were routed: the local and U7-P13 sections of DONE, the three local sections and U7-T2 section of PROGRAM B, and INIT B to U7-R3. A complete DRC was rerun after every change, with no new Clearance, Short-Circuit, or Hole To Hole violations.

The current result is 2,621 active violations and 12 documented waivers:

- Clearance: 0 active and 4 waived;
- Short-Circuit: 0 active and 6 waived;
- Un-Routed Net: 550;
- Hole To Hole Clearance: 0 active and 2 waived;
- Minimum Solder Mask Sliver: 227;
- Silk To Solder Mask: 1,442;
- Silk To Silk: 402.

The waiver reason is stored in the PCB file, survives a complete DRC rerun, and remains visible in the generated report under Waived Violations. All twelve known connector-overlap findings use exact waivers; no global rule was weakened. The reconstructed PCB still requires routing, silkscreen, and manufacturing-clearance cleanup and is not a DRC-clean production release.

## 6. Repository Layout

```text
SummerProject/
|-- README.md
|-- README_EN.md
|-- GIT_WORKFLOW.md
|-- PCB_Project/
|   |-- PCB_Project.PrjPcb
|   |-- Sheet1.SchDoc
|   |-- PCB1.PcbDoc
|   |-- PCB_Project.BomDoc
|   `-- integrated component library
`-- references/
    |-- course plan and physical-board photographs
    |-- core-board schematic
    `-- board and development-tool introduction
```

Timestamp wrappers, previews, history, logs, locks, backups, and regenerable outputs are excluded. The repository contains one copy of the binary Altium project, shared by both language versions of the report.

## 7. Opening and Continuing the Project

1. Clone the repository. Git LFS is not required; the largest file is an integrated library of approximately 40 MB.
2. Start Altium Designer.
3. Open `PCB_Project/PCB_Project.PrjPcb`.
4. Confirm in the Projects panel that the schematic, PCB, BOM document, and library are not missing.
5. Create a branch before editing. Do not edit the same binary Altium file concurrently on two computers.
6. Save and close Altium before committing and pushing changes.

## 8. Validation Boundary

The repository evidence establishes that:

- the final project files and required library are colocated;
- the board outline is 100 mm by 68 mm;
- the PCB is a two-layer design with components on both sides;
- the physical board contains only one FPGA;
- the duplicate FPGA originated from an inconsistent multipart designator;
- the correct repair must begin in the schematic and propagate through ECO.

Without additional generated files and test records, this report does not claim that:

- Gerber, NC Drill, or assembly production files have been generated and reviewed;
- USB differential impedance or signal integrity has been verified;
- a board has been assembled, powered, or functionally tested;
- the design satisfies the production rules of a specific manufacturer.

## 9. Conclusion

The project moved from a simplified workflow-validation design to a complete two-sided reconstruction based on the physical board. Final inspection identified a duplicate FPGA footprint caused by inconsistent designators in a multipart schematic symbol. The selected root-cause repair changes the schematic designator and then synchronizes the PCB through ECO.

The final component recount and ECO verification are complete: all six FPGA schematic parts are `U7`, the PCB contains one `U7 / FBGA256`, and the component count is 243. The remaining Validate/ERC and DRC issues are recorded as actual results rather than presented as zero-error results. The single Altium project and the content-equivalent Chinese and English reports form the repository deliverable.

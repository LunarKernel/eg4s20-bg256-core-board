# EG4S20 BG256 实物复刻 PCB 项目最终报告

[English report](README_EN.md)

日期：2026-07-10

## 摘要

本项目依据课程提供的 EG4S20BG256 原理图资料、Altium 集成元器件库、板卡说明、引脚图以及实物板正反面照片，在 Altium Designer 中完成 EG4S20 FPGA 教学板的原理图与双面 PCB 复刻。

项目早期曾建立一套仅含 24 个物理元器件的简化工程，用于验证原理图整理、ECO、布局布线和 DRC 流程。该工程没有完整覆盖实物板上的数码管、矩阵按键、八位拨码开关、LED、连接器和背面辅助电路，因此已由本仓库中的完整 `PCB_Project` 替换，不再作为最终入口。

最终检查发现 PCB 中多出一颗 FPGA。根因不是布局阶段误放，而是多分部 FPGA 原理图符号的 Designator 不一致：Part 1、2、3、5、6 使用 `U7`，Part 4 错误使用 `U?`。Altium 因此把同一颗逻辑器件识别为两个物理器件，并生成 `U7` 和 `U?` 两个 FBGA256 封装。正确修复方式是先在原理图中把 Part 4 归并到 `U7`，再通过 ECO 同步 PCB，而不是只在 PCB 中手工删除封装。

## 最终工程入口

```text
PCB_Project/PCB_Project.PrjPcb
```

工程文件：

- `PCB_Project/Sheet1.SchDoc`：完整单页原理图；
- `PCB_Project/PCB1.PcbDoc`：100 mm × 68 mm 双面 PCB；
- `PCB_Project/PCB_Project.BomDoc`：BOM 配置；
- `PCB_Project/ANLOGIC开发板封装库.IntLib`：工程所需集成库。

建议使用 Altium Designer 25.8.1 或兼容版本打开工程入口，不要单独打开 SchDoc/PcbDoc 作为自由文档。

## 1. 课程要求与参考资料

课程任务要求独立完成 SCH 和 PCB 设计。仓库保留以下原始资料：

- [课程计划、引脚图及实物板正反面照片](references/史万周小学期上机2026%20给学生.doc)；
- [EG4S20BG256 核心板原理图](references/EG4S20BG256核心板%20-%202023.pdf)；
- [板卡和开发工具入门资料](references/大拇指安路EG4S20%20-%20板卡和开发工具入门.pdf)。

实物正面照片显示一颗 EG4S20 FPGA、四位数码管、4×4 矩阵按键、八位拨码开关、LED、蜂鸣器和多组板边接口；背面照片显示电源、配置及辅助控制电路。照片用于确认器件数量、板面归属和相对位置，电气连接仍以原理图和 Altium 工程为准。

## 2. 工程演进

### 2.1 旧简化工程

旧版采用 A0 主原理图和 24 元器件 PCB，完成过编译、ECO、自动布线及 DRC 流程验证。它适合说明设计流程，但元器件规模明显小于实物板。

旧版中的“24 个组件”和“DRC 违规为 0”只适用于被替换的旧 PCB，不能作为本次完整实物复刻版的验证结果。旧文件不再保留在当前目录中，需要时可从 Git 历史恢复。

### 2.2 完整实物复刻工程

最终基线来自按实物照片重新排版的 `PCB_Project`：

- 单页完整原理图；
- 100 mm × 68 mm 板框；
- Top/Bottom 两层铜；
- 正反两面器件布局；
- FPGA、显示、按键、拨码开关、LED、蜂鸣器、USB/JTAG/UART、电源和扩展接口等完整功能块。

修复前静态解析结果为 244 个 PCB Component，其中 Top 148、Bottom 96；PCB 数据包含 316 个网络、1411 个焊盘、4943 条走线和 13 个过孔。

完成 ECO 并保存后的最终解析结果为 243 个 Component，其中 Top 147、Bottom 96；数据包含 316 个网络、1155 个焊盘、4928 条走线、13 个过孔和 557 个未布线连接。焊盘减少 256 个，恰好对应被删除的第二个 FBGA256 封装。

## 3. 主要功能模块

| 模块 | 主要内容 |
|---|---|
| FPGA 核心 | EG4S20BG256，多分部原理图符号，FBGA256 封装 |
| 时钟与配置 | 主时钟、辅助晶振、SPI Flash、配置按键 |
| 用户输入 | 8 位拨码开关、4×4 矩阵按键、复位按键 |
| 用户输出 | LED、四位数码管、蜂鸣器 |
| 通信与调试 | USB、UART、JTAG 及保护器件 |
| 电源 | 输入保护、稳压、电感、二极管、滤波和电源指示 |
| 扩展接口 | 板边排针和辅助连接器 |

PCB 正面主要承载 FPGA、显示、按键、拨码开关、LED、蜂鸣器和用户接口；背面主要承载电源、配置和辅助控制电路。

## 4. 多余 FPGA 的根因与修复

### 4.1 问题表现

修复前 PCB 同时存在：

- `U7 / FBGA256`；
- `U? / FBGA256`。

实物板正面只有一颗 EG4S20 FPGA，因此第二个封装是工程数据错误。

### 4.2 根因

EG4S20 原理图符号由六个已放置分部组成：

- Part 1、2、3、5、6：`U7`；
- Part 4（Unique ID `NZRUKKZJ`）：`U?`。

Designator 不一致使 Altium 将 Part 4 解释为另一颗物理器件，并为其生成额外封装。

### 4.3 修复原则

1. 在 `Sheet1.SchDoc` 中将 FPGA Part 4 从 `U?` 修正为 `U7`；
2. 保存并 Validate/Compile 工程；
3. 执行 `Design → Update PCB Document PCB1.PcbDoc`；
4. 在 ECO 中先 Validate Changes，再执行全部通过的 component/net/pin 变更；
5. 确认多余的 `U?` 被删除，Part 4 的焊盘网络归并到 `U7`；
6. 再次比较原理图和 PCB，应无待同步差异；
7. 重新运行 DRC 并记录真实结果。

直接删除 PCB 上的 `U?` 会丢失 Part 4 的网络归属，且下一次 ECO 还会重新生成，因此不能作为最终修复。

## 5. 最终验证记录

| 检查项目 | 验收条件 | 当前记录 |
|---|---|---|
| FPGA 原理图标号 | 六个分部均为 `U7` | 通过；Part 1-6 全部为 `U7` |
| PCB FPGA 数量 | 仅一颗 `U7 / FBGA256` | 通过；静态解析仅 1 颗 |
| 未编号 FPGA | 不存在第二颗 `U? / FBGA256` | 通过；PCB 中精确匹配 `U?` 为 0 |
| 物理元器件总数 | 243 | 通过；修复前 244，修复后 243 |
| Top / Bottom 数量 | 147 / 96 | 通过；修复前 148 / 96 |
| Project Validate / ERC | 记录完整工程真实结果 | 35 个错误、37 个警告，主要为单引脚网络等既有原理图问题 |
| ECO | 器件、引脚、网络同步完成 | 通过；再次比较无 Component/Pin/Net 变更 |
| ECO 非功能项 | 不扩大本次修复范围 | 未执行 1 个自动元件类移除和 10 个自动电源规则新增 |
| DRC | 记录新工程真实违规数 | 2640 条；详见下方分类，未通过量产验收 |
| 工程可移植性 | 从最终路径打开，无缺失文档或库 | 通过；全部工程文档和 IntLib 可加载 |

完整 DRC 在 Altium Designer 25.8.1 中运行，检查上限提高到 10000，未因默认 500 条上限提前终止。结果为 2640 条：

- Clearance：4；
- Short-Circuit：6；
- Un-Routed Net：557；
- Hole To Hole Clearance：2；
- Minimum Solder Mask Sliver：227；
- Silk To Solder Mask：1442；
- Silk To Silk：402。

这组结果说明重复 FPGA 已修复，但完整复刻板仍需要后续布线、丝印与工艺间距整理，不能作为可直接投板的 DRC-clean 版本。

## 6. 仓库结构

```text
SummerProject/
├─ README.md
├─ README_EN.md
├─ GIT_WORKFLOW.md
├─ PCB_Project/
│  ├─ PCB_Project.PrjPcb
│  ├─ Sheet1.SchDoc
│  ├─ PCB1.PcbDoc
│  ├─ PCB_Project.BomDoc
│  └─ ANLOGIC开发板封装库.IntLib
└─ references/
   ├─ 史万周小学期上机2026 给学生.doc
   ├─ EG4S20BG256核心板 - 2023.pdf
   └─ 大拇指安路EG4S20 - 板卡和开发工具入门.pdf
```

时间戳包装目录、预览、History、日志、锁文件、备份和可再生成输出不进入最终仓库。二进制工程只保留一套，中英文报告共同引用该工程。

## 7. 使用方法

1. 克隆仓库并确认 Git LFS 不是必需项；当前最大文件为约 40 MB 的 IntLib。
2. 启动 Altium Designer。
3. 打开 `PCB_Project/PCB_Project.PrjPcb`。
4. 在 Projects 面板确认原理图、PCB、BomDoc 和 IntLib 均无 Missing。
5. 修改前先创建分支；同一时间不要在两台设备编辑同一个二进制 Altium 文件。
6. 修改后保存并关闭 Altium，再提交和推送。

## 8. 验证边界

本仓库能够证明：

- 最终工程和依赖库已集中归档；
- 板框为 100 mm × 68 mm；
- PCB 为双层且正反面均有器件；
- 实物图中只有一颗 FPGA；
- 重复 FPGA 来自多分部符号 Designator 不一致；
- 正确修复必须从原理图出发并通过 ECO 同步。

除非后续另有实际输出和测试记录，本报告不声明：

- 已生成并复核 Gerber、NC Drill 或贴片生产文件；
- 已完成 USB 差分阻抗或信号完整性验证；
- 已完成实物焊接、上电或功能测试；
- 已满足特定板厂的量产工艺要求。

## 9. 总结

项目最终从流程验证型简化工程切换到依据实物板重新排版的完整双面工程。最终阶段定位到多分部 FPGA 标号不一致造成的重复封装，并确定采用“修正原理图 Designator，再通过 ECO 同步 PCB”的根因修复路径。

最终组件复点和 ECO 验证已经完成：原理图六个 FPGA 分部统一为 `U7`，PCB 仅保留一颗 `U7 / FBGA256`，组件总数为 243。ERC/Validate 和 DRC 的遗留问题已按实际结果记录，未被包装成“零错误”。本仓库中的唯一 Altium 工程以及内容等价的中英文报告共同构成项目交付。

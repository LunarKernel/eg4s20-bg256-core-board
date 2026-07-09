# EG4S20BG256 暑期项目交付说明

## 工程入口

- `EG4S20_SummerProject.PrjPcb`
- `EG4S20BG256_CoreBoard_A0_NATIVE.SchDoc`（当前主原理图）
- `EG4S20_CoreBoard.PcbDoc`

## 已录入的 FPGA 管脚映射

- 拨码开关：A9、A10、B10、A11、A12、B12、A13、A14
- LED：B14、B15、B16、C15、C16、E13、E16、F16
- 数码管段选：A4、A6、B8、E8、A7、B5、A8、C8
- 数码管位选：C9、B6、A5、A3
- 蜂鸣器：H11
- 时钟：R7
- 矩阵键盘列：F10、C11、D11、E11
- 矩阵键盘行：E10、C10、F9、D9
- UART：RXD=F12，TXD=D12

## PCB 内容

- 已建立 PCB 文档和 102.2 mm x 71.8 mm 板框。
- 已关联主要封装库，当前工程可从 PCB Library Documents 中找到所需封装。
- 已参考实物板正反面图片完成一轮器件布局。
- 已按 5 mil 间距、5/6 mil 走线、16/12 mil 过孔规则完成一轮布线修正。
- 已补齐剩余 GND/JTAG 连接，清理天线线头、丝印压盘和默认重复丝印。
- 已运行最终 DRC：Violations Detected = 0，Waived Violations = 0。
- 已运行板框边界审计：primitive 越界 0，component 越界 0。
- 过程备份已集中归档到 `backups/2026-07-09/`，不作为正式交付文件。

辅助脚本：

- `../PCB_AutoLayout_Route.PrjScr`
- `../PCB_AutoLayout_Route.pas`
- `../PCB_Run_DRC.PrjScr`
- `../PCB_Boundary_Audit.PrjScr`

阶段总结：

- `../../docs/阶段性总结_2026-07-09_PCB布局布线.md`
- `../../docs/阶段性总结_2026-07-09_AD控制验证.md`

## 提交前检查

- 当前 PCB 已完成最终 DRC 和板框边界审计。
- 出板前若继续改 PCB，必须重新运行 `Tools > Design Rule Check`，重点确认间距、短路、未连接、孔径、板框外对象、丝印重叠。
- USB_D+ / USB_D- 当前未按严格差分阻抗/等长规则优化；若课程要求接近可制造产品，需要单独人工检查。

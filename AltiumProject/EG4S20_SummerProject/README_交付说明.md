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

- 已建立 PCB 文档和 100 mm x 68 mm 板框。
- 已关联主要封装库，当前工程可从 PCB Library Documents 中找到所需封装。
- 已参考实物板正反面图片完成一轮器件布局。
- 已按 5 mil 间距、5/6 mil 走线、16/12 mil 过孔规则完成一轮自动布线。
- 自动布线后剩余的两段实际 GND 短连接已用顶层 6 mil 线补齐。
- 过程备份已集中归档到 `backups/2026-07-09/`，不作为正式交付文件。

辅助脚本：

- `../PCB_AutoLayout_Route.PrjScr`
- `../PCB_AutoLayout_Route.pas`

阶段总结：

- `../../docs/阶段性总结_2026-07-09_PCB布局布线.md`

## 提交前检查

- 当前 PCB 已完成一轮布局布线，但尚未完成正式出板前 DRC。
- 出板前必须运行 `Tools > Design Rule Check`，重点确认间距、短路、未连接、孔径、板框外对象、丝印重叠。
- 建议继续完成 GND Polygon Pour，再重新 repour 和 DRC。
- USB_D+ / USB_D- 当前未按严格差分阻抗/等长规则优化；若课程要求接近可制造产品，需要单独人工检查。

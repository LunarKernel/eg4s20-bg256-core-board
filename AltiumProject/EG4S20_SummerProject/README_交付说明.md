# EG4S20BG256 暑期项目交付说明

## 工程入口

- `EG4S20_SummerProject.PrjPcb`
- `01_Connectors.SchDoc`
- `02_FPGA_Clock_Flash.SchDoc`
- `03_USB_JTAG.SchDoc`
- `04_UserIO.SchDoc`
- `05_Power.SchDoc`
- `EG4S20_CoreBoard.PcbDoc`
- `EG4S20_CoreBoard_recovery.PcbDoc`（恢复副本）

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

- 已建立 PCB 文档和板框。
- 已生成 EG4S20BG256 的 16×16、共 256 个顶层 BGA 焊盘及顶层丝印外框。
- 原始 `EG4S20_CoreBoard.PcbDoc` 已纳入工程；恢复副本保留当前编辑状态。

## 提交前检查

- 当前原理图为按参考资料拆分的结构化草稿，尚未完成全部导线、器件参数和电气规则收敛。
- PCB 尚未完成器件布局、网络同步、布线、铺铜和 DRC。
- 打开工程后应检查缺失的封装/模型警告，并按实物板尺寸校正板框。

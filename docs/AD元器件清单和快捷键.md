# AD 元器件搜索清单和常用快捷键

## 元器件搜索清单

| PDF 里出现的器件/模块 | Altium Designer 中搜索名 |
|---|---|
| FPGA 主芯片 EG4S20BG256 | `EG4S20BG256` |
| 板载 SDRAM | 不单独放，集成在 `EG4S20BG256` |
| USB 接口 / Micro USB | `105017-0001` |
| USB ESD 保护 | `TPD4E001DBVR` |
| USB 转 UART | `CH340G` |
| USB-JTAG 控制器 | `GD32F150U` |
| 配置 Flash | `W25Q80BLSNIG` |
| 50 MHz / 主时钟晶振 | 优先搜 `7X-20.000MBB-T_1`，没有就搜 `ABLS-8.000MHZ-B4-T` 后改参数 |
| 低频/外部晶振 | `ABLS-8.000MHZ-B4-T` |
| 8 个 LED | `4LED-ANODE` |
| 四位七段数码管 | 库里未稳定确认，先用文字/网络标签，后续搜 `7SEG` / `DIGITRON` / `LED` |
| 蜂鸣器 | `BUZZER_EFBAA14D001` |
| 拨码开关 SW0-SW7 | 库里未稳定确认，先用文字/网络标签，后续搜 `SW` / `DIP` |
| 4x4 矩阵按键 | 库里未稳定确认，先用文字/网络标签，后续搜 `KEY` / `SW` |
| IO 扩展排针 | 搜 `HEADER` / `CONN` / `PIN`，按实际针数替换 |
| R-2R DAC 电阻网络 | `CRCW04021K00FKED` 或搜 `RES` |
| 普通电阻 | `CRCW04021K00FKED`，再改阻值 |
| 普通 0.1uF 电容 | `C1005X7R1H104M_1` |
| 普通贴片电容/大电容 | `GRM21BC81C475KA88L`，再改容值 |
| 3.3V 线性稳压 | `AMS1117` |
| DC-DC 稳压 | `RT8097` |
| 肖特基二极管 | `B340B-13-F` |
| 磁珠 | `BLM21BD121SN1D` |
| TL431 基准/反馈 | `TL431AIDBZ` |
| ADC 输入 | 不单独放，使用 `EG4S20BG256` 对应 ADC 引脚 |
| UART RX/TX 网络 | Net Label：`UART_RXD_F12` / `UART_TXD_D12` |
| JTAG 网络 | Net Label：`JTAG_TCK` / `JTAG_TMS` / `JTAG_TDI` / `JTAG_TDO` |
| SPI Flash 网络 | Net Label：`SPI_CS` / `SPI_CLK` / `SPI_MOSI` / `SPI_MISO` |
| 电源网络 | Power Port / Net Label：`VIN_5V` / `VCC_3V3` / `VCC_1V2` / `GND` |

## 常用快捷键

| 操作 | 快捷键 / 操作方式 |
|---|---|
| 全图显示 | `V` 然后 `F` |
| 取消当前命令 | `Esc` |
| 保存 | `Ctrl+S` |
| 撤销 | `Ctrl+Z` |
| 删除选中对象 | `Delete` |
| 移动物体时旋转 | `Space` |
| 放导线 | `P` 然后 `W` |
| 放 Net Label | `P` 然后 `N` |
| 放器件 | `P` 然后 `P` |
| 平移视图 | 按住鼠标右键拖动 |
| 缩放 | 鼠标滚轮 |

## 使用建议

先用这份表把 A0 草图里的文字块替换成正式器件。库里搜不到的器件不要卡住，先保留文字块和 Net Label，等主干原理图完成后再补封装。

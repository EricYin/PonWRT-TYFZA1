# PT1570-R10 适配规格说明

本文件记录天翼 PT1570-R10 在 PonWRT 上的适配规格、与 TYFZA1 的硬件差异、
全部改动点以及实测结论。对应分支 `pt1570`。

---

## 1. 硬件规格

| 项目 | PT1570-R10 | TYFZA1 |
| --- | --- | --- |
| SoC | Realtek RTL9617C，4× Cortex-A55 | 同 |
| 内存 / 存储 | 512 MB / 256 MB NAND | 同 |
| NAND 型号 | **XT26G02C**（0x0b/0x12，2 Gbit） | 其他 |
| PON | **XG-PON（10G/2.5G）** | 10G-EPON |
| 光模块 | **UX3361**（MSA BOSA，自带 EEPROM） | Semtech 系列 |
| 无线 | RTL8852BE（5G）+ RTL8852BE（2.4G） | 同 |
| 有线 | 4× GE，PHY 顺序与面板**相反** | 4× GE |
| 前面板按键 | 3 个（复位 / 灯光 / 无线） | 1 个（灯光） |
| 指示灯 | 13 个丝印位 + 1 个无丝印 = 14 个 | 12 个 |
| 外壳 | 外部散热板（可拆） | — |

---

## 2. 与 TYFZA1 的关键差异

### 2.1 UBI 卷编号整体前移一位

PT1570 的 UBI 布局**没有 `ubi_fpga` 卷**，导致其后所有卷号减一：

| 卷 | TYFZA1 | PT1570 |
| --- | --- | --- |
| ubi_Config | ubi0_0 | ubi0_0 |
| ubi_DTB0 | ubi0_1 | ubi0_1 |
| ubi_k0 | ubi0_2 | ubi0_2 |
| ubi_r0 | ubi0_3 | ubi0_3 |
| ubi_DTB1 | ubi0_4 | ubi0_4 |
| ubi_k1 | ubi0_5 | ubi0_5 |
| ubi_r1 | ubi0_6 | ubi0_6 |
| **ubi_fpga** | **ubi0_7** | **不存在** |
| ubi_framework1 | ubi0_8 | **ubi0_7** |
| ubi_framework2 | ubi0_9 | **ubi0_8** |
| ubi_apps | ubi0_10 | **ubi0_9** |
| rootfs_data | ubi0_11 | **ubi0_11**（运行时分配） |

**后果**：FIT 启动脚本里 `ubiblock` 设备号写死成 `0_3/0_6` 才对得上
（上游写的是 `0_3/0_6`，恰好正确；中间曾误改成 `0_4` 导致无法启动）。

### 2.2 按键在 bank3，不在 bank2

原厂 FDT 写的是：

```dts
btn_led  = <&gpio2 7 GPIO_ACTIVE_LOW>;
btn_wifi = <&gpio2 3 GPIO_ACTIVE_LOW>;
```

按 `bank@2` 的 `gpio-ranges` 换算会得到全局 71 / 67，**但这是错的**。
该 phandle 实际解析到 `bank@3`（节点名与 ranges 索引错位）。

**实测方法**（U-Boot 里读原始输入寄存器，逐键按压）：

```
md 0x4f43292c0 0x30        # dump 整个 GPIO 块
```

```
idx  bank2(0x310)  bank3(0x334)   b2[3] b2[7] b3[3] b3[7]
  6  00000000      00000088         0     0     1     1
  7  00000000      00000080         0     0     0     1   ← 灯光按下
  9  00000000      00000008         0     0     1     0   ← 无线按下
```

**正确映射**：

| 按键 | bank | pin | 全局 GPIO |
| --- | --- | --- | --- |
| 复位 | bank0 | 8 | **8** |
| 灯光 | bank3 | 3 | **99** |
| 无线 | bank3 | 7 | **103** |

### 2.3 LAN 口顺序与面板相反

物理 port 0 驱动面板最右侧的 LAN4：

```
面板 LAN1 ← lan4 ← LED_EPHY3 ← GPIO0 ← PHY 地址 4 ← NI port 3
面板 LAN4 ← lan1 ← LED_EPHY0 ← GPIO4 ← PHY 地址 1 ← NI port 0
```

修正方式：`realtek,lan-phys` 反转为 `<&phy3 &phy2 &phy1 &phy0>`，
同时 LED 的 `lan_devs` 反转为 `lan4 lan3 lan2 lan1`。

### 2.4 光模块是 MSA BOSA，不是 Semtech

UX3361 用标准 MSA（SFF-8472）布局，**自带 EEPROM 校准**：

- 型号 / 厂商在 **A0 页**（I2C `0x50`）
- DDM 在 **A2 页**（I2C `0x51`，偏移 `0x60` 起）

而 PonWRT 的 `rtl9617c-bosa.c` 是按 **Semtech GN25L95/98、GN28L95/96/97**
写的：用 `0x7f` 做页选择、读 `0x80/0x85/0x86` 取 identity。

**结果**：`identity=ff/ff/ff`、`error=-19`（-ENODEV）、`configured=0`。

**但这不影响光模块实际工作**——它自己用 EEPROM 里的校准参数。
判断光模块是否工作要看 DDM：

```
bias_raw=3911  tx_power_raw=22490  rx_power_raw=137     ← 全都有值
```

**处理**：`identify()` 失败后先做存活探测，再决定降级还是报错（见 §3.3）。

---

## 3. 改动清单

### 3.1 设备树

| 文件 | 改动 |
| --- | --- |
| `rtl9617c-tyfza1-ni.dts` | `realtek,lan-phys` 反转为 `<&phy3 &phy2 &phy1 &phy0>` |
| `rtl9617c-tyfza1-leds.dtsi` | 三个按键：`btn-reset`=8、`btn-led`=99、`btn-wifi`=103 |
| `rtl9617c-tyfza1-ubi.dts` | 保持上游，`ubiblock` 用 `0_3/0_6` |

### 3.2 内核配置

| 项 | 说明 |
| --- | --- |
| `CONFIG_INPUT=y` | 上游完全没编 INPUT，导致 `gpio-button-hotplug` 无法注册按键 |
| `CONFIG_INPUT_EVDEV=y` | 便于调试时用 `evtest` 观察 |

> 注意：`gpio-button-hotplug` 实际**不使用 INPUT 子系统**（从模块字符串可确认
> 没有 `input_allocate_device`），它是轮询 GPIO 后发 uevent。加 INPUT 是为了
> 满足模块的符号依赖，不是按键生效的必要条件。

### 3.3 BOSA 驱动（`rtl9617c-bosa.c`）

`identify()` 失败后**不直接降级**，先做存活探测：

```c
ret = rtl_bosa_identify(bosa);
if (ret) {
    rtl_bosa_write(bosa, 0x7f, page);      /* identify() 会把页留在 0xff/2 */

    for (i = 0; i < 4; i++) {              /* 读 A2 页 DDM: 温度/电压 */
        if (rtl_bosa_read(bosa, 0x60 + i, &probe[i]))
            break;
        if (probe[i] != 0xff)
            alive = true;
    }

    if (!alive) {                           /* 全 0xff = 模块缺失/无响应 */
        dev_err(..., "module missing or unresponsive");
        ret = -ENODEV;
        goto restore;
    }
    /* 有响应 = 带 EEPROM 的 MSA 器件，跳过主机侧校准 */
    bosa->model = 0;
    bosa->eeprom = true;
    bosa->configured = true;
    ret = 0;
}
```

**判据依据**：A2 页温度/电压是真实测量值，不会恰好四个字节全 `0xff`；
I2C 总线悬空时读回就是全 `0xff`。这样真实故障仍会报错。

### 3.4 PON 初始化脚本（`/etc/init.d/pon`）

| 阶段 | 改动 |
| --- | --- |
| `bosa` | `printf '1' > $device/bosa` 改为 `\|\| true`，BOSA 失败不中止整个初始化 |
| `onu_mac` | 为空时回退到 `/tmp/tyfza1-factory/lan_mac`（ELAN MAC），对应原厂 `runoam.sh` 行为 |

### 3.5 默认配置

| 文件 | 改动 |
| --- | --- |
| `etc/config/pon` | `option mode 'xgpon'` |
| `etc/uci-defaults/94-tyfza1-leds` | `lan_devs="lan4 lan3 lan2 lan1"` |

### 3.6 状态页与 LED

| 文件 | 改动 |
| --- | --- |
| `packages/tyfza1-pon-control/files/leds.uc` | 注册灯判定增加"业务路径已建立"分支 |
| `packages/luci-app-tyfza1-pon/.../luci.tyfza1-pon` | 后端暴露 `transceiver` 字段 |
| `packages/luci-app-tyfza1-pon/.../overview.js` | 新增温度/电压/偏置/收发光功率五项显示 |

**LED 判定**（中国移动按 SN 认证，`pon-omcid` 不会上报 OMCI auth 结果）：

```js
current = (auth == 1 || (omci != null && +omci.paths > 0 && +omci.error == 0))
          ? 1 : auth > 1 ? 0 : 250;
```

**DDM 换算**（标准 MSA A2）：

| 项目 | 公式 | 实测 |
| --- | --- | --- |
| 温度 | `signed(raw) / 256` °C | 36.3 °C |
| 电压 | `raw / 10000` V | 3.35 V |
| 偏置 | `raw / 500` mA | 7.82 mA |
| 发送光功率 | `10·log10(raw/10000)` dBm | 3.52 dBm |
| 接收光功率 | `10·log10(raw/10000)` dBm | −18.6 dBm |

> 温度是 **signed 16-bit**，负温度需先做符号扩展。

---

## 4. 实测验证结果

### 4.1 上网

中国移动 **PPPoE + VLAN 4031**：

```sh
uci set network.pon0_4031=device
uci set network.pon0_4031.type='8021q'
uci set network.pon0_4031.name='pon0.4031'
uci set network.pon0_4031.ifname='pon0'
uci set network.pon0_4031.vid='4031'

uci set network.wan.proto='pppoe'
uci set network.wan.device='pon0.4031'
uci set network.wan.username='<宽带账号>'
uci set network.wan.password='<密码>'
uci set network.wan.ipv6='1'
```

结果：

```
pppoe-wan: 10.230.46.217  peer 10.230.0.1/32
IPv6:      2409:8a28:af5:731:.../64
DNS:       211.140.13.188 / 211.140.188.188

ping 223.5.5.5 → 5.8 ms, 0% loss
```

**VLAN 必须手动建子接口**——OMCI 只下发 GEM Port，不下发 VLAN 配置。

### 4.2 PON 注册

```
ACTP 0 -> 1  ONU-ID=0
ACTP 1 -> 2  ONU-ID=19  OMCC=1
ACTP 2 -> 3  ONU-ID=19  OMCC=1        ← O5 运行态
pon0: UP, LOWER_UP   carrier = 1
```

### 4.3 指示灯

14 个 LED 全部逐一点亮确认，映射见下表：

| 面板位置 | LED | GPIO | 极性 |
| --- | --- | --- | --- |
| 电源 | `LED_PWR_G` | 11 | HIGH |
| 注册 | `LED_PON` | 9 | LOW |
| 光信号 | `LED_LOS` | 10 | LOW |
| 5G | `LED_WLAN_5G` | WiFi 芯片 | — |
| 2.4G | `LED_WLAN_2G` | WiFi 芯片 | — |
| LAN1–4 | `LED_EPHY3/2/1/0` | 0/1/3/4 | LOW |
| 电话 | `LED_FXS` | 12 | HIGH |
| 宽带 | `LED_PPP_G` | 2 | LOW |
| WPS | `LED_WPS_G` | 5 | HIGH |
| USB | `LED_USB0` | 7 | HIGH |
| （无丝印） | `LED_USB1` | 6 | LOW |

> 5G / 2.4G 灯由 `rtl_ax_ap` 驱动注册（走 WiFi 芯片自己的 LED 引脚），
> 不能用 `brightness` 直接控制，只能用 trigger（`default-on` 可用，
> `phy0radio` 因注册时序问题不触发）。

### 4.4 按键

| 按键 | GPIO | 行为 |
| --- | --- | --- |
| 复位 | 8 | 短按重启（`/etc/rc.button/reset`） |
| 灯光 | 99 | 切换 LED 模式 0 ↔ 2（`lights_toggle`） |
| 无线 | 103 | WPS（`/etc/rc.button/wps`） |

---

## 5. 已知问题

### 5.1 首次上电 SerDes 训练可能不稳

第一次插光纤时状态机可能卡在 O1/O2 反复（`ACTP 0↔1` 循环），
`sync_result=0`（单次同步成功）但状态机不前进。

**拔插一次光纤触发完整重训即可进入 O5。** 遇到类似情况先试拔插，比改参数快。

### 5.2 BOSA identity 探测失败

`bosa/configure` 会显示 `model=0 eeprom=0 identity=ff/ff/ff`，
但 `configured=1 error=0`（已降级）。**这是预期行为**，不影响功能。

### 5.3 2.5G 变体未验证

`tianyi,tyfza1-2p5g` 板型的按键 GPIO 仍沿用上游值（66/67），
未在实机验证。PT1570-R10 是 4GE 变体。

### 5.4 `pon-oam0` 在 XGPON 下为 DOWN

这是 EPON 的 OAM 通道，XGPON 模式不需要，属正常。

---

## 6. 构建与刷入

### 6.1 构建

打 `v0.8.1-pt1570-*` 前缀的标签触发 GitHub Actions：

```sh
git tag v0.8.1-pt1570-<name>
git push origin v0.8.1-pt1570-<name>
```

**每次新标签必须在 `RELEASE_NOTES.md` 里有对应章节**，否则构建立即失败。

### 6.2 只更新内核（不整包刷机）

```
tftpboot 0x5000000 kernel.itb
ubi part ubi_device
ubi write 0x5000000 ubi_k0 <size>
```

`<size>` 用 `tftpboot` 报告的十六进制值，不要手算。

### 6.3 完整刷机

用 Release 里的 `sysupgrade.bin`，或 `install.sh` 安装到另一槽。

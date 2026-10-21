## v0.8.1-pt1570-lan15

### 本版内容

- **无线键再加锁 + 记录按键事件**。上一版改成异步 reload 后，仍然出现
  "按几次之后关了就打不开"。加了两个东西：

  1. ** 串行化**：上一次的  可能还在跑，
     和这一次的撞在一起
  2. ****：每次 released 都记一条，
     这样"按键没反应"就能区分是**根本没触发**还是**触发了但被跳过**
  3.  换成  / ，语义更直接

  设备上模拟两次：

  

- 含  的全部内容：按键 GPIO 交换、LAN LED 修正、
  注册灯重算、工具链缓存、sysupgrade LEB 对齐。

## v0.8.1-pt1570-lan14

### 本版内容

- **修好无线键（上一版几乎不可用）**。三个问题叠在一起：

  1. **`wifi reload` 是同步调用**，拆 radio 时它会阻塞好几秒，
     脚本卡在那里，`logger` 那行永远执行不到，按键也像是"没反应"；
     而 `disabled` 其实已经被改了 —— 于是按几次之后 WiFi 关了，再按却打不开。
  2. **状态判断依赖 uci 的 `disabled`**，但这个值可能是"未设置"（表示启用），
     而且 reload 失败时 uci 和现实会脱节。
  3. **没有防抖**，按键抖动或连按会让状态翻转两次。

  改成：

  ```sh
  # 3 秒防抖
  stamp=/tmp/.wifi-button.stamp
  ...

  # 用实际接口判断，不看 uci
  if iw dev 2>/dev/null | grep -q 'Interface'; then target=1; else target=0; fi

  uci commit wireless
  logger -t wifi-button "radios disabled=$target"   # 先记日志

  ( wifi reload >/dev/null 2>&1 & )                 # 再异步 reload
  ```

  设备上实测：

  ```
  第一次：disabled=1  接口数 0  日志 radios disabled=1
  第二次：disabled=0  接口数 2  日志 radios disabled=0
  ```

- 含 `v0.8.1-pt1570-lan13` 的全部内容：按键 GPIO 交换、无线键改 radio 开关、
  LAN 口指示灯错位修正、注册灯重算、工具链缓存、sysupgrade LEB 对齐。

## v0.8.1-pt1570-lan13

### 本版内容

- **去掉状态页描述里的调试标记**。上一版为了确认浏览器有没有加载到新文件，
  在副标题末尾加了一个 `· UI r2`，忘记删掉了：

  ```
  光链路、业务网络与无线，集中查看。接口连接不等于互联网可达。 · UI r2
  ```

  现在恢复为原本的文案。

- 含 `v0.8.1-pt1570-lan12` 的全部内容：无线键改为 radio 开关、
  灯光键与无线键 GPIO 交换、LAN 口指示灯错位修正、注册灯每个 tick 重算、
  工具链缓存、sysupgrade LEB 对齐写入、`DISTRIB_REVISION` 改为 commit。

## v0.8.1-pt1570-lan12

### 本版内容

- **无线键改为「无线开关」**。它原本绑的是 `wps`，但固件的 wpad 是 basic 版
  不带 WPS，按下去完全没有效果。改成开关更实用：

  - DTS label 从 `wps` 改为 `wifi`（`linux,code` 保持不变）
  - 新增 `/etc/rc.button/wifi`：按一下关闭所有 radio，再按一下打开

  ```sh
  current=$(uci -q get wireless.@wifi-device[0].disabled)
  [ "$current" = "1" ] && target=0 || target=1
  # 遍历所有 wifi-device，写 disabled=$target
  uci commit wireless
  wifi reload
  ```

  `wifi reload` 会重启 hostapd，所以连按两次也等于「重启无线」。

- 含 `v0.8.1-pt1570-lan11` 的全部内容：灯光键与无线键 GPIO 交换、
  LAN 口指示灯错位修正、注册灯每个 tick 重算、工具链缓存、
  sysupgrade LEB 对齐写入、`DISTRIB_REVISION` 改为 commit。

## v0.8.1-pt1570-lan11

### 本版内容

- **交换灯光键与无线键的 GPIO**。两个键的物理位置和 label 绑反了：

  | 物理按键 | 实际触发 | 应该触发 |
  | --- | --- | --- |
  | 灯光 | `wps`（GPIO 99）→ wpad 不支持，**无反应** | `lights_toggle` |
  | 无线 | `lights_toggle`（GPIO 103）→ **所有灯全灭** | `wps` |

  现象正好印证：按「无线」键灯全灭（`lights_toggle` 把 LED mode 切到 0），
  按「灯光」键毫无反应（`/etc/rc.button/wps` 遍历 `/etc/rc.wps/*`，
  但固件的 wpad 是 basic 版，没有 WPS 功能）。

  现在 `btn-led` 绑 GPIO 103、`btn-wifi` 绑 GPIO 99。
  测试夹具同步更新（board 0 的 `btn-wifi` 继承主 DTSI，也跟着变成 99）。

- 含 `v0.8.1-pt1570-lan9`/`lan10` 的全部内容：LAN 口指示灯错位修正、
  注册灯每个 tick 重算、工具链缓存、sysupgrade LEB 对齐写入、
  `DISTRIB_REVISION` 改为 commit、瓦片排成一行。

## v0.8.1-pt1570-lan10

### 本版内容

- **修正 LAN 口指示灯错位**。插在面板 `LAN4` 会点亮面板 `LAN1` 的灯。

  根因：早前为了让"软件 lan1 == 面板 LAN1"做过一次设备树反转实验
  （把 `realtek,lan-phys` 反序），同时把 `94-tyfza1-leds` 里的
  `lan_devs` 改成了 `lan4 lan3 lan2 lan1` 来配合。那个实验**破坏了数据通路**
  （`rx_packets` 恒为 0）后被回滚，但 `lan_devs` **忘了改回来**。

  于是当前映射是：

  | LED | 实际绑定的接口 | 应该绑定 |
  | --- | --- | --- |
  | `LED_EPHY0`（面板 LAN4 的灯） | `lan4` | **`lan1`** |
  | `LED_EPHY1`（面板 LAN3 的灯） | `lan3` | **`lan2`** |
  | `LED_EPHY2`（面板 LAN2 的灯） | `lan2` | **`lan3`** |
  | `LED_EPHY3`（面板 LAN1 的灯） | `lan1` | **`lan4`** |

  插在面板 LAN4 时，软件接口是 `lan1`（UP），而 `LED_EPHY3` 正好绑了 `lan1`，
  所以亮的是面板 LAN1 的灯。

  现在 `lan_devs` 恢复为 `lan1 lan2 lan3 lan4`（自然顺序）：
  `LED_EPHY0` → `lan1` → 面板 LAN4，以此类推。

  2.5G 变体那一支的 `lan_devs` 保持不变——那块板子的 PHY 顺序本来就不同。

- 含 `v0.8.1-pt1570-lan9` 的全部内容：注册灯每个 tick 重算、
  工具链缓存、sysupgrade LEB 对齐写入、`DISTRIB_REVISION` 改为 commit、
  瓦片排成一行。

## v0.8.1-pt1570-lan9

### 本版内容

- **修复注册灯在开机后一直闪烁**。`leds.uc` 的 auth 判断带了一个
  `key = mode:session:auth:state` 的缓存，本意是省掉重复计算。但守护进程在
  PON 还在 O1 时就启动了，`state` 之后变成 O5，而 `auth` 恒为 0
  （中国移动按 SN 认证，OMCI 从不上报结果），缓存 key 几乎不动，
  于是 LED 一直停在 `itu_patterns[O5] = 250`（闪烁），
  必须手动 `restart` 才常亮。

  现在改成**每个 tick 都重新判断**——几次比较的开销远小于一个会过期的缓存。

- **构建缓存工具链**（首次构建仍然慢，从第二次起生效）。
  之前只缓存了 `dl`（源码包），而一次冷构建里**交叉工具链 + host 工具
  占了将近一半时间**（约 40 分钟）。新增缓存：

  ```
  sources/openwrt/staging_dir
  sources/openwrt/build_dir/host
  ```

  key 包含 `sources.lock.json` + `configs/*.config` + 内核 `config-6.18`，
  这三者不变就复用。OpenWrt 的构建系统仍会检查 `build_dir` 内的时间戳，
  所以缓存不会掩盖源码改动。

- 含 `v0.8.1-pt1570-lan8` 的全部内容：sysupgrade 改为 LEB 对齐写入、
  `DISTRIB_REVISION` 改为实际 commit、瓦片排成一行。

## v0.8.1-pt1570-lan8

### 本版内容

- **修复 `sysupgrade` 写不进 rootfs（重要）**。之前每次升级都能跑完、设备也重启，
  但 rootfs 内容不变、overlay 却被清空，看起来像"升级没生效"。

  根因：`ubiupdatevol()` 在数据正好落在 LEB 边界上时会**静默失败**。
  这块板子的 rootfs 是 20,916,044 字节，写进 165 LEB 的卷（20,951,040 字节），
  **余量只有 34,996 字节**。

  `platform_do_upgrade()` 不再走 `nand_do_upgrade()`，改为自己写：
  先解出 kernel / root，`nand_upgrade_prepare_ubi` 准备好卷，
  然后把 rootfs **pad 到 LEB 整数倍**再写入，彻底避开边界情况。
  多出来的零字节位于 squashfs 超级块之后，永远不会被读取。

- **`DISTRIB_REVISION` 改为反映实际 commit**。之前它恒为 `r0-79bc56c`
  （构建脚本写死的 baseline），导致：

  - LuCI 的静态资源 URL 是 `...?v=${resource_version}`，
    这个值不变 → **浏览器永远用旧缓存**，每次刷完固件 UI 都像没变
  - 排查时无法用版本号判断固件有没有刷进去（我因此误判了两次）

  现在 `build.sh` 在 `make defconfig` 之后写入
  `CONFIG_VERSION_REVISION="r0-<commit>"`，每次构建都会变。

- **状态页 5 个瓦片排成一行**。grid 从 `minmax(260px)` + 18px 间距
  改成 `minmax(190px)` + 12px 间距：5 个瓦片所需宽度从 1372px 降到 998px，
  1000px 以上的视口都能一行放下。

- 含 `v0.8.1-pt1570-lan7` 的全部内容：视图改回 `overview.js`、
  LAN 映射回滚、升级检查收紧为 PT1570 专属、`model` 改为
  `YHTC PT1570-R10`、描述样式对齐 Argon。

## v0.8.1-pt1570-lan7

### 本版内容

- **视图文件改回干净名字**。前几版为了绕开浏览器缓存，把状态页视图依次改名
  成 `status-v2/v3/v4/v5/v6`。那只是调试期的手段，不该留在仓库里：

  正式固件每次构建 `DISTRIB_REVISION` 都会变，`luci.js` 拼出的
  `?v=` 跟着变，所有静态资源 URL 一起变，缓存自然失效。

  现在恢复为 `view/tyfza1/overview.js`，`menu.d` 的 `path` 同步改回
  `tyfza1/overview`。

- **去掉视图里的两处调试兼容代码**：
  - CSS 链接重指（`link.href = ... + '?v=' + CSS_V`）
  - 描述节点的 DOM 搬移（`head.parentNode.insertBefore(desc, ...)`）

  这两处原本是为了在 `ui.js` / `status.js` 被缓存的情况下让改动生效。
  现在源头都改好了，视图直接 `return ui.page(...)` 即可。

- **CSS 版本改为模块级时间戳**：`status.js` 里
  `var CSS_VERSION = Date.now()`，改完样式刷新页面就能看到，
  不用再手工改版本号。

- **板型兜底值改为 PT1570-R10**（原来写的是 `'TYFZA1'`）。

- 含 `v0.8.1-pt1570-lan4` 的全部内容：LAN 映射回滚、升级检查收紧为
  PT1570 专属、`model` 改为 `YHTC PT1570-R10`、测试夹具改 PT1570 布局、
  描述样式对齐 Argon。

## v0.8.1-pt1570-lan6

### 本版内容

- **修正 `menu.d` 指向**。`v0.8.1-pt1570-lan5` 的产物是坏的：
  视图文件已改名 `status-v5.js` → `status-v6.js`，但 `menu.d` 里的
  `path` 还停在 `tyfza1/status-v5`，**ONU 运行状态页会 404**。

  那次改名只提交了文件、漏了菜单配置，改动一直留在工作区没进 tag。

  现在 `path` 与文件一致：`tyfza1/status-v6`。

- **描述文字样式对齐 Argon**（随本次一起进构建）：
  `font-size: small`、`line-height: 1.5`、`padding: 0 var(--section-inset)`、
  颜色继承 `--text-strong`，与主题的 `.cbi-map-descr` 完全一致。

- **样式表版本改为动态**（`Date.now()`），以后改 CSS 不必再换文件名。

- 含 `v0.8.1-pt1570-lan4` 的全部内容：LAN 映射回滚、升级检查收紧为
  PT1570 专属、`model` 改为 `YHTC PT1570-R10`、测试夹具改 PT1570 布局。

## v0.8.1-pt1570-lan5

### 本版内容

- **修正 `test_ubi_storage.py` 的夹具**。上一版把升级检查收紧为 PT1570 专属
  （只认 `ubi0_3` / `ubi0_6`）后，构建在「Verify storage migration」这一步
  挂了 7 个用例：

  ```
  AssertionError: False != True :
  Unexpected root volume: ubi0_7 - this image is for PT1570-R10 (ubi0_3/ubi0_6) only
  ```

  原因是测试夹具模拟的是 **TYFZA1 布局**（`OEM` 列表里有 `ubi_fpga`，
  root 落在索引 4/7）。夹具改为 PT1570 布局：

  - `OEM` 去掉 `('ubi_fpga', 34)`，其后所有卷 ID 前移一位
  - root0/root1 断言由 `vols['4']` / `vols['7']` 改为 `vols['3']` / `vols['6']`
  - `(rootid-4)//3` → `(rootid-3)//3`
  - `root=/dev/ubiblock0_{4+3*slot}` → `{3+3*slot}`

- 含上一版全部内容：升级检查收紧、`model` 改为 `YHTC PT1570-R10`、
  LAN 映射回滚、ONU 界面统一、DDM 显示、BOSA 存活探测、按键 bank3。

## v0.8.1-pt1570-lan4

### 本版内容

- **升级检查收紧为 PT1570 专属**。上一版让 `tyfza1-storage.sh` 同时接受
  `ubi0_3/ubi0_6`（PT1570）和 `ubi0_4/ubi0_7`（TYFZA1），这是错的：

  两块板子的 DTS `compatible` 都是 `tianyi,tyfza1`，
  `nand_do_platform_check()` 根本区分不了。**UBI 卷号是唯一可靠的判别依据**
  （PT1570 没有 `ubi_fpga`，所有 ID 前移一位）。放宽之后，PT1570 的固件
  刷到 TYFZA1 上会通过检查，然后写到错误的卷。

  现在只接受 `ubi0_3/ubi0_6`，报错文案也点明：

  ```
  Unexpected root volume: ubi0_3 - this image is for PT1570-R10 (ubi0_3/ubi0_6) only
  ```

  TYFZA1 硬件请用 `tyfza1-custom` 分支。

- **系统信息里的型号改为 PT1570**。`rtl9617c-tyfza1-ubi.dts` 的 `model`
  从 `Tianyi TYFZA1 (RTL9617C UBI)` 改成 `YHTC PT1570-R10 (RTL9617C UBI)`，
  `/tmp/sysinfo/model` 和 LuCI 的板型显示都会跟着变。

  `compatible` 保持 `tianyi,tyfza1` 不动——驱动靠它匹配，改了会起不来。

- 含上一版（`v0.8.1-pt1570-lan3`）的全部内容：LAN 映射回滚、
  sysupgrade 卷号修复、ONU 界面统一、DDM 显示、BOSA 存活探测、
  按键 bank3、`keep.d` 保护 factory 身份。

## v0.8.1-pt1570-lan3

### 本版内容

- **回滚 LAN 映射反转（重要）**。上一版把 `phy-handle` 指向 `phy3`、
  `realtek,lan-phys` 反转为 `<&phy3 &phy2 &phy1 &phy0>`，想纠正面板顺序，
  结果把数据通路打断了：

  ```
  lan4: Link is Up - 1Gbps/Full - flow control off
  br-lan: port 4(lan4) entered forwarding state
  rx_packets = 0        <- 链路通了，但一个包都收不到
  ```

  **MAC port 与 PHY 是板上固定连线的**：port 0 只能连 phy0（mdio:01），
  port 3 只能连 phy3（mdio:04）。把 `phy-handle` 指到 phy3 只是让 port 0
  和错误的 PHY 协商出了链路，数据通路从未接通。

  而且 `rtl_register_lans()` 里 **port 0 不读 `lan-phys`，它用 `phy-handle`**，
  所以只反转 `lan-phys` 会让 port 0 和 port 3 都拿到 phy0，第二个
  `phy_attach_direct()` 直接 `-EEXIST`，LAN4 根本注册不上。

  现已恢复 `<&phy0 &phy1 &phy2 &phy3>` 并去掉 `phy-handle` 覆盖。
  **面板顺序由硬件决定：Linux `lan1` 就是丝印 `LAN4`。**
  要改接口名只能改驱动（`rtl_register_lan()` 里按 port 拼接口名的那行），
  不是设备树能解决的。

- **修正 sysupgrade 的 root 卷号检查**。`tyfza1-storage.sh` 硬编码期望
  `ubi_r0 = ubi0_4` / `ubi_r1 = ubi0_7`（TYFZA1 布局）。PT1570-R10 没有
  `ubi_fpga` 卷，所有 ID 前移一位，实际是 `ubi0_3` / `ubi0_6`，于是整包升级
  被拒绝：

  ```
  Unexpected TYFZA1 root volume: ubi0_3
  Image check failed.
  ```

  现在同时接受两种布局（`_3/_4` 与 `_6/_7`）。

- **ONU 界面统一**（7 个页面）：
  - 页面标题渲染为 Argon 风格的圆角卡片
  - 描述文字移到卡片外，`font-size: small`、`line-height: 1.5`、
    `padding: 0 var(--section-inset)`、颜色继承 `--text-strong`
    ——完全照搬主题的 `.cbi-map-descr`
  - 状态页瓦片收回到 5 个（收/发光功率、温度、光口发射、光学校准），
    电压、偏置电流等移入「光模块详情」折叠
  - 去掉顶级 `ONU` 菜单的 ACL 依赖

- 含之前所有内容：DDM 显示、BOSA 存活探测、按键 bank3（99/103）、
  `keep.d` 保护 factory 身份、FIT 槽位判据 `31:11`。

## v0.8.1-pt1570-lan2

### 本版内容

- **修正 LAN4 初始化失败（-EEXIST）**。上一版只反转了 `realtek,lan-phys`，
  但 `rtl_register_lans()` 里 **port 0 根本不读 lan-phys，它用的是 `phy-handle`**：

  ```c
  phy = of_parse_phandle(parent->of_node,
      port == priv->port ? "phy-handle" : "realtek,lan-phys",
      port == priv->port ? 0 : port);
  ```

  `xram-lan.dts` 里 `realtek,port = <0>` 且 `phy-handle = <&phy0>`，
  所以反转后 port0 仍是 phy0、port3 也是 phy0，第二次 `phy_attach_direct()`
  报 `sysfs: cannot create duplicate filename '.../mdio:01'`，lan4 起不来。

  现在 `phy-handle` 一起指向 `&phy3`：

  | port | 来源 | PHY | 面板 |
  |---|---|---|---|
  | 0 | `phy-handle` | phy3 (mdio:04) | LAN1 |
  | 1 | `lan-phys[1]` | phy2 (mdio:03) | LAN2 |
  | 2 | `lan-phys[2]` | phy1 (mdio:02) | LAN3 |
  | 3 | `lan-phys[3]` | phy0 (mdio:01) | LAN4 |

  `lan-phys[0]` 从不被读取。2.5G 变体显式覆盖 `phy-handle = <&phy0>` 保持原顺序。

- **修正注册灯常闪**。`leds.uc` 的缓存 key 是 `mode:session:auth`，**不含 state**。
  开机时状态机还在 O1/O2，此时 key 就被固定；之后进入 O5 但 auth 一直是 0
  （中国移动按 SN 认证，OMCI 不上报 auth 结果），key 不变 → 永远不重算 → 一直闪。
  key 改为 `mode:session:auth:state`。

- **sysupgrade 保留 `/etc/tyfza1-factory`**。新增
  `lib/upgrade/keep.d/tyfza1-factory`，否则整包升级会丢掉本机 MAC/SN/校准，
  而 `tyfza1-factory` 已不再回退到镜像内副本。

- 含之前所有内容：DDM 显示、BOSA 存活探测、按键 bank3（99/103）、FIT 槽位 31:11。

## v0.8.1-pt1570-ddm2

### 本版内容

- 修正 2.5G 变体的按键 fixture：`btn-wifi` 继承主 DTSI 的 bank3 pin7（GPIO 103），
  不是旧的 67。上一版构建因 `test_board_variants.py` 断言失败而中断。
- FIT 槽位判据修正：`31:12` → `31:11`（PT1570 只有 ubi0_0..ubi0_10）。
- factory 数据源改为显式三段判断，不再静默回退到固件内副本。
- 含 DDM 显示、BOSA 存活探测、LAN 顺序、注册灯、按键 bank3 修正。

## v0.8.1-pt1570-ddm

### 本版内容

- **补上光模块 DDM 显示**。之前页面只写"光功率 / 温度尚无读取接口"，
  因为后端只暴露了 `optical`（状态位），DDM 数据在 `transceiver` 里没人读。
  现在：
  - 后端增加 `transceiver` 字段
  - 前端按标准 MSA A2 换算显示五项读数：

    | 项目 | 换算 | 典型值 |
    |---|---|---|
    | 温度 | `raw / 256` °C | 36.3 °C |
    | 电压 | `raw / 10000` V | 3.35 V |
    | 偏置电流 | `raw / 500` mA | 7.82 mA |
    | 发送光功率 | `10*log10(raw/10000)` dBm | 3.52 dBm |
    | 接收光功率 | `10*log10(raw/10000)` dBm | −18.6 dBm |

- 含 BOSA 存活探测降级、LAN 顺序、注册灯、按键 bank3 修正。

## v0.8.1-pt1570-bosa2

### 本版内容

- **BOSA 降级前先做存活探测**（修正上一版过于宽松的处理）。
  identity 探测失败后不再直接当作"外部 EEPROM 模式"，而是：

  1. 恢复页指针（`identify()` 会把它留在 0xff 或 2）
  2. 读标准 MSA DDM 区 `0x60..0x63`（温度 / 电压）
  3. **全部读回 0xff → 判定模块缺失或无响应，仍然返回 -ENODEV**
  4. 只要有任一字节非 0xff → 确认是带 EEPROM 的 MSA 器件，
     跳过主机侧校准（`eeprom=1 configured=1 error=0`）

  这样真实的 BOSA 故障仍会报错，只有"器件活着但不认 Semtech 身份协议"
  的情况才降级。对应原厂 `Detecting UX3361 ... EEPROM exists, do NOT do
  initialization` 的行为。

- 含 LAN 顺序纠正、注册灯修正、按键 bank3 修正。

## v0.8.1-pt1570-bosa

### 本版内容

- **BOSA identity 探测失败不再报错**。UX3361 用外部 EEPROM 自带校准，
  不实现 Semtech 的 page-0x7f identity 寄存器，`identify()` 读回 0xff 后
  返回 -ENODEV，导致：
  - `bosa.error=-19`，状态页判定为"初始化异常"
  - `bosa.configured=0`，显示"光学校准未就绪"

  现在 identity 失败时按"外部 EEPROM 模式"处理（`eeprom=1 configured=1 error=0`），
  因为这类光模块本来就不需要主机侧校准。

- 含上一版内容：LAN 顺序纠正、注册灯不再误闪、按键 bank3 修正。

## v0.8.1-pt1570-lan-fix

### 本版内容

- **LAN 口顺序纠正**。面板丝印 LAN1..LAN4 从左到右，但 PHY/port 顺序相反
  （port 0 驱动面板 LAN4）。`rtl9617c-tyfza1-ni.dts` 反转 `realtek,lan-phys`，
  使 Linux `lan1` 对应面板 LAN1；`94-tyfza1-leds` 的 `lan_devs` 同步反转为
  `lan4 lan3 lan2 lan1`，保证 `LED_EPHY0`（物理在面板 LAN4）绑定 `lan4`。

- **注册灯不再误闪**。中国移动按 SN 认证，`pon-omcid` 不会上报 OMCI auth 结果
  （`/var/run/pon-omci` 里 `auth=0`，但 `paths=6` 业务已通）。
  `leds.uc` 原来只看 `auth == 1`，导致 O5 状态下仍闪 250 模式。
  现在把"业务路径已建立且无错误"也视为注册成功，灯常亮。

- 保留三个按键修正（bank3: lights=99, wifi=103）与 PON 相关修复。

## v0.8.1-pt1570-keys2

### 本版内容

- **修正三个按键的 GPIO 编号**。通过 U-Boot 直接读取输入寄存器、
  逐键按压确认：
  - 复位 `bank0 pin8` = **GPIO 8**
  - 灯光 `bank3 pin3` = **GPIO 99**
  - 无线 `bank3 pin7` = **GPIO 103**

  之前的 71 / 67 是错的。原厂 FDT 里写作 `<&gpio2 7>` / `<&gpio2 3>`，
  但该 phandle 实际解析到 `bank@3`（节点名与 ranges 索引错位），
  所以读 bank2 永远是 0。

- 保留 `CONFIG_INPUT` 与 PON 修复（BOSA 容错、onu_mac 回退、xgpon 默认）。

## v0.8.1-pt1570-input

### 本版内容

- 打开 `CONFIG_INPUT` / `CONFIG_INPUT_EVDEV`。之前内核完全没编 INPUT，
  导致 `gpio-button-hotplug` 只能申请到 GPIO，无法注册按键设备
  （`/sys/class/input` 不存在，按了没反应）。
- 保留 v0.8.1-pt1570-keys 的三个按键定义（reset=GPIO8、灯光=GPIO71、WPS=GPIO67）。
- PON：BOSA 识别失败不再中止初始化；`onu_mac` 回退到 ELAN MAC；
  默认模式 xgpon。

## v0.8.1-pt1570-keys

### 本版内容

- 补齐 PT1570-R10 前面板三个按键：复位（GPIO8）、灯光（GPIO71）、无线/WPS（GPIO67），
  GPIO 编号取自原厂运行中 FDT 的 `/gpio-keys` 节点。
- 原定义只声明了一个 `lights_toggle`，且误用了无线键的 GPIO67。
- 2.5G 变体的灯光键覆盖同步为 GPIO66。
- 其余内容与 v0.8.1-pt1570 相同。

## v0.8.1-pt1570

### 本版内容

- 新增 XTX XT26G02C（厂商 0x0B / 器件 0x12）到内核 SPI-NAND 芯片表，供中国移动 PT1570-R10 使用（2048 页 / 128B OOB / 128KB 块 / 2 Gbit）。
- 基于 v0.8.1-beta，其余内容与该版本相同。

## v0.8.7-custom

### 本版内容

- 修复蓝口（port4）10/100 Mbps 链路无流量问题：MAC 回调不再在低速时错误切到 MII，port4 全速率保持 GMII（厂商 SGMII PCS 要求），内含 80 组端口/速率/双工回归测试。
- 修复 2.5G 版升级时误报 invalid sysupgrade file 的问题（双板共享同一 sysupgrade 归档目录，校验规则同时接受两种板卡身份）。另含 legacy 2.5G 板补救脚本 fix_legacy_2p5g_upgrade.sh。
- 多 Wan 分流：原生 nftables 版 mwan3（dl12345/mwan3 3.6.12）。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.6-custom（未发布：构建中止，内容并入 v0.8.7-custom）

### 本版内容

- 修复 2.5G 版升级时误报 invalid sysupgrade file 的问题（双板共享同一 sysupgrade 归档目录，校验规则改为同时接受两种板卡身份）。另含 legacy 2.5G 板补救脚本 fix_legacy_2p5g_upgrade.sh 与新的 CI 板卡校验步骤。
- 多 Wan 分流：原生 nftables 版 mwan3（dl12345/mwan3 3.6.12）。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.5-custom

### 本版内容

- 多 Wan 分流正式切换为原生 nftables 版 mwan3（dl12345/mwan3 3.6.12）：构建时将仓库克隆并重嵌套进子目录，经 src-link feed 置于 packages 之前，覆盖官方 iptables 版；规则直接运行在内核 nft 表，配 nftables-json 变体。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.4-custom

### 本版内容

- 多 Wan 分流：mwan3 + LuCI 应用（本版实际为官方 iptables 版——尝试切换 dl12345/mwan3 nft 版时因该仓库根级布局无法被 OpenWrt feed 扫描器索引而静默回退，切换在 v0.8.5-custom 完成）。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.3-custom

### 本版内容

- 新增多 Wan 分流：mwan3 + luci-app-mwan3（含中文界面），依赖已由官方 compat 清单覆盖。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.2-custom

### 本版内容

- 合入上游 v0.8.1-beta：OMCC 版本选择（0xb0/0x86 兼容模式）、Class 332 增强认证开关、双板四 LAN 口映射修复。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.1-beta

- 修复 2.5G 版升级时误报 invalid sysupgrade file 的问题。
- 增加 OMCC 版本选择，支持默认 0xb0 与兼容模式 0x86。
- 增加独立的 Class 332 增强认证开关，默认保持启用。

## v0.8.1-custom

### 本版内容

- 合入上游 v0.8.0-beta：Wi-Fi 硬件加速 1.34 Gbps、官方 APK 源、可写空间 34.6 MiB、原生 U-Boot 安装。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。

## v0.8.0-beta

- 同一镜像兼容全千兆版和 2.5G 口版，两种机型都提供四个 LAN 口。
- 网口统一为 LAN1–LAN4；2.5G 版最左侧蓝口对应 LAN4。
- 修复 RTL8221B 冷启动和 HiSGMII 初始化，包括应答超时后的请求释放。
- 单个网口初始化失败不再拖掉全部网口；灯控、诊断或无线通知器出错也不会撤销有线接口。
- 修正 2.5G 口的计数器、PON 统计和界面端口显示。
- 校正两种机型的 LAN、USB 灯位。
- 恢复 LAN 与双频 Wi-Fi 出厂 MAC。
- 补齐 WPA3/PMF 能力声明与管理帧保护。
- 修正 2.4 GHz HT40、HE40 配置，完善 DFS 停止与重新启用时的状态处理。
- 优化 Wi-Fi 硬件加速，5 GHz UDP 实测吞吐约 1.34 Gbps。
- 改进 PE 批量收发与 HE 聚合，减少无线传输开销。
- 修复无线入桥后的流表衔接和小包长度处理。
- 新增无线发射功率设置。
- 加入 CPU 调频页面，修正温度读取和平台信息显示。
- 重整 ONU 管理界面，集中展示线路、业务、加速和诊断状态。
- 集成 Argon 主题与简体中文。
- 处理升级后的 LuCI、Argon 资源缓存。
- 从原厂配置恢复 PON 模式及设备身份。
- 接入带签名校验的 OpenWrt 官方软件源，预装常用插件所需的内核模块和依赖。
- 调整可写数据卷，新装后可用空间约 34.6 MiB；保留原厂配置及回退所需卷。
- 支持原生 U-Boot 安装、标准 sysupgrade，以及早期 alpha 固件直接升级。
- 更新 Telnet 安装包和安装说明。
- GitHub Actions 支持同版本重新构建，并加入双板型端口、故障隔离和统计映射检查。

## v0.7.1-custom

### 本版内容

- 合入上游 v0.7.0-alpha：双板支持、新 ONU 界面、Argon 主题与简体中文。
- 自用组件：WireGuard、iperf3、SmartDNS、PassWall（xray-core）。
## v0.7.0-alpha

### 本版更新

- 同一固件兼容全千兆版和 2.5G 口版，修正网口初始化、协商及两种机型的指示灯。
- 修正 WPA3/PMF、2.4GHz HE40 配置及 LAN、双频 Wi-Fi 出厂 MAC 地址恢复。
- 修复无线入桥后的硬件卸载衔接、数据收发处理和 DFS 生命周期。
- 更新 ONU 管理界面，集成 Argon 主题及简体中文。

### 待验证与待处理

- 两种板型的冷启动、灯态、2.5G 持续双向收发及 WPA3/HE40 仍待实机验证。
- 开启 Wi-Fi 流量硬件加速后，Wi-Fi 最高吞吐只有约 500 Mbps，待进一步修复。

## v0.6.1

### 添加自用包

## v0.6.0-alpha

### 实测进展

- **XG-PON 线路 PPPoE 拨号成功，千兆带宽跑满，CPU 占用约 4.5%。** 以上为本次测试环境下的实测结果。

### 本版更新

- 修复 PPPoE/PON 双向硬件转发和小包封装异常，降低转发时的 CPU 开销。
- 修复 VLAN WAN 业务入口及防火墙流表的设备识别，完善 PPPoE 拨号与硬件卸载衔接。
- 网口统一命名为 `lan1`–`lan5`，PON 业务口改为 `pon0`；保留配置升级时自动迁移原有设备引用。
- 修正硬件转发流量统计，完善转发关闭、重新启用后的恢复。

### 已知问题与待验证项

- VLAN WAN 启动修复仍待重启实测。
- 2.5G 网口及 USB 面板指示灯状态异常，仍待排查。

## v0.5.0-alpha

- 新增原生指示灯和灯光开关，接入 PON、网口、USB 与双频 Wi-Fi 状态。
- 接入 USB 2.0/3.0、U 盘自动挂载及常见文件系统，完善 2.5G 网口。
- 修复保留配置升级后的指示灯初始化，完善 PON 认证灯态。
- 修复硬件转发初始化、流表匹配及 Wi-Fi 上行处理异常。

## v0.4.2-alpha

- 修复 PON 上行繁忙时的 VLAN 处理及 PPPoE 重试异常。

## v0.4.1-alpha

- 修复 PON 多业务及 VLAN 处理异常
- 修复 Wi-Fi 自动选信道失败
- 无线默认地区调整为中国

## v0.4.0-alpha

- 新增 5 GHz Wi-Fi 160 MHz 支持，已实测双天线连接；完善信道切换和雷达避让。
- 优化 Wi-Fi 收发和双向硬件加速，修复暂停传输、省电及加密密钥更新时的数据处理问题。
- 加入无线温度监测和自动校准。
- 完善各类 PON 模式的认证、业务配置及切换流程，修复原厂配置读取和不同模式相互影响的问题。
- 改进光纤短时断线及设备异常后的恢复，修复重新连接时业务配置、加密和硬件转发的衔接问题。
- 增加光口故障监测、异常发光保护和断电通知的驱动支持。
- 修正内存启动镜像的大小检查，补充原厂 USB 识别与挂载分析，以及 PON/Wi-Fi 测试工具。

## v0.3.1-alpha

- 光学、射频校准数据改为每次启动从原厂配置卷加载到 `/tmp`，修复读取失败后沿用旧校准文件的问题。
- 补充原厂系统槽、配置卷保留和校准数据自动加载说明。

## v0.3.0-alpha

- 修复启动时射频校准数据未及时加载，导致找不到 Wi-Fi 设备、无线页面出现 404 的问题。
- 优化双频 Wi-Fi 6 与双向硬件加速的数据收发、动态速率和省电调度。
- 完善 PON 的 OMCI 业务配置、VLAN 映射及硬件转发联动。
- 改进 PON、网络转发和 PCIe 的启停与资源管理。
- 重整 PON 管理页面，集中展示线路、认证和业务状态，保留原生 OpenWrt 网络配置入口。
- 改进自定义软件包选择、增量构建同步和 GitHub Actions 发布流程。

PON 各模式的 OLT 互通与 Wi-Fi 兼容性待测试；持续高负载丢包待优化。各项进度与安装方法见 README。

---
tags: [技术/Yocto]
created: 2026-07-21
---
----------------------------------------------------------------------------
# Yocto bblayers.conf 与 Layer 详解

## 概述

Layer 是 Yocto 组织代码的核心方式。`bblayers.conf` 是入口，告诉 BitBake 去哪里找 Layer；每个 Layer 内的 `conf/layer.conf` 是自述文件，声明自己的身份、范围和依赖。

> 本章配套笔记：[[Yocto-构建系统深入]]

---

## 一、bblayers.conf 的角色

`build/conf/bblayers.conf` 只做一件事：**列出所有 Layer 的绝对路径**。

```conf
# POKY_BBLAYERS_CONF_VERSION 用于检查版本兼容性
BBLAYERS ?= " \
  /home/user/poky/meta \
  /home/user/poky/meta-poky \
  /home/user/poky/meta-yocto-bsp \
  /home/user/meta-custom \
  "
```

**注意**：
- `bblayers.conf` 没写的 Layer，即使磁盘上有目录也不会被加载
- 添加 Layer 用 `bitbake-layers add-layer <path>`，等价于手动编辑
- 路径建议用**绝对路径**，避免因工作目录变化导致找不到

---

## 二、layer.conf — Layer 的自述文件

每个 Layer 目录下必须有 `conf/layer.conf`，否则 BitBake 不认。它告诉 BitBake 五件事：

```conf
# meta/conf/layer.conf (OE-Core 核心层)
BBFILE_COLLECTIONS += "core"                    # ① 注册名
BBFILE_PATTERN_core = "^${LAYERDIR}/"           # ② 管辖范围
BBFILE_PRIORITY_core = "5"                      # ③ 优先级
LAYERDEPENDS_core = ""                          # ④ 必须依赖
LAYERRECOMMENDS_core = "core"                   # ⑤ 推荐依赖
LAYERSERIES_COMPAT_core = "scarthgap"           # ⑥ 兼容版本
```

### 2.1 BBFILE_COLLECTIONS — 注册名

Layer 的**全局唯一标识**。所有后续的 `_core` 后缀变量都引用这个名字。

```conf
BBFILE_COLLECTIONS += "core"        # 注册名为 "core"
BBFILE_PRIORITY_core = "5"          # 引用 "core" 的优先级

BBFILE_COLLECTIONS += "meta-custom" # 注册名为 "meta-custom"
BBFILE_PRIORITY_meta-custom = "6"   # 引用 "meta-custom" 的优先级
```

> 命名惯例：用 Layer 目录名去掉 `meta-` 前缀后的名字，或直接用完整名。

#### 理解 `_<注册名>` 后缀

`_core`、`_meta-custom` 这些后缀的作用是**把变量绑定到特定的 Layer**。

**标准做法是一个目录只注册一个名字**，一一对应最清晰：

```conf
# meta/conf/layer.conf — 一个 Layer，一个注册名
BBFILE_COLLECTIONS += "core"
BBFILE_PRIORITY_core = "5"
```

> 这里举例多注册只是为了说明后缀的作用机制，**实际中不要这样用**，纯粹增加混淆。

所有支持 `_<注册名>` 后缀的变量：

| 变量 | 含义 |
|------|------|
| `BBFILE_PATTERN_<name>` | 该 Layer 匹配哪些 `.bb` 文件 |
| `BBFILE_PRIORITY_<name>` | 该 Layer 的优先级 |
| `LAYERDEPENDS_<name>` | 该 Layer 的必须依赖 |
| `LAYERRECOMMENDS_<name>` | 该 Layer 的推荐依赖 |
| `LAYERSERIES_COMPAT_<name>` | 该 Layer 兼容的 Yocto 版本 |

实际例子（meta-raspberrypi）：

```conf
BBFILE_COLLECTIONS += "raspberrypi"              ← 注册名 raspberrypi
BBFILE_PRIORITY_raspberrypi = "6"                ← 优先级 6
LAYERDEPENDS_raspberrypi    = "core"             ← 依赖 core layer
LAYERSERIES_COMPAT_raspberrypi = "scarthgap"     ← 兼容版本
```

`_raspberrypi` 后缀就是把这些变量绑定到 `raspberrypi` 这个 Layer 上。

### 2.2 BBFILE_PATTERN — 管辖范围

BitBake 用正则匹配哪些 `.bb` 文件属于这个 Layer：

```conf
BBFILE_PATTERN_core = "^${LAYERDIR}/"
# ${LAYERDIR} = /home/user/poky/meta
# 即：所有以 /home/user/poky/meta/ 开头的 .bb 文件都归这个 Layer 管
#
# 匹配示例（meta/ 下的所有内容，不限层级）：
#   /home/user/poky/meta/recipes-core/busybox/busybox_1.36.1.bb                    ✅
#   /home/user/poky/meta/recipes-core/base-files/base-files_3.0.14.bb              ✅
#   /home/user/poky/meta/recipes-kernel/linux/linux-yocto_6.6.bb                   ✅
#
# 不匹配示例（不在 meta/ 目录下）：
#   /home/user/poky/meta-poky/conf/layer.conf                                       ❌
#   /home/user/poky/meta-yocto-bsp/recipes-core/busybox/busybox_1.36.1.bb          ❌
#   /home/user/poky/meta-raspberrypi/recipes-core/busybox/busybox_1.36.1.bbappend  ❌
```

> `^${LAYERDIR}/` 末尾的 `/` 很关键——它确保只匹配 `meta/` 目录内部，而不会误匹配到 `meta-poky`、`meta-raspberrypi` 等名称以 `meta` 开头的其他目录。

通常就是 `${LAYERDIR}/`，表示**该目录下的所有 `.bb` 和 `.bbappend` 属于我**。一般不需要改。

### 2.3 BBFILE_PRIORITY — 优先级

**只针对同名 Recipe 冲突时生效**：

```conf
Layer A (priority=5): meta/recipes-core/busybox/busybox_1.36.1.bb
Layer B (priority=6): meta-custom/recipes-core/busybox/busybox_1.36.1.bb

→ BitBake 选择 Layer B 的 busybox（6 > 5）
```

默认优先级参考：

| Layer | 优先级 | 说明 |
|-------|--------|------|
| `meta` (OE-Core) | 5 | 核心层，最底层 |
| `meta-poky` | 5 | Poky 发行版配置 |
| `meta-yocto-bsp` | 5 | Yocto 官方 BSP |
| `meta-<vendor>` | 5-8 | 第三方 Layer（如 meta-raspberrypi=6） |
| `meta-custom` | **6-10** | **建议自定义 Layer 设 6 以上，确保能覆盖** |

#### 优先级对 .bbappend 不生效

**所有匹配的 .bbappend 都会叠加到同一个 .bb 上**，优先级不参与筛选。

```conf
# 三个 Layer，三种优先级
meta（priority=5）:       busybox_1.36.1.bb              ← 基础 Recipe
meta-poky（priority=6）:  busybox_1.36.1.bbappend        ← ✅ 应用
meta-custom（priority=7）: busybox_1.36.1.bbappend       ← ✅ 应用
```

三个文件最终**合成为一个"虚拟 busybox.bb"**，优先级 5/6/7 在这里没区别。

#### 叠加顺序由 BBLAYERS 顺序决定

多个 `.bbappend` 按 `BBLAYERS` 中出现的顺序依次叠加：

```conf
# bblayers.conf
BBLAYERS ?= " \
  /home/user/poky/meta \             ← .bb 在这里
  /home/user/poky/meta-poky \         ← 第 1 个 .bbappend
  /home/user/meta-custom \            ← 第 2 个 .bbappend
  "
```

```conf
# meta-poky（先加载）:
PACKAGECONFIG:append = " nfs"

# meta-custom（后加载）:
PACKAGECONFIG:append = " httpd"

# 最终：PACKAGECONFIG = "原有值 nfs httpd"
```

#### 优先级在 .bbappend 中唯一的作用

仅当两个 `.bbappend` 对**同一个变量**使用 `=`（完全赋值）时，优先级高的胜出：

```conf
# meta-poky (priority=6，先加载):
SRC_URI = "https://old.com/source.tar.gz"

# meta-custom (priority=7，后加载):
SRC_URI = "https://new.com/source.tar.gz"

# 最终：SRC_URI = "https://new.com/source.tar.gz"（后加载 + 高优先级）
```

这里实际上是 **BBLAYERS 顺序**和**优先级**共同作用——但日常写 `.bbappend` 时记住：**用 `:append` / `:remove` 不会受优先级影响**，用 `=` 才会。

#### 如何安全地覆盖原有的值？

推荐用 `:remove` + `:append` 组合，既覆盖又不受后面 Layer 影响：

```conf
# 你想把 "ipv6" 换成 "httpd"
PACKAGECONFIG:remove = "ipv6"
PACKAGECONFIG:append = " httpd"

# 最终："nfs ssl" → "nfs ssl httpd"（ipv6 被删掉了）
```

三种方式对比：

| 方式 | 语法 | 能否覆盖？ | 是否受后续 Layer 影响？ |
|------|------|-----------|----------------------|
| 直接覆盖 | `VAR = "新值"` | ✅ 覆盖 | ✅ 可能被后面的 `=` 再覆盖 |
| 追加 | `VAR:append = " 新值"` | ❌ 只能追加 | ❌ 不受影响 |
| 先删后加 | `VAR:remove = "旧值"` + `VAR:append = " 新值"` | ✅ 推荐 | ❌ 不受影响 |

#### 用 .bbappend 还是完整 .bb 来覆盖？

**方式一：.bbappend（推荐）** — 增量修改，只写你要改的部分：

```conf
PACKAGECONFIG:append = " httpd"
SRC_URI += "file://my-config.patch"
```

- ✅ 只关心你要改的地方，不需要知道 .bb 全貌
- ✅ Yocto 升级后 .bbappend 通常还能用

**方式二：完整 .bb** — 你的 Layer 优先级高则完全替换原 Recipe：

```conf
# meta-custom/recipes-core/busybox/busybox_1.36.1.bb
# ↑ meta/ 下的同名 .bb 被完全忽略
SRC_URI = "git://my-fork/busybox.git"
do_compile() { ... }
```

- ✅ 可以大改特改，不受原 .bb 限制
- ❌ Yocto 升级后需手动跟进，维护成本高

**选型建议**：能用 `.bbappend` 解决的别写完整 `.bb`。大改源码、整体替换功能时才用完整 `.bb`。

### 2.4 LAYERDEPENDS — 必须依赖

声明这个 Layer 依赖其他 Layer。构建时会检查依赖是否已添加：

```conf
# meta-raspberrypi/conf/layer.conf
LAYERDEPENDS_meta-raspberrypi = "core"
```

如果 `BBLAYERS` 中没有 `meta` 层，BitBake 会报错并停止。

### 2.5 LAYERRECOMMENDS — 推荐依赖

比 `LAYERDEPENDS` 弱，没有也能跑：

```conf
# 推荐有 networking layer，但不是必须的
LAYERRECOMMENDS_meta-layer = "networking-layer"
```

### 2.6 LAYERSERIES_COMPAT — 兼容版本

**新手最常见的问题来源**。声明这个 Layer 兼容哪个 Yocto 版本：

```conf
LAYERSERIES_COMPAT_meta-raspberrypi = "scarthgap"
```

Yocto 大版本的代号：

| 版本 | 代号 | 发布时间 |
|------|------|---------|
| 4.0 | Kirkstone | 2022.04 (LTS) |
| 5.0 | Scarthgap | 2024.04 (LTS) |
| 5.1 | Styhead | 2024.10 |

如果 Layer 声明了 `LAYERSERIES_COMPAT = "kirkstone"` 但你用的是 `scarthgap`，BitBake 会警告或报错。很多第三方 Layer 不更新这个字段，导入时经常要手动改。

---

## 三、Layer 优先级 vs BBLAYERS 顺序

两个容易混淆的机制：

| 机制 | 控制什么 | 设置位置 |
|------|---------|---------|
| **BBLAYERS 顺序** | **文件查找顺序**—同名文件谁先被发现 | `bblayers.conf` |
| **BBFILE_PRIORITY** | **文件覆盖规则**—同名文件谁生效 | `layer.conf` |

**举例**：两个 Layer 都提供 `busybox.bb`

```
BBLAYERS 顺序：                  BBFILE_PRIORITY：
meta (先加载)                     meta = 5
meta-custom (后加载)              meta-custom = 6

实际生效过程：
1. BitBake 扫描 meta，发现 busybox.bb（记录）
2. 扫描 meta-custom，也发现 busybox.bb（记录）
3. 比较优先级：meta(5) < meta-custom(6)
4. ✅ 使用 meta-custom 的 busybox.bb
```

**如果两个 Layer 优先级相同**（比如都是 5），则 **BBLAYERS 中后出现的 Layer 覆盖先出现的**。

---

## 四、.bbappend 的特殊行为

> 优先级与叠加的详细机制已在 [[#2.3 BBFILE_PRIORITY — 优先级|2.3 优先级]] 中完整说明，本节仅补充目录相关的匹配规则。

### 文件名匹配规则

`.bbappend` 必须放在和 `.bb` **完全相同的目录路径**下才能匹配：

```conf
# busybox.bb 在 meta/recipes-core/busybox/busybox_1.36.1.bb
# bbappend 必须在：
meta-custom/recipes-core/busybox/busybox_1.36.1.bbappend   ✅
meta-custom/recipes-extended/busybox/busybox_1.36.1.bbappend ❌
```

### 版本号匹配

```conf
busybox_1.36.1.bb      →  busybox_1.36.1.bbappend   ✅ 精确匹配
busybox_1.36.1.bb      →  busybox_%.bbappend        ✅ % 通配任意版本
busybox_1.36.1.bb      →  busybox.bbappend          ❌ 不匹配，缺版本号
```

> `%` 通配符表示"任意版本"，`.bbappend` 中用 `%` 比写死版本号更灵活，升级 Recipe 时不用改文件名。

**完整 .bb** — 完全重写，你的 Layer 优先级高就覆盖原版：

```conf
# meta-custom/recipes-core/busybox/busybox_1.36.1.bb
# ↑ 完整的 Recipe，meta/ 下的同名 .bb 被完全忽略
SRC_URI = "git://my-fork/busybox.git"
PACKAGECONFIG = "httpd ssl nfs"
```

- ✅ 可以大改特改，不受原 .bb 限制
- ❌ Yocto 升级后可能要跟着改，维护成本高
- ❌ 和上游 Recipe 不再关联，升级时容易漏掉安全更新

**如何选**：

| 场景 | 推荐 |
|------|------|
| 加个配置、打个补丁 | .bbappend |
| 修改几个变量 | .bbappend |
| 改用完全不同的源码 | .bb |
| 功能大改（删半加半） | .bb 优先 |
| 长期维护、追 Yocto 升级 | .bbappend（变动小） |

一个实用建议：**能用 .bbappend 解决的别写完整 .bb**，省事也省维护。实在需要大改再用完整 .bb。

一个标准 Layer 的目录结构：

```
meta-custom/                      ← Layer 根目录（以 meta- 开头）
├── conf/
│   ├── layer.conf                ← 必须有，否则不被识别为 Layer
│   ├── machine/                  ← MACHINE 定义
│   │   └── my-board.conf
│   └── distro/                   ← DISTRO 定义
│       └── my-distro.conf
├── recipes-example/              ← 按功能分组的 Recipe 目录
│   ├── hello/
│   │   ├── hello_1.0.bb
│   │   └── files/
│   │       └── hello.c
│   └── myapp/
│       ├── myapp_git.bb
│       └── myapp.inc
├── recipes-core/                 ← 覆盖 OE-Core 的 Recipe
│   └── busybox/
│       └── busybox_1.36.1.bbappend
├── classes/                      ← 自定义 .bbclass
│   └── myapp.bbclass
├── files/                        ← 通用文件
│   └── common-license/
├── README                        ← 建议写清楚用途和依赖
└── COPYING.MIT
```

> Recipe 目录名建议用 `recipes-<功能>` 命名，方便管理。

---

## 六、常用管理命令

```bash
# 查看所有已启用的 Layer 及优先级
bitbake-layers show-layers

# 查看所有 Recipe（按 Layer 分组显示）
bitbake-layers show-recipes

# 查看某个 Recipe 来自哪个 Layer
bitbake -s | grep busybox
# 输出：busybox : 1.36.1 : meta

# 查看某个 Recipe 被哪些 .bbappend 影响了
bitbake-layers show-appends | grep busybox

# 添加 Layer
bitbake-layers add-layer /path/to/meta-custom

# 移除 Layer
bitbake-layers remove-layer meta-custom

# 创建新 Layer 骨架
bitbake-layers create-layer meta-myapp
# 会自动生成 conf/layer.conf 和 README

# 查看 Layer 依赖关系
bitbake-layers layerindex-fetch --show layer
```

---

## 七、常见问题

### Q1：添加 Layer 后 BitBake 报 "incompatible"

```
ERROR: Layer 'meta-raspberrypi' is not compatible with the core layer which
uses 'scarthgap' (layer is 'kirkstone')
```

**原因**：Layer 的 `LAYERSERIES_COMPAT` 写的是 `kirkstone`，但你用的 Yocto 是 `scarthgap`。

**解决**：编辑 Layer 的 `conf/layer.conf`，把兼容版本改成你用的：

```conf
- LAYERSERIES_COMPAT_meta-raspberrypi = "kirkstone"
+ LAYERSERIES_COMPAT_meta-raspberrypi = "scarthgap"
```

### Q2：添加了两个同名 Recipe，用了哪个？

```bash
# 查看哪个优先
bitbake -s | grep busybox

# 如果来自 meta(priority=5)，但你的 layer(priority=6) 没生效
# → 检查你的 layer.conf 中 BBFILE_PRIORITY 是否设对了
# → 检查你的 layer 目录结构是否和 meta 一致（recipes-core/busybox/）
```

### Q3：.bbappend 没生效

```bash
# 检查文件名是否匹配（版本号必须和 .bb 完全一致或使用 %）
# busybox_1.36.1.bb   →  busybox_1.36.1.bbappend ✅
# busybox_1.36.1.bb   →  busybox_%.bbappend       ✅  (% 通配任意版本)
# busybox_1.36.1.bb   →  busybox.bbappend          ❌  (没版本号，不匹配)

# 检查目录结构是否一致
# meta/recipes-core/busybox/busybox_1.36.1.bb
# meta-custom/recipes-core/busybox/busybox_1.36.1.bbappend  ✅
# meta-custom/recipes-extended/busybox/busybox_1.36.1.bbappend ❌
#                 ↑ 路径必须完全一致
```

---

## 八、速查索引

| 概念 | 文件 | 作用 |
|------|------|------|
| Layer 入口 | `bblayers.conf` | 列出所有启用的 Layer 路径 |
| Layer 自述 | `conf/layer.conf` | 声明注册名、范围、优先级、依赖、兼容版本 |
| 注册名 | `BBFILE_COLLECTIONS` | Layer 的唯一标识 |
| 管辖范围 | `BBFILE_PATTERN` | 正则表达式，匹配哪些 .bb 属于该 Layer |
| 优先级 | `BBFILE_PRIORITY` | 同名 Recipe 冲突时谁胜出（默认 5） |
| 必须依赖 | `LAYERDEPENDS` | 依赖的其他 Layer，缺了就报错 |
| 推荐依赖 | `LAYERRECOMMENDS` | 推荐的其他 Layer，没有不影响 |
| 兼容版本 | `LAYERSERIES_COMPAT` | 声明兼容的 Yocto 版本代号 |

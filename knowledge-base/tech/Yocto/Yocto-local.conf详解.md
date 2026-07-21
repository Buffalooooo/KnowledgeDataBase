---
tags: [技术/Yocto]
created: 2026-07-21
---

# Yocto local.conf 详解

## 概述

`build/conf/local.conf` 是 Yocto 构建的核心配置文件，控制**为目标设备构建什么样的系统**。它由 `oe-init-build-env` 自动生成模板，用户按需修改。

> 本章配套笔记：[[Yocto-构建系统深入]]

---

## 一、目标定义（必须配置）

```conf
MACHINE = "qemux86-64"
DISTRO  = "poky"
```

| 变量 | 作用 | 取值来源 |
|------|------|---------|
| `MACHINE` | 指定目标硬件平台 | `meta/conf/machine/` 或 BSP Layer 中预定义 |
| `DISTRO` | 发行版策略 | `meta-poky/conf/distro/` 或自定义 Layer |

**`MACHINE` 会影响**：内核架构、设备树、U-Boot 配置、包架构后缀名、QEMU 配置等。

**`DISTRO` 控制**：特性开关（`DISTRO_FEATURES`）、C 库选择（glibc/musl）、初始化系统（systemd/sysvinit）等。

> `DISTRO = ""` 表示不使用发行版策略，完全由 Recipe 默认行为决定，不推荐。

---

## 二、目录配置

```conf
TMPDIR     = "${TOPDIR}/tmp"
DL_DIR     = "${TOPDIR}/../downloads"
SSTATE_DIR = "${TOPDIR}/../sstate-cache"
```

| 变量 | 默认位置 | 内容 | 磁盘占用 | 建议 |
|------|---------|------|---------|------|
| `TMPDIR` | `build/tmp/` | 编译中间产物、日志、最终镜像 | **最大**（10-100GB） | 保持默认 |
| `DL_DIR` | `build/downloads/` | 下载的源码包 | 中等（2-10GB） | **移到 build 外**，跨项目共享 |
| `SSTATE_DIR` | `build/sstate-cache/` | 编译缓存 | 大（5-50GB） | **移到 build 外**，跨项目共享 |

**推荐布局**：

```
~/yocto/
├── downloads/              ← DL_DIR（所有项目共用）
├── sstate-cache/           ← SSTATE_DIR（所有项目共用）
└── poky/
    ├── build-qemu/         ← 项目 A
    │   └── tmp/            ← TMPDIR（各自独立）
    ├── build-raspi/        ← 项目 B
    │   └── tmp/
    └── build-arm/          ← 项目 C
        └── tmp/
```

这样切项目时无需重新下载源码和编译，省大量时间。

---

## 三、性能调优

### 并行度

```conf
# 自动检测 CPU 核心（推荐）
BB_NUMBER_THREADS = "${@bb.utils.cpu_count()}"
PARALLEL_MAKE     = "-j ${@bb.utils.cpu_count()}"
```

| 变量 | 含义 | 示例 |
|------|------|------|
| `BB_NUMBER_THREADS` | BitBake 同时执行多少个 Recipe | `4` = 同时构建 4 个 Recipe |
| `PARALLEL_MAKE` | 每个 Recipe 内 make 的并行度 | `-j 4` = 每个 Recipe 用 4 核编译 |

**注意**：总负载 ≈ `BB_NUMBER_THREADS × PARALLEL_MAKE` 的并发度。对于虚拟机，建议手动限制避免宿主机卡死：

```conf
# VM 分配了 4 核
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE     = "-j 4"
```

### 解析加速

```conf
# 用多个线程解析 Recipe（默认就是 cpu_count() 的一半，一般不用改）
BB_NUMBER_PARSE_THREADS = "${@bb.utils.cpu_count()}"
```

---

## 四、磁盘空间保护

Yocto 构建很容易把磁盘撑爆，新手最常见的问题就是"构建到一半报磁盘满"。这个配置能自动保护：

```conf
BB_DISKMON_DIRS = "\
    STOPTASKS,${TMPDIR},1G,100K \      # tmp < 1G 或 inode < 100K 时停止新任务
    STOPTASKS,${DL_DIR},1G,100K \      # downloads < 1G 时停止
    STOPTASKS,${SSTATE_DIR},1G,100K \  # sstate < 1G 时停止
    ABORT,${TMPDIR},100M,1K \          # tmp < 100M 直接终止构建
    ABORT,${DL_DIR},100M,1K"           # downloads < 100M 直接终止
```

**两种动作**：
- `STOPTASKS` — 不再启动新任务，但正在运行的任务继续执行完
- `ABORT` — 立即终止整个构建

**节省磁盘的常用技巧**：

```conf
# 构建完成后自动清理 tmp/work/ 下的中间文件（省几十 GB）
INHERIT += "rm_work"
```

> **注意**：开启 `rm_work` 后无法再查看 `tmp/work/<recipe>/temp/` 下的构建日志。调试阶段建议关闭，稳定后再开启。

---

## 五、包和镜像控制

### 包格式

```conf
# 三选一
PACKAGE_CLASSES = "package_ipk"
```

| 值 | 格式 | 包管理器 | 适用 |
|------|------|---------|------|
| `package_ipk` | IPK | `opkg` | 嵌入式默认推荐 |
| `package_deb` | DEB | `dpkg` / `apt` | 兼容 Debian 生态 |
| `package_rpm` | RPM | `rpm` / `dnf` | 企业级产品 |

### 镜像格式

```conf
# 可同时生成多种，用空格分隔
IMAGE_FSTYPES = "wic ext4 tar.bz2"
```

典型配置参考 [[Yocto-构建产物使用]]。

### 镜像内容

```conf
# 往镜像里额外安装包（不修改 Recipe）
CORE_IMAGE_EXTRA_INSTALL = " \
    openssh \
    htop \
    iperf3 \
    "

# 排除某些包
PACKAGE_EXCLUDE = "packagegroup-core-buildessential"
```

### 特性开关

```conf
# 额外功能特性
EXTRA_IMAGE_FEATURES = " \
    debug-tweaks \          # 允许 root 登录、空密码等调试便利
    ssh-server-openssh \    # 集成 SSH 服务
    tools-debug \           # gdb、strace 等调试工具
    "
```

`debug-tweaks` 在开发阶段几乎是必开的，否则 QEMU 控制台可能无法登录。

---

## 六、网络和缓存优化

### 包管理器源（目标设备上的 opkg 源）

```conf
# 告诉 BitBake 在构建根文件系统时从哪里下载 ipk
# 默认用本地生成的包，不需要配置
# 如果要用外部源：
PACKAGE_FEED_URIS = "http://myserver/ipk"
```

### 预构建缓存（加快首次构建）

```conf
# 从官方 sstate 服务器下载缓存（需要联网）
SSTATE_MIRRORS ?= "file://.* http://sstate.yoctoproject.org/all/PATH"

# 生成 sstate tarball 方便分发到其他机器
BB_GENERATE_MIRROR_TARBALLS = "1"
```

### 下载镜像源

```conf
# 如果官方源慢，配置国内镜像
PREMIRRORS ?= "\
    git://.*/.*   http://mirrors.ustc.edu.cn/yocto/ \n \
    ftp://.*/.*   http://mirrors.ustc.edu.cn/yocto/ \
    "
```

### 离线模式

```conf
# 完全禁止网络访问（所有源码必须已在 DL_DIR 中）
BB_NO_NETWORK = "1"
```

---

## 七、调试和分析

### 构建统计

```conf
# 记录每个任务的 CPU/内存/耗时（输出到 tmp/buildstats/）
INHERIT += "buildstats"

# 记录构建历史（镜像大小变化、包版本变化等）
INHERIT += "buildhistory"
BUILDHISTORY_COMMIT = "1"    # 每次构建后自动 git commit
```

`buildhistory` 启用后可以在 `build/buildhistory/` 下看到每次构建的差异：

```
buildhistory/
└── images/
    └── qemux86-64/
        ├── glibc/
        ├── core-image-minimal/
        │   ├── files-in-image.txt       # 镜像文件列表
        │   ├── installed-packages.txt    # 安装的包列表
        │   └── image-info.txt            # 镜像大小、时间戳
        └── busybox/
            └── ...
```

### 日志和调试

```conf
# 构建日志详细程度
BB_VERBOSE_LOGS = "1"          # 显示完整编译命令（默认是 @echo 简化）

# 任务失败时保留临时文件（默认失败会清理）
BBINCLUDELOGS = "yes"

# BitBake 服务器行为
BB_SERVER_TIMEOUT = "60"       # 服务器空闲超时秒数（0=不复用）
```

---

## 八、配置版本管理

```conf
# Yocto 版本升级时，local.conf 的格式可能变化
# 这两个变量控制版本兼容性检查
CONF_VERSION = "2"
LCONF_VERSION = "3"
```

当你的 Yocto 主版本升级后，BitBake 会检查版本号。如果不匹配，会提示你审查配置，避免旧配置在新版本下产生意外行为。

---

## 九、完整示例（开发环境推荐配置）

```conf
# ==================== 目标定义 ====================
MACHINE = "qemux86-64"
DISTRO  = "poky"

# ==================== 目录共享 ====================
DL_DIR        = "/home/user/yocto/downloads"
SSTATE_DIR    = "/home/user/yocto/sstate-cache"

# ==================== 性能 ====================
BB_NUMBER_THREADS = "${@bb.utils.cpu_count()}"
PARALLEL_MAKE     = "-j ${@bb.utils.cpu_count()}"

# ==================== 磁盘保护 ====================
BB_DISKMON_DIRS = "\
    STOPTASKS,${TMPDIR},1G,100K \
    STOPTASKS,${DL_DIR},1G,100K \
    STOPTASKS,${SSTATE_DIR},1G,100K \
    ABORT,${TMPDIR},100M,1K \
    ABORT,${DL_DIR},100M,1K"

# ==================== 包和镜像 ====================
PACKAGE_CLASSES  = "package_ipk"
IMAGE_FSTYPES    = "wic ext4 tar.bz2"
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
CORE_IMAGE_EXTRA_INSTALL = "openssh"

# ==================== 调试 ====================
INHERIT += "rm_work buildstats buildhistory"
BUILDHISTORY_COMMIT = "1"
BB_VERBOSE_LOGS = "1"

# ==================== 缓存加速 ====================
SSTATE_MIRRORS ?= "file://.* http://sstate.yoctoproject.org/all/PATH"
BB_GENERATE_MIRROR_TARBALLS = "1"

# ==================== 版本兼容 ====================
CONF_VERSION = "2"
```

---

## 十、速查索引

| 分组 | 变量 | 用途 |
|------|------|------|
| 目标 | `MACHINE`、`DISTRO` | 指定硬件平台和发行版 |
| 目录 | `TMPDIR`、`DL_DIR`、`SSTATE_DIR` | 构建和缓存路径 |
| 性能 | `BB_NUMBER_THREADS`、`PARALLEL_MAKE` | 并行构建控制 |
| 磁盘 | `BB_DISKMON_DIRS` | 自动保护磁盘空间 |
| 包 | `PACKAGE_CLASSES` | 包格式选择 |
| 镜像 | `IMAGE_FSTYPES`、`EXTRA_IMAGE_FEATURES` | 镜像格式和内容 |
| 网络 | `SSTATE_MIRRORS`、`PREMIRRORS`、`BB_NO_NETWORK` | 下载加速和离线 |
| 调试 | `buildstats`、`buildhistory`、`BB_VERBOSE_LOGS` | 分析和排查 |
| 版本 | `CONF_VERSION`、`LCONF_VERSION` | 配置兼容性 |

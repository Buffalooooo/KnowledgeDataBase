---
tags: [技术/Yocto]
created: 2026-07-16
---

# Yocto 构建系统深入

## 概述

本章深入理解 Yocto 构建过程中的目录结构、核心配置文件的作用，以及常用的调试命令。掌握这些内容后，你将能够独立分析构建问题、调整构建配置。

---

## 3.1 构建目录结构

执行 `source oe-init-build-env` 后，会在 `build/` 目录下生成以下结构：

### `tmp/` 核心目录树

```
build/
└── tmp/
    ├── deploy/              # 构建产物输出目录
    │   ├── images/          # 最终镜像文件（.wic, .tar.bz2, .ext4 等）
    │   │   └── <MACHINE>/   # 按目标机器分类
    │   ├── ipk/             # 若选择 IPK 包格式
    │   ├── deb/             # 若选择 DEB 包格式
    │   └── rpm/             # 若选择 RPM 包格式
    ├── work/                # 所有 Recipe 的工作目录（最核心）
    │   ├── <arch>/          # 架构，如 core2-64-poky-linux
    │   │   └── <recipe>/    # 配方名，如 busybox
    │   │       └── <version>/  # 版本号，如 1.36.1
    │   │           ├── temp/        # 日志和运行脚本
    │   │           │   ├── log.do_compile   # 编译日志
    │   │           │   ├── log.do_fetch     # 下载日志
    │   │           │   ├── run.do_compile   # 编译运行的 shell 脚本
    │   │           │   └── run.do_fetch     # 下载运行的 shell 脚本
    │   │           ├── image/       # do_install 后的镜像目录（即 ${D}）
    │   │           ├── packages-split/  # 分割后的包目录
    │   │           ├── sysroot-destdir/ # 安装到 sysroot 的目录
    │   │           ├── source-date-epoch  # 源码时间戳
    │   │           ├── *.tgz / *.tar.zst  # 打包后的源码归档
    │   │           ├── deploy-*           # 各任务产生的部署文件
    │   │           └── recipe-sysroot/    # 该 Recipe 的构建时 sysroot
    │   └── shared/          # 共享的中间输出
    ├── stamps/              # 任务完成标记文件（空文件，用于跟踪任务状态）
    ├── sysroots/            # 所有 Recipe 的 sysroot 汇总
    │   ├── <arch>/          # 目标系统的 sysroot
    │   └── x86_64-linux/   # 宿主机工具的 sysroot
    └── work-shared/         # 跨架构共享的工作目录（如内核源码）
```

### 关键子目录详解

| 目录 | 说明 |
|------|------|
| `tmp/deploy/images/<MACHINE>/` | 最终产物 — 烧录到设备的镜像文件 |
| `tmp/work/<arch>/<recipe>/<version>/` | 每个 Recipe 的独立工作空间 |
| `tmp/work/.../temp/` | 调试核心 — 日志和执行的 shell 脚本都在这里 |
| `tmp/work/.../image/` | `do_install` 阶段安装的文件（即 `${D}`）  |
| `tmp/work/.../packages-split/` | 包分割后的结果，验证包内容是否完整 |
| `tmp/stamps/` | BitBake 判断任务是否需要重新执行的依据 |

> **调试技巧**：构建失败时，优先看 `tmp/work/<arch>/<recipe>/<version>/temp/log.do_*` 和 `run.do_*`，前者告诉你在哪一步出错，后者让你看到实际执行的命令。

---

## 3.2 local.conf 详解

`build/conf/local.conf` 是 Yocto 构建的主要配置文件。以下是关键变量及其作用：

### 核心变量

| 变量 | 示例 | 说明 |
|------|------|------|
| `MACHINE` | `MACHINE = "qemux86-64"` | 指定目标硬件平台 |
| `DISTRO` | `DISTRO = "poky"` | 发行版策略配置 |
| `TMPDIR` | `TMPDIR = "${TOPDIR}/tmp"` | 构建临时目录路径 |
| `DL_DIR` | `DL_DIR = "${TOPDIR}/../downloads"` | 源码下载缓存目录，建议跨项目共享 |
| `SSTATE_DIR` | `SSTATE_DIR = "${TOPDIR}/../sstate-cache"` | 共享状态缓存目录，建议跨项目共享 |
| `PACKAGE_CLASSES` | `PACKAGE_CLASSES = "package_ipk"` | 包格式：`package_ipk`、`package_deb`、`package_rpm` |

### 并行构建

```conf
# CPU 核心数与 BitBake 任务数的关系
BB_NUMBER_THREADS = "4"        # BitBake 同时执行的任务数
PARALLEL_MAKE = "-j 4"         # make 的并行编译选项

# 推荐：直接让 BitBake 自动检测
BB_NUMBER_THREADS = "${@bb.utils.cpu_count()}"
PARALLEL_MAKE = "-j ${@bb.utils.cpu_count()}"
```

### 常用配置项

```conf
# 磁盘空间监控（构建过程中检查剩余空间）
BB_DISKMON_DIRS = "\
    STOPTASKS,${TMPDIR},1G,100K \
    STOPTASKS,${DL_DIR},1G,100K \
    STOPTASKS,${SSTATE_DIR},1G,100K \
    ABORT,${TMPDIR},500M,1K \
    ABORT,${DL_DIR},500M,1K"

# 启用镜像（加速首次构建，从预构建服务器下载）
BB_GENERATE_MIRROR_TARBALLS = "1"

# 网络访问
BB_NO_NETWORK = "0"            # 1 表示离线构建模式

# 调试信息
INHERIT += "rm_work"           # 构建完成后自动清理工作目录（节省磁盘）
INHERIT += "buildstats"        # 记录构建统计信息
INHERIT += "buildhistory"      # 记录构建历史，跟踪大小变化
```

> **建议**：`DL_DIR` 和 `SSTATE_DIR` 最好设置到 `build/` 目录之外（如 `~/yocto/downloads`），这样不同项目间可以共享缓存，避免重复下载和编译。

---

## 3.3 bblayers.conf 与 Layer 概念

### 文件结构

`build/conf/bblayers.conf` 的内容示例：

```conf
# POKY_BBLAYERS_CONF_VERSION 用于检查版本兼容性
BBLAYERS_LAYERINDEX_URLS ?= "layers.openembedded.org"
BBLAYERS_LAYERINDEX_API_VERSION ?= "1"

BBLAYERS ?= " \
  /path/to/poky/meta \
  /path/to/poky/meta-poky \
  /path/to/poky/meta-yocto-bsp \
  "
```

### 理解 `BBLAYERS`

- `BBLAYERS` 列出所有启用的 Layer 的**绝对路径**
- BitBake 按 Layer 在 `BBLAYERS` 中出现的**顺序**加载 Recipe
- 后加载的 Layer 中的 Recipe 会覆盖先加载的同名 Recipe

### Layer 优先级（BBFILE_PRIORITY）

每个 Layer 有一个优先级，数值越大优先级越高：

```conf
# 在 meta-custom/conf/layer.conf 中
BBFILE_PRIORITY_meta-custom = "10"
```

默认优先级通常是：
- `meta` (OE-Core)：5
- `meta-poky`：5
- `meta-yocto-bsp`：5
- `meta-<vendor>`：通常 5-8
- 自定义 Layer 建议设为 6-10，确保能覆盖默认行为

> **优先级机制**：当两个 Layer 提供同名的 `.bb` 文件时，优先级高的 Layer 生效。当使用 `.bbappend` 时，所有匹配的 `.bbappend` 都会应用到基础 Recipe 上，优先级影响执行顺序。

### Layer 命名规范

- 名称以 `meta-` 开头（约定而非强制，但强烈建议遵守）
- 放在 `sources/` 或 `layers/` 目录下统一管理

### Layer 的检索机制

BitBake 怎么知道去哪里找 Layer？流程如下：

```
bblayers.conf          ← 入口：列出所有 Layer 的绝对路径
     │
     ▼
  每个 Layer 目录       ← BitBake 进入每个路径
     │
     ▼
  conf/layer.conf       ← 关键：有这个文件才算 Layer
     │
     ├── BBFILE_COLLECTIONS    →  Layer 的标识名（如 "core"）
     ├── BBFILE_PATTERN_core   →  哪些 .bb 文件属于该 Layer
     ├── BBFILE_PRIORITY_core  →  优先级（决定覆盖关系）
     ├── LAYERDEPENDS_core     →  依赖的其他 Layer
     └── LAYERSERIES_COMPAT_core → 兼容的 Yocto 版本
     │
     ▼
  扫描 .bb / .bbappend  ← 注册到 BitBake 的 Recipe 数据库
```

**关键点**：
- `bblayers.conf` 没写的 Layer，即使磁盘上有目录也不会被加载
- 添加 Layer 用 `bitbake-layers add-layer <path>`，或手动编辑 `bblayers.conf`
- BitBake 不会递归搜索子目录，只扫描 `BBFILE_PATTERN` 匹配范围内的 `.bb` 文件

**判断一个目录是不是 Layer**：不看目录名是否以 `meta-` 开头，而是看有没有 `conf/layer.conf`。

### 常用命令

```bash
# 列出所有已启用的 Layer
bitbake-layers show-layers

# 列出所有可用 Recipe（按 Layer 分组）
bitbake-layers show-recipes

# 查看特定 Recipe 来自哪个 Layer
bitbake-layers show-recipes <recipe-name>
```

---

## 3.4 基本调试命令

### `bitbake -e` — 展开所有变量

```bash
# 查看某个变量的值
bitbake -e core-image-minimal | grep ^TMPDIR=

# 查看 Recipe 级别的变量
bitbake -e busybox | grep ^PV=
```

> `-e` 会展开所有全局变量和 Recipe 变量，是调试配置问题的**第一利器**。

### `bitbake -s` — 搜索 Recipe

```bash
# 搜索所有可用的 Recipe
bitbake -s | grep busybox

# 搜索结果格式：busybox : 1.36.1 : meta-core
```
> `-s` 显示 Recipe 名称、版本号和所属 Layer。

### `bitbake -g` — 生成依赖图

```bash
# 生成依赖图
bitbake -g core-image-minimal

# 这会生成两个文件：
#   - recipe-depends.dot：Recipe 级依赖
#   - pn-depends.dot：包名级依赖
#
# 可以配合 graphviz 可视化：
#   dot -Tpng recipe-depends.dot -o deps.png
```

### `bitbake -c devshell` — 进入开发 Shell

```bash
# 进入某个 Recipe 的开发 Shell（在构建环境中）
bitbake -c devshell busybox

# 这会打开一个 shell，环境变量已设置好
# 工作目录为 ${S}（源码目录）
# 可以在此手动执行配置、编译命令进行调试
```

### `bitbake -c listtasks` — 查看所有任务

```bash
# 列出 Recipe 的所有可用任务
bitbake -c listtasks busybox
```

### `bitbake -C` — 强制重新执行任务

```bash
# 强制重新执行 do_compile 及其下游任务
bitbake -C compile busybox
```

> **与 `-f` 的区别**：`-f`（force）强制重新运行指定任务但不清理 Stamp 文件，`-C`（clear）会先清除 Stamp 再运行。推荐用 `-C`，行为更可预测。

### `bitbake -c clean` 与 `bitbake -c cleanall`

```bash
# 只清理工作目录
bitbake -c clean busybox

# 清理工作目录 + 删除下载的源码 + 删除 sstate 缓存
bitbake -c cleanall busybox
```

> **小心**：`cleanall` 会删除 `DL_DIR` 中的下载缓存，下次构建需要重新下载。通常使用 `clean` 即可。

---

## 3.5 调试常见场景

### 场景 1：某 Recipe 构建失败

```bash
# 1. 查看构建日志
less tmp/work/<arch>/<recipe>/<version>/temp/log.do_compile

# 2. 查看实际执行的 shell 命令
less tmp/work/<arch>/<recipe>/<version>/temp/run.do_compile

# 3. 进入开发 shell 手动调试
bitbake -c devshell <recipe>
```

### 场景 2：变量不符合预期

```bash
# 展开所有变量并搜索
bitbake -e <recipe> | grep ^<VARIABLE>=
```

### 场景 3：依赖问题

```bash
# 生成依赖图并查看
bitbake -g <target>
grep <recipe> pn-depends.dot
```

### 场景 4：Layer 优先级冲突

```bash
# 查看某个 Recipe 来自哪个 Layer
bitbake -s | grep <recipe>

# 查看 Layer 优先级
bitbake-layers show-layers
```

---

## 3.6 SSTATE 加速原理（进阶）

Yocto 的共享状态缓存（Shared State Cache）是加速构建的关键机制：

```
                     ┌─────────────┐
                     │   Hash 计算  │
                     │ (task hash)  │
                     └──────┬──────┘
                            │
                    ┌───────┴───────┐
                    │  SSTATE_DIR 中 │
                    │  是否有匹配？   │
                    └───┬───┬───┬───┘
                   Yes  │   │   │  No
              ┌─────────┘   │   └──────────┐
              ▼             │              ▼
        ┌──────────┐       │        ┌──────────┐
        │ 恢复缓存  │       │        │ 完整执行  │
        │ (setscene)│       │        │ 所有任务  │
        └──────────┘       │        └──────────┘
                           ▼
                    ┌──────────────┐
                    │ 源码/配置变化 │
                    │ → Hash 变化  │
                    │ → 重新构建   │
                    └──────────────┘
```

- 当 `SSTATE_DIR` 中有匹配的缓存时，BitBake 执行 `do_*_setscene` 任务恢复缓存
- 缓存通过任务输入的签名（Signature/Hash）来匹配
- 输入没有变化 → 使用缓存；输入变化 → 重新构建
- `SSTATE_MIRRORS` 可配置远程 sstate 服务器，进一步加速

---

## 3.7 包格式与镜像格式

> 本章节内容已移出到独立文档 → [[Yocto-构建产物使用]]
> 
> 包含：ipk/deb/rpm 包格式对比、wic/ext4/tar/squashfs/ubifs 镜像格式详解、
> 各格式的详细使用方式（烧录/挂载/运行/QEMU/chroot/容器化）、
> 不同镜像 rootfs 内容一致性的验证、生产环境选型建议。

---

## 验收清单

- [ ] 能说出 `tmp/work/` 下的目录含义
- [ ] 能独立修改 `local.conf` 的常用配置
- [ ] 掌握 3 个以上调试命令
- [ ] 理解 SSTATE 加速机制基本原理

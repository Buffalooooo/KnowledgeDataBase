---
tags: [技术/Yocto]
created: 2026-06-20
---

# Yocto 概述

## 概述

Yocto 是一个**开源协作项目**，提供模板、工具和方法来创建定制 Linux 系统。它不是 Linux 发行版，而是一套**构建系统**，用于为嵌入式设备、IoT、工业控制等场景生成自定义 Linux 系统。

### 一句话理解

> Yocto = 一个可以让你像搭积木一样定制嵌入式 Linux 系统的工具集合

---

## 核心概念

### Poky
Yocto 的**参考构建系统**，相当于一个"样板工程"，包含了两大核心组件：
- **BitBake** — 任务执行引擎（负责"怎么做"）
- **OE-Core** — 核心 Recipe 和类的集合（负责"做什么"）

可以理解为：Poky = BitBake（引擎）+ OE-Core（配方库）

### BitBake
- 类似 `make`，但功能更强大
- 负责解析 Recipe（配方），按依赖关系执行任务
- 支持任务并行执行
- 任务示例：`do_fetch`（下载）、`do_compile`（编译）、`do_install`（安装）

### Recipe（配方）
- 文件后缀：`.bb`
- 描述如何构建一个软件包
- 包含：源码地址、依赖、编译方法、安装方法等

### Layer（层）
- Recipe 和配置文件的集合，按功能分组
- 常见 Layer：`meta-raspberrypi`（树莓派支持）、`meta-qt5`（Qt5 支持）
- 命名规范：`meta-` 前缀

### Machine（机器）
- 目标硬件平台的定义
- 包含：CPU 架构、设备树、内核配置等
- 示例：`qemux86-64`、`raspberrypi3-64`

### Distribution（发行版）
- 系统级配置策略
- 控制：特性开关（Wi-Fi、蓝牙等）、C 库选择、初始化系统等

### Image（镜像）
- 最终生成的系统镜像
- 示例：`core-image-minimal`（最小镜像）、`core-image-sato`（带 GUI 的镜像）

---

## 核心概念关系图

```
Poky (参考构建系统)
├── BitBake (构建引擎)
├── OE-Core (核心配方)
└── meta-yocto-bsp (参考板级支持)

用户自定义
├── meta-mylayer (你的 Layer)
│   ├── recipes-example/hello/hello_1.0.bb (Recipe)
│   └── conf/machine/myboard.conf (Machine)
└── build/conf/local.conf (构建配置)
       │
       ▼
   bitbake core-image-minimal
       │
       ▼
   tmp/deploy/images/qemux86-64/core-image-minimal-qemux86-64.wic
```

---

## 与 Buildroot 对比

| 特性 | Yocto | Buildroot |
|------|-------|-----------|
| 学习曲线 | 陡峭 | 平缓 |
| 灵活性 | 极高 | 中等 |
| 包数量 | 上万 | 数千 |
| 构建时间 | 长 | 短 |
| 企业使用 | 广泛 | 较少 |
| 适用场景 | 复杂产品 | 简单设备 |

---

## 版本命名规则

Yocto 版本以动物命名，按字母顺序：
- `scarthgap`（当前 LTS 版本）
- `mickledore`
- `kirkstone`（上一个 LTS）

---

## 要点

1. **Yocto 是构建系统，不是发行版** — 它帮你"做"Linux，不是直接"用"Linux
2. **Layer 是模块化核心** — 每个功能独立分层，方便复用和维护
3. **BitBake 是心脏** — 所有构建任务都由它编排执行
4. **Recipe 是基本单元** — 每个软件包有自己的一份"简历"
5. **学习曲线陡峭但值得** — 掌握后可以精确控制 Linux 系统的每个方面

---

## 参考

- [Yocto 官方手册](https://docs.yoctoproject.org/)
- [Yocto Overview and Concepts Manual](https://docs.yoctoproject.org/overview-manual/)
- [BitBake 用户手册](https://docs.yoctoproject.org/bitbake/)
- [OE-Core 源码](https://github.com/openembedded/openembedded-core)
- [Poky 源码](https://git.yoctoproject.org/poky)

---
tags: [技术/Yocto]
created: 2026-06-20
---

# Yocto 环境搭建

## 概述

Yocto 构建环境基于 Ubuntu 系统。依赖包分为两类：**基础开发工具**和 **Yocto 专有依赖**，已备有一键安装脚本。

---

## 依赖说明

### 基础开发工具（gcc/git/ssh 等）

包括：编译器、版本控制、网络工具、编辑器、系统监控等。

> 一键脚本：`scripts/setup-dev-env.sh`

```bash
chmod +x setup-dev-env.sh
./setup-dev-env.sh
```

### Yocto 专有依赖（构建系统需要）

| 包 | 作用 |
|------|------|
| `gawk` | BitBake 内部解析 |
| `diffstat` | 文件差异统计 |
| `texinfo` | 文档构建 |
| `chrpath` / `socat` / `cpio` | 构建工具链所需 |
| `zstd` / `liblz4-tool` | sstate-cache 高速压缩 |
| `python3-pexpect` / `python3-git` / `python3-jinja2` / `python3-subunit` | BitBake Python 扩展 |
| `libegl1-mesa` / `libsdl1.2-dev` / `mesa-common-dev` | QEMU 图形显示 |
| `debianutils` / `iputils-ping` | 网络工具 |
| `xterm` | QEMU 终端 |

> 一键脚本：`scripts/setup-yocto-deps.sh`

```bash
chmod +x setup-yocto-deps.sh
./setup-yocto-deps.sh
```

### 两条命令完成

```bash
# Step 1: 基础环境
./setup-dev-env.sh

# Step 2: Yocto 专有依赖
./setup-yocto-deps.sh
```

---

## 安装 Poky

```bash
git clone git://git.yoctoproject.org/poky
cd poky
git checkout scarthgap          # 切换到当前 LTS 版本
```

---

## 第一次构建

```bash
# 初始化构建环境
source oe-init-build-env

# 构建最小镜像
bitbake core-image-minimal

# 在 QEMU 中运行
runqemu qemux86-64
```

---

## 要点

- [x] 确认宿主机系统（Ubuntu 26.04 LTS）
- [x] 安装基础开发依赖
- [x] 安装 Yocto 专有依赖
- [ ] 克隆 Poky 并切换分支
- [ ] 初始化构建环境
- [ ] 理解 local.conf 和 bblayers.conf
- [ ] 第一次构建 core-image-minimal
- [ ] 在 QEMU 中运行镜像

## 环境信息

<!-- 记录你的实际环境参数 -->

| 项目 | 值 |
|------|-----|
| 宿主机系统 | Ubuntu 26.04 LTS |
| 架构 | x86-64 |
| 内存 | |
| 磁盘剩余 | |
| Poky 版本 | scarthgap（LTS） |

## 安装命令记录

<!-- 记录实际执行过的命令 -->

## 遇到的问题

| 问题 | 原因 | 解决 |
|------|------|------|
| VM GUI 卡顿休眠 | VMware + Ubuntu 26.04 兼容 | 禁用休眠 + SSH 管理 |

## 参考

- [Yocto Project Quick Build](https://docs.yoctoproject.org/brief-yoctoprojectqs/)
- [Yocto Project Development Tasks Manual](https://docs.yoctoproject.org/dev-manual/)
- 安装脚本：`scripts/setup-dev-env.sh`
- 安装脚本：`scripts/setup-yocto-deps.sh`

---
tags: [技术/Yocto]
created: 2026-06-20
---

# Yocto 环境搭建

## 概述

Yocto 构建环境基于 Ubuntu 系统。依赖包分为两类：**基础开发工具**和 **Yocto 专有依赖**，已备有一键安装脚本。

---

## 要点

- [x] 确认宿主机系统（Ubuntu 26.04 LTS）
- [x] 安装基础开发依赖
- [x] 安装 Yocto 专有依赖
- [x] 克隆 Poky
- [ ] 切换分支（scarthgap）
- [ ] 初始化构建环境
- [ ] 理解 local.conf 和 bblayers.conf
- [ ] 第一次构建 core-image-minimal
- [ ] 在 QEMU 中运行镜像

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
| `zstd` / `liblz4-tool` / `lz4` | sstate-cache 高速压缩（`lz4` 提供 `lz4c` 命令） |
| `libcrypt-dev` | Python _crypt 模块编译支持 |
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

```bash
# 注：git.yoctoproject.org 无法直连，换用 GitHub 镜像
git clone https://github.com/yoctoproject/poky.git
```

## 遇到的问题

### 1. VM GUI 卡顿休眠

**现象**：VMware 中 Ubuntu 26.04 的 GUI 界面卡顿并休眠

**原因**：VMware + Ubuntu 26.04 兼容问题

**解决方案**：禁用休眠 + 使用 SSH 管理

---

### 2. git.yoctoproject.org 连接被拒

**现象**：`git clone git://git.yoctoproject.org/poky` 返回 `Connection refused`

**原因**：该域名被 GFW 屏蔽 / 网络限制，无法直连

**解决方案**：
- **方法一**（已验证）：换用 GitHub 镜像
  ```bash
  git clone https://github.com/yoctoproject/poky.git
  ```
- **方法二**（未验证）：通过代理后直连官方源
  ```bash
  git config http.proxy http://<代理IP>:<端口>
  git clone https://git.yoctoproject.org/poky
  ```

---

### 3. VM 内 git clone 连不上 GitHub

**现象**：VM（Ubuntu）内 `git clone` 超时，提示 `Connection reset by peer`

**原因**：VMware NAT 模式下，VM 网络流量不经过宿主机 VPN，即使宿主机开了 VPN 也无法访问外网

**解决方案**：宿主机代理软件开启「允许局域网连接」（Allow LAN）即可。

---

### 4. BitBake 报错 lz4c 找不到

**现象**：执行 `bitbake` 时报错 `lz4c` 不在 PATH 中

**原因**：`liblz4-tool` 包不提供 `lz4c` 命令，需要额外安装 `lz4` 包

**解决方案**：
```bash
sudo apt install lz4 -y
```
同步更新了安装脚本 `scripts/setup-yocto-deps.sh`，已加入 `lz4` 包。

---

### 5. AppArmor 限制 User Namespace 导致 BitBake 报错

**现象**：运行 `bitbake` 时报错 `User namespaces are not usable by BitBake, possibly due to AppArmor`

**原因**：Ubuntu 24.04+ 默认限制非特权用户命名空间（User Namespace），BitBake 依赖此功能

**解决方案**：

**方法一**（已验证）：临时关闭限制，立即生效
```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

**方法二**：永久关闭限制
```bash
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee -a /etc/sysctl.d/99-bitbake.conf
sudo sysctl -p /etc/sysctl.d/99-bitbake.conf
```

**方法三**：如果内核参数名不同，尝试
```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1
```

---

### 6. python3-native 构建失败 — 缺少 _crypt 模块

**现象**：`bitbake core-image-minimal` 在构建 `python3-native` 时报错：
```
The necessary bits to build these optional modules were not found:
_crypt
```
`do_install` 阶段退出码 1，构建终止。

**原因**：宿主机缺少 `libcrypt-dev`，导致 Python 3.12 的 `_crypt` 模块无法编译。

**解决方案**：
```bash
sudo apt install libcrypt-dev -y
bitbake python3-native -c cleansstate
bitbake core-image-minimal
```
同步更新了安装脚本 `scripts/setup-yocto-deps.sh`，已加入 `libcrypt-dev` 包。


## 参考

- [Yocto Project Quick Build](https://docs.yoctoproject.org/brief-yoctoprojectqs/)
- [Yocto Project Development Tasks Manual](https://docs.yoctoproject.org/dev-manual/)
- 安装脚本：`scripts/setup-dev-env.sh`
- 安装脚本：`scripts/setup-yocto-deps.sh`

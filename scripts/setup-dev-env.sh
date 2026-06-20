#!/bin/bash
# =============================================
# 🚀 Ubuntu 开发环境一键安装脚本
# 适用：Ubuntu 20.04 / 22.04 / 24.04 / 26.04
# 平台：VMware / 物理机 / 其他虚拟机
# =============================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

# =============================================
# 进度条函数
# =============================================
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local bar_len=40
    local filled=$((percent * bar_len / 100))
    local empty=$((bar_len - filled))

    printf "\r${BLUE}[%-${bar_len}s${NC}] %3d%% %s" \
        "$(printf '#%.0s' $(seq 1 $filled))$(printf ' %.0s' $(seq 1 $empty))" \
        "$percent" "$message"
}

# =============================================
# 检测系统环境
# =============================================
detect_env() {
    echo ""
    echo "============================================"
    echo "  系统环境检测"
    echo "============================================"

    # 系统版本
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        info "系统: $NAME $VERSION_ID"
    else
        warn "无法检测系统版本"
    fi

    # 架构
    info "架构: $(uname -m)"

    # 内存
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    info "内存: ${total_mem}MB"

    # 磁盘
    disk_free=$(df -h / | awk 'NR==2{print $4}')
    info "磁盘剩余: ${disk_free}"

    # CPU 核心数
    cpu_cores=$(nproc)
    info "CPU 核心: ${cpu_cores}"
    echo ""

    # 检测 VMware 工具
    echo "--------------------------------------------"
    echo "  VMware 状态"
    echo "--------------------------------------------"
    if systemctl is-active --quiet open-vm-tools 2>/dev/null; then
        ok "open-vm-tools 运行中"
    else
        warn "open-vm-tools 未运行"
    fi

    # 检测共享目录
    if [ -d /mnt/hgfs ]; then
        hgfs_count=$(ls /mnt/hgfs/ 2>/dev/null | wc -l)
        if [ "$hgfs_count" -gt 0 ]; then
            ok "共享目录已挂载 ($(ls /mnt/hgfs/ | tr '\n' ' '))"
        else
            warn "共享目录已创建但为空，可能需要配置 VMware 共享文件夹"
        fi
    fi
}

# =============================================
# 检测已安装的包
# =============================================
check_packages() {
    echo ""
    echo "============================================"
    echo "  检测已安装/未安装的软件包"
    echo "============================================"

    local packages=(
        # ===== 编译与构建 =====
        "build-essential:编译基础 (gcc/g++)"
        "gcc:gcc 编译器"
        "g++:g++ 编译器"
        "make:make 构建工具"
        "cmake:cmake 构建工具"
        "autoconf:autoconf 源码配置"
        "automake:automake Makefile 生成"
        "libtool:libtool 库管理工具"
        "pkg-config:pkg-config 编译参数检测"

        # ===== 版本控制 =====
        "git:Git 版本控制"

        # ===== 开发库头文件（编译 Python / C 扩展需要）=====
        "libssl-dev:SSL 开发库"
        "libffi-dev:FFI 开发库"
        "zlib1g-dev:zlib 压缩库"
        "libbz2-dev:bzip2 压缩库"
        "libreadline-dev:readline 库"
        "libsqlite3-dev:SQLite3 开发库"
        "libncurses-dev:ncurses 终端界面库"
        "libgdbm-dev:GDBM 数据库库"
        "liblzma-dev:XZ 压缩库"

        # ===== Python =====
        "python3:Python3 解释器"
        "python3-pip:Python3 pip 包管理器"
        "python3-venv:Python3 虚拟环境"
        "python3-dev:Python3 开发头文件"

        # ===== SSH 与远程 =====
        "openssh-server:SSH 服务端（远程登录）"
        "openssh-client:SSH 客户端"
        "sshfs:SSHFS 远程目录挂载"
        "rsync:rsync 文件同步"

        # ===== 网络工具 =====
        "curl:cURL 下载"
        "wget:wget 下载"
        "net-tools:网络工具 (ifconfig/netstat/route)"
        "iproute2:路由工具 (ip/ss)"
        "dnsutils:DNS 查询 (dig/nslookup)"
        "nmap:nmap 端口扫描"
        "telnet:telnet 网络测试"
        "traceroute:traceroute 路由追踪"
        "lsof:lsof 端口/文件查看"
        "ethtool:ethtool 网卡信息"
        "iperf3:iperf3 网络性能测试"
        "bridge-utils:网桥管理 (brctl)"

        # ===== 压缩与归档 =====
        "zip:zip 压缩"
        "unzip:unzip 解压"
        "tar:tar 归档"
        "p7zip-full:7z 高压缩比压缩"
        "unrar:unrar 解压 RAR"
        "bzip2:bzip2 压缩"

        # ===== 系统监控 =====
        "htop:htop 进程监控"
        "iotop:iotop 磁盘 I/O 监控"
        "nethogs:nethogs 按进程流量监控"
        "dstat:dstat 系统资源统计"
        "sysstat:sysstat (sar/iostat/mpstat)"

        # ===== 编辑器与终端 =====
        "vim:vim 编辑器"
        "nano:nano 编辑器"
        "gedit:gedit 图形化文本编辑器"
        "screen:screen 终端复用"
        "tmux:tmux 终端复用（增强版）"
        "bash-completion:命令补全增强"

        # ===== 文件与文本处理 =====
        "tree:tree 目录树"

        # ===== 数据库客户端 =====
        # ===== VMware 集成（仅 VMware 下有用）=====
        "open-vm-tools:VMware 基础工具"
        "open-vm-tools-desktop:VMware 桌面集成"
    )

    local missing=()
    local installed=()
    local package_names=""

    for pkg_info in "${packages[@]}"; do
        pkg_name="${pkg_info%%:*}"
        pkg_desc="${pkg_info#*:}"
        if dpkg -s "$pkg_name" &>/dev/null; then
            installed+=("$pkg_name")
            ok "✓ $pkg_desc"
        else
            missing+=("$pkg_name")
            warn "✗ $pkg_desc"
        fi
    done

    echo ""
    echo "--------------------------------------------"
    echo "  统计"
    echo "--------------------------------------------"
    ok "已安装: ${#installed[@]} 个"
    warn "未安装: ${#missing[@]} 个"
    echo ""

    # 返回未安装的包列表
    MISSING_PACKAGES=("${missing[@]}")
}

# =============================================
# 安装函数（带进度条）
# =============================================
install_with_progress() {
    local packages=("$@")
    local total=${#packages[@]}
    local current=0

    if [ "$total" -eq 0 ]; then
        info "所有包已安装，无需操作"
        return 0
    fi

    # 计算总安装步骤（更新 + 升级 + 每个包安装）
    local total_steps=$((total + 3))

    echo "============================================"
    echo "  开始安装 ${total} 个包"
    echo "============================================"
    echo ""

    # Step 1: apt update
    current=$((current + 1))
    show_progress $current $total_steps "更新软件源..."
    sudo apt-get update -qq 2>/dev/null
    echo ""

    # Step 2: apt upgrade (without prompts)
    current=$((current + 1))
    show_progress $current $total_steps "升级现有包..."
    sudo apt-get upgrade -y -qq 2>/dev/null
    echo ""

    # Step 3: 安装所有缺失包（一次性安装，避免多个进度条）
    current=$((current + 1))
    show_progress $current $total_steps "安装 ${total} 个包..."
    echo ""

    # 分成小批量安装，避免命令过长
    local batch=()
    local batch_count=0
    for pkg in "${packages[@]}"; do
        batch+=("$pkg")
        batch_count=$((batch_count + 1))

        # 每 20 个包一批，或最后一包
        if [ ${#batch[@]} -ge 20 ] || [ "$batch_count" -eq "$total" ]; then
            if ! sudo apt-get install -y -qq "${batch[@]}" 2>/dev/null; then
                # 如果批量失败，逐个重试
                for single in "${batch[@]}"; do
                    sudo apt-get install -y "$single" 2>/dev/null || warn "安装 $single 失败"
                done
            fi
            batch=()
        fi

        current=$((current + 1))
        show_progress $current $total_steps "安装: $pkg..."
        echo ""
    done

    echo ""
    show_progress $total_steps $total_steps "安装完成！"
    echo ""
    echo ""
}

# =============================================
# 配置共享目录自动挂载
# =============================================
setup_vmware_shared() {
    echo ""
    echo "============================================"
    echo "  配置 VMware 共享目录自动挂载"
    echo "============================================"

    # 确保 open-vm-tools 已安装
    if ! dpkg -s open-vm-tools &>/dev/null; then
        warn "open-vm-tools 未安装，跳过共享目录配置"
        return 1
    fi

    # 创建挂载点
    if [ ! -d /mnt/hgfs ]; then
        sudo mkdir -p /mnt/hgfs
        ok "创建挂载点 /mnt/hgfs"
    fi

    # 检查 vmhgfs 模块是否可用
    if lsmod | grep -q vmhgfs 2>/dev/null; then
        ok "vmhgfs 内核模块已加载"
    else
        warn "vmhgfs 模块未加载，尝试加载..."
        sudo modprobe vmhgfs 2>/dev/null && ok "vmhgfs 加载成功" || warn "vmhgfs 加载失败（重启后可能正常）"
    fi

    # 确保 vmware-tools 服务已启用
    sudo systemctl enable open-vm-tools 2>/dev/null
    sudo systemctl restart open-vm-tools 2>/dev/null

    # 尝试挂载
    if mountpoint -q /mnt/hgfs 2>/dev/null; then
        ok "共享目录已挂载"
    else
        warn "共享目录未自动挂载，尝试手动挂载..."
        sudo vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other 2>/dev/null && \
            ok "手动挂载成功" || warn "手动挂载失败（请在 VMware 设置中添加共享文件夹后重启）"
    fi

    # 检查挂载状态，成功后创建桌面快捷方式
    if mountpoint -q /mnt/hgfs 2>/dev/null && ls /mnt/hgfs/ | grep -q .; then
        # 查找桌面目录
        for desktop_dir in "$HOME/Desktop" "$HOME/桌面"; do
            if [ -d "$desktop_dir" ]; then
                local symlink_target="$desktop_dir/Shared"
                if [ ! -L "$symlink_target" ]; then
                    ln -sf /mnt/hgfs "$symlink_target"
                    ok "桌面快捷方式已创建: $symlink_target → /mnt/hgfs"
                else
                    ok "桌面快捷方式已存在: $symlink_target"
                fi
                break
            fi
        done
    fi

    # 添加开机自动挂载（通过 systemd 服务）
    local service_name="vmware-shared-folders.service"
    local service_path="/etc/systemd/system/${service_name}"

    if [ ! -f "$service_path" ]; then
        info "创建开机自启服务..."
        sudo tee "$service_path" > /dev/null << 'EOF'
[Unit]
Description=Mount VMware Shared Folders
After=open-vm-tools.service
Requires=open-vm-tools.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
ExecStop=/bin/fusermount -u /mnt/hgfs

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable "${service_name}" 2>/dev/null
        ok "开机自启服务已创建"
    else
        ok "开机自启服务已存在"
    fi
}

# =============================================
# 显示安装总结
# =============================================
show_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}  ✅ 安装完成！${NC}"
    echo "============================================"
    echo ""
    echo "已安装的开发工具："
    echo "  📦 编译构建:  gcc, g++, make, cmake, autoconf, libtool, pkg-config"
    echo "  🗂️ 版本控制:   git"
    echo "  🐍 Python:     python3, pip, venv + libssl/libffi/readline 等开发库"
    echo "  🔌 SSH/远程:   openssh-server, rsync, sshfs"
    echo "  🌐 网络工具:   curl, wget, net-tools, nmap, dnsutils, lsof, iperf3"
    echo "  📦 压缩归档:   zip, unzip, tar, p7zip, unrar, bzip2"
    echo "  📊 系统监控:   htop, iotop, nethogs, dstat, sysstat"
    echo "  ✏️ 编辑器:     vim, nano"
    echo "  💻 终端增强:   tmux, screen, bash-completion"
    echo "  🔍 文本工具:   tree"
    echo "  🖥️ VMware:     open-vm-tools, open-vm-tools-desktop"
    echo ""

    # 检查关键工具版本
    echo "工具版本："
    echo "  gcc:       $(gcc --version 2>/dev/null | head -1 || echo '未安装')"
    echo "  git:       $(git --version 2>/dev/null || echo '未安装')"
    echo "  cmake:     $(cmake --version 2>/dev/null | head -1 || echo '未安装')"
    echo "  python3:   $(python3 --version 2>/dev/null || echo '未安装')"
    echo "  ssh:       $(ssh -V 2>&1 | head -1 || echo '未安装')"
    echo "  tmux:      $(tmux -V 2>/dev/null || echo '未安装')"
    echo ""

    # 重启提示
    if [ -n "$NEED_REBOOT" ]; then
        echo -e "${YELLOW}⚠ 建议重启系统以完成 VMware 驱动加载${NC}"
        echo "  重启命令: sudo reboot"
        echo ""
    fi

    echo "共享目录位置：/mnt/hgfs/（需在 VMware 中配置共享文件夹后生效）"
    echo ""
    echo "SSH 状态：$(sudo systemctl is-active ssh 2>/dev/null || echo '检查中')"
    echo "============================================"
}

# =============================================
# 主流程
# =============================================
main() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  🚀 Ubuntu 26.04 开发环境一键安装脚本${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""

    # 检查 root 权限
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}⚠ 部分操作需要 sudo 权限，请输入密码${NC}"
        sudo true
    fi

    # 1. 环境检测
    echo -e "${BLUE}━━━ 步骤 1/4：系统环境检测 ━━━${NC}"
    detect_env
    echo ""

    # 2. 检测已安装/未安装的包
    echo -e "${BLUE}━━━ 步骤 2/4：检测软件包 ━━━${NC}"
    check_packages
    echo ""

    # 3. 安装缺失包
    echo -e "${BLUE}━━━ 步骤 3/4：安装缺失软件包 ━━━${NC}"
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        install_with_progress "${MISSING_PACKAGES[@]}"
        NEED_REBOOT=1
    else
        info "所有包已安装，跳过安装步骤"
    fi
    echo ""

    # 4. VMware 共享目录配置
    echo -e "${BLUE}━━━ 步骤 4/4：VMware 共享目录配置 ━━━${NC}"
    setup_vmware_shared
    echo ""

    # 5. 显示总结
    show_summary
}

main "$@"

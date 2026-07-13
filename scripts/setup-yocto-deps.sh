#!/bin/bash
# =============================================
# 🏗️ Yocto 构建依赖安装脚本
# 适用：Ubuntu 20.04 / 22.04 / 24.04 / 26.04
# 需先安装基础开发环境（gcc/git等）
# =============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

# =============================================
# 进度条
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

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        info "系统: $NAME $VERSION_ID"
    fi
    info "架构: $(uname -m)"

    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    info "内存: ${total_mem}MB"

    disk_free=$(df -h / | awk 'NR==2{print $4}')
    info "磁盘剩余: ${disk_free}"

    cpu_cores=$(nproc)
    info "CPU 核心: ${cpu_cores}"

    # 检测基础环境
    echo ""
    echo "--------------------------------------------"
    echo "  基础工具检测（需先安装 build-essential）"
    echo "--------------------------------------------"
    for cmd in gcc make git python3; do
        if command -v "$cmd" &>/dev/null; then
            ok "$cmd: $(command -v $cmd)"
        else
            warn "$cmd: 未安装"
        fi
    done
}

# =============================================
# 检测 Yocto 依赖包
# =============================================
check_packages() {
    echo ""
    echo "============================================"
    echo "  检测 Yocto 构建依赖"
    echo "============================================"

    local packages=(
        # 基础工具
        "gawk:GNU awk 文本处理"
        "diffstat:文件差异统计"
        "unzip:unzip 解压"
        "texinfo:Texinfo 文档系统"
        "chrpath:二进制 rpath 修改"
        "socat:多路网络工具"
        "cpio:cpio 归档工具"
        "zstd:Zstd 压缩"
        "liblz4-tool:LZ4 压缩工具"
        "lz4:lz4c 命令支持"

        # Python 扩展
        "python3-pexpect:Python expect"
        "python3-git:Python Git 库"
        "python3-jinja2:Python Jinja2 模板"
        "python3-subunit:Python 测试协议"

        # 网络工具
        "debianutils:Debian 工具集"
        "iputils-ping:ping 工具"

        # QEMU 图形支持
        "libegl1-mesa:Mesa EGL 库"
        "libsdl1.2-dev:SDL 1.2 开发库"
        "xterm:xterm 终端"
        "mesa-common-dev:Mesa 通用开发"
    )

    local missing=()
    local installed=()

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

    MISSING_PACKAGES=("${missing[@]}")
}

# =============================================
# 安装（带进度条）
# =============================================
install_with_progress() {
    local packages=("$@")
    local total=${#packages[@]}
    local current=0

    if [ "$total" -eq 0 ]; then
        info "所有 Yocto 依赖已安装，无需操作"
        return 0
    fi

    local total_steps=$((total + 3))

    echo "============================================"
    echo "  开始安装 ${total} 个 Yocto 依赖包"
    echo "============================================"
    echo ""

    current=$((current + 1))
    show_progress $current $total_steps "更新软件源..."
    sudo apt-get update -qq 2>/dev/null
    echo ""

    current=$((current + 1))
    show_progress $current $total_steps "升级现有包..."
    sudo apt-get upgrade -y -qq 2>/dev/null
    echo ""

    current=$((current + 1))
    show_progress $current $total_steps "安装 ${total} 个包..."
    echo ""

    local batch=()
    local batch_count=0
    for pkg in "${packages[@]}"; do
        batch+=("$pkg")
        batch_count=$((batch_count + 1))

        if [ ${#batch[@]} -ge 20 ] || [ "$batch_count" -eq "$total" ]; then
            if ! sudo apt-get install -y -qq "${batch[@]}" 2>/dev/null; then
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
# Yocto 环境检查
# =============================================
check_yocto_ready() {
    echo ""
    echo "============================================"
    echo "  ✅ Yocto 构建环境就绪检查"
    echo "============================================"
    echo ""
    echo "以下工具必须可用："
    local errors=0

    local essentials=(
        "gawk:gawk"
        "git:git"
        "python3:python3"
        "chrpath:chrpath"
        "socat:socat"
        "zstd:zstd"
    )

    for item in "${essentials[@]}"; do
        cmd="${item%%:*}"
        name="${item#*:}"
        if command -v "$cmd" &>/dev/null; then
            ok "  $name: $(which $cmd)"
        else
            err "  $name: 未找到！"
            errors=$((errors + 1))
        fi
    done

    echo ""
    if [ "$errors" -eq 0 ]; then
        echo -e "${GREEN}  ┌────────────────────────────────────────┐${NC}"
        echo -e "${GREEN}  │  所有依赖就绪，可以开始构建 Yocto！     │${NC}"
        echo -e "${GREEN}  └────────────────────────────────────────┘${NC}"
        echo ""
        echo "  建议磁盘剩余空间: ≥ 100GB"
        echo "  当前剩余空间:     $(df -h / | awk 'NR==2{print $4}')"
        echo ""
    else
        echo -e "${RED}  ┌────────────────────────────────────────┐${NC}"
        echo -e "${RED}  │  还有 $errors 个依赖未就绪，请检查        │${NC}"
        echo -e "${RED}  └────────────────────────────────────────┘${NC}"
        echo ""
    fi
}

# =============================================
# 主流程
# =============================================
main() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  🏗️  Yocto 构建依赖安装脚本${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""

    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}⚠ 部分操作需要 sudo 权限，请输入密码${NC}"
        sudo true
    fi

    echo -e "${BLUE}━━━ 步骤 1/3：系统环境检测 ━━━${NC}"
    detect_env
    echo ""

    echo -e "${BLUE}━━━ 步骤 2/3：检测 Yocto 依赖 ━━━${NC}"
    check_packages
    echo ""

    echo -e "${BLUE}━━━ 步骤 3/3：安装并验证 ━━━${NC}"
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        install_with_progress "${MISSING_PACKAGES[@]}"
    else
        info "所有 Yocto 依赖已安装，跳过安装"
    fi

    check_yocto_ready
}

main "$@"

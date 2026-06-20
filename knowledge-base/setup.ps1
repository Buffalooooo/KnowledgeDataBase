<#
.SYNOPSIS
    Obsidian 个人知识库一键部署脚本
.DESCRIPTION
    初始化知识库目录结构、Git 仓库、笔记模板，可选安装 Ollama 本地 AI 或配置 DeepSeek 云 API。
#>

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Obsidian 个人知识库 - 一键部署脚本   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ==================== 1. 创建目录结构 ====================
Write-Host "[1/5] 创建目录结构..." -ForegroundColor Yellow
$dirs = @(
    "技术",
    "Templates"
)
foreach ($d in $dirs) {
    $path = Join-Path $ROOT $d
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "  ✓ 创建: $d" -ForegroundColor Green
    } else {
        Write-Host "  · 已存在: $d" -ForegroundColor Gray
    }
}

# 创建 .gitignore
Write-Host "[2/5] 配置 Git..." -ForegroundColor Yellow
if (-not (Test-Path (Join-Path $ROOT ".git"))) {
    Set-Location $ROOT
    git init | Out-Null
    Write-Host "  ✓ Git 仓库初始化" -ForegroundColor Green
} else {
    Write-Host "  · Git 仓库已存在" -ForegroundColor Gray
}

$gitignore = Join-Path $ROOT ".gitignore"
if (-not (Test-Path $gitignore)) {
@"
# Obsidian 本地缓存配置（不同设备不同，不同步）
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache/
.obsidian/plugins/*/data.json

# 系统文件
Thumbs.db
.DS_Store
"@ | Set-Content -Path $gitignore -Encoding UTF8
    Write-Host "  ✓ .gitignore 已创建" -ForegroundColor Green
} else {
    Write-Host "  · .gitignore 已存在" -ForegroundColor Gray
}

# ==================== 3. 创建笔记模板 ====================
Write-Host "[3/5] 创建笔记模板..." -ForegroundColor Yellow
$templateDir = Join-Path $ROOT "Templates"

$templates = @{
    "技术笔记.md" = @'
---
tags: [技术/{{title}}]
created: {{date}}
---

# {{title}}

## 概述

## 要点

## 代码示例

## 参考
'@
}

foreach ($name in $templates.Keys) {
    $path = Join-Path $templateDir $name
    if (-not (Test-Path $path)) {
        $templates[$name] | Set-Content -Path $path -Encoding UTF8
        Write-Host "  ✓ 创建: Templates/$name" -ForegroundColor Green
    } else {
        Write-Host "  · 已存在: Templates/$name" -ForegroundColor Gray
    }
}

# ==================== 4. AI 配置 ====================
Write-Host "[4/5] AI 助手配置..." -ForegroundColor Yellow
Write-Host ""
Write-Host "选择 AI 模式：" -ForegroundColor Cyan
Write-Host "  [1] DeepSeek 云 API（需 API Key，无需 GPU）"
Write-Host "  [2] 本地 Ollama + DeepSeek（免费离线，CPU 可跑）"
Write-Host "  [3] 跳过，稍后手动配置"
Write-Host ""

$choice = Read-Host "请输入选项 (1/2/3)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "你选择了 DeepSeek 云 API。" -ForegroundColor Green
        Write-Host "部署后请在 Smart Connections 插件中进行以下配置：" -ForegroundColor Yellow
        Write-Host "  1. 前往 https://platform.deepseek.com/ 注册并获取 API Key" -ForegroundColor White
        Write-Host "  2. Obsidian → 设置 → Smart Connections → Provider 选择 OpenAI" -ForegroundColor White
        Write-Host "  3. API Base URL 填入: https://api.deepseek.com" -ForegroundColor White
        Write-Host "  4. 填入你的 DeepSeek API Key" -ForegroundColor White
        Write-Host "  5. Model 填入: deepseek-chat" -ForegroundColor White
        Write-Host "  6. 点击 Index 建立知识库索引" -ForegroundColor White
    }
    "2" {
        Write-Host ""
        Write-Host "你选择了本地 Ollama 模式。" -ForegroundColor Green
        
        # 检查是否已安装 Ollama
        $ollamaInstalled = Get-Command "ollama" -ErrorAction SilentlyContinue
        if (-not $ollamaInstalled) {
            Write-Host "  检测到 Ollama 未安装。" -ForegroundColor Yellow
            $install = Read-Host "  是否自动下载安装 Ollama？(y/n)"
            if ($install -eq "y") {
                Write-Host "  正在下载 Ollama 安装包..." -ForegroundColor Yellow
                $installer = "$env:TEMP\OllamaSetup.exe"
                try {
                    Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer -UseBasicParsing
                    Write-Host "  正在安装 Ollama（请按向导完成）..." -ForegroundColor Yellow
                    Start-Process -Wait -FilePath $installer
                    Write-Host "  ✓ Ollama 安装完成" -ForegroundColor Green
                } catch {
                    Write-Host "  ✗ 下载失败，请手动安装: https://ollama.com/" -ForegroundColor Red
                }
            } else {
                Write-Host "  请手动安装 Ollama: https://ollama.com/" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✓ Ollama 已安装" -ForegroundColor Green
        }

        # 拉取模型
        if (Get-Command "ollama" -ErrorAction SilentlyContinue) {
            Write-Host "  正在拉取 DeepSeek-R1:7b 模型（约 4GB，首次下载较慢）..." -ForegroundColor Yellow
            Write-Host "  如果网络较慢，可随时 Ctrl+C 跳过，后续手动执行: ollama pull deepseek-r1:7b" -ForegroundColor Gray
            try {
                ollama pull deepseek-r1:7b 2>&1 | Out-Null
                Write-Host "  ✓ DeepSeek-R1:7b 拉取完成" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ 拉取失败，稍后可手动运行: ollama pull deepseek-r1:7b" -ForegroundColor Red
            }

            Write-Host "  正在拉取 nomic-embed-text 模型（用于语义搜索）..." -ForegroundColor Yellow
            try {
                ollama pull nomic-embed-text 2>&1 | Out-Null
                Write-Host "  ✓ nomic-embed-text 拉取完成" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ 拉取失败，稍后可手动运行: ollama pull nomic-embed-text" -ForegroundColor Red
            }

            Write-Host ""
            Write-Host "配置 Smart Connections 插件：" -ForegroundColor Yellow
            Write-Host "  1. Obsidian → 设置 → Smart Connections → Provider 选择 Ollama" -ForegroundColor White
            Write-Host "  2. API Base URL 填入: http://localhost:11434" -ForegroundColor White
            Write-Host "  3. Chat Model 选择: deepseek-r1:7b" -ForegroundColor White
            Write-Host "  4. Embedding Model 选择: nomic-embed-text" -ForegroundColor White
            Write-Host "  5. 点击 Index 建立知识库索引" -ForegroundColor White
        }
    }
    "3" {
        Write-Host "已跳过 AI 配置，稍后可在 Smart Connections 插件中手动设置。" -ForegroundColor Gray
    }
    default {
        Write-Host "无效选项，跳过 AI 配置。" -ForegroundColor Red
    }
}

# ==================== 5. 完成 ====================
Write-Host ""
Write-Host "[5/5] 完成!" -ForegroundColor Yellow
Write-Host ""

# Git commit
Set-Location $ROOT
$status = git status --porcelain
if ($status) {
    git add -A
    git commit -m "init: 知识库初始部署" | Out-Null
    Write-Host "  ✓ 初始提交已创建" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   部署完成！接下来请做两件事：         " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. 用 Obsidian 打开此文件夹：" -ForegroundColor White
Write-Host "       Obsidian → 打开本地文件夹 → 选择: $ROOT" -ForegroundColor White
Write-Host ""
Write-Host "  2. 安装社区插件（设置 → 社区插件 → 浏览）：" -ForegroundColor White
Write-Host "       - Smart Connections（AI 问答 + 语义搜索）" -ForegroundColor White
Write-Host "       - Templater（使用已创建的笔记模板）" -ForegroundColor White
Write-Host ""
Write-Host "  3. VS Code 共享：" -ForegroundColor White
Write-Host "       在 VS Code 中打开 $ROOT" -ForegroundColor White
Write-Host "       两边编辑同一份文件，Obsidian 会自动刷新" -ForegroundColor White
Write-Host ""
Write-Host "祝你知识管理愉快！" -ForegroundColor Cyan

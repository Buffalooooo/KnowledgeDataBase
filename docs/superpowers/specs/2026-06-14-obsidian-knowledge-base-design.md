# Obsidian 个人知识库设计方案

## 概述

在现有工作区中构建基于 Obsidian 的个人知识库，支持多类型内容（技术笔记、创作幻想、日记、读书笔记等），并接入 AI 模型实现智能检索与问答。

## 存储方式

- 纯本地 Markdown 文件
- 库路径：`d:\004_workspace\data\knowledge-base`
- 可用 Git 做版本管理

## 目录结构

```
knowledge-base/
├── 技术/                 # 技术笔记
├── Templates/            # 笔记模板
```

分类方式：文件作为粗分类 + 笔记内标签做细粒度标记。

## 核心插件

| 插件 | 用途 |
|------|------|
| Smart Connections | 语义关联 + AI 问答，接入本地 Ollama 或 OpenAI |
| Copilot (Obsidian) | 基于知识库的 AI 对话助手 |
| Dataview | 类 SQL 查询笔记，自动生成目录 |
| Templater | 预设各类笔记模板 |

## AI 接入方案

支持云端和本地两种模式，通过一键脚本快速切换。

### 方式 A：DeepSeek 云 API（需网络，无需 GPU）
- 安装 Smart Connections 插件
- Provider 设为 OpenAI（兼容格式）
- API Base URL: `https://api.deepseek.com`
- 填入 DeepSeek API Key
- 模型：`deepseek-chat`

### 方式 B：本地 DeepSeek + Ollama（免费、离线、数据不出本机）
- 安装 [Ollama](https://ollama.ai/)
- 拉取模型：`ollama pull deepseek-r1:7b` + `ollama pull nomic-embed-text`
- Smart Connections 配置选择 Ollama 提供商
- CPU 可运行，无需 GPU

### 切换方式
一键脚本 `setup.ps1` 支持交互式配置，引导用户选择云端或本地模式，自动完成安装和配置。

## 推荐启用设置

- 文件 > 自动更新内部链接 ✓
- 文件 > 检测所有类型文件 ✓
- 核心插件 > 日记（配置日记模板和路径）
- 核心插件 > 图探索（可视化知识关联）

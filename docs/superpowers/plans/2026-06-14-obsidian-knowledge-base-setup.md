# Obsidian 个人知识库搭建计划

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `d:\004_workspace\data` 下搭建 Obsidian 知识库，VS Code 和 Obsidian 共用同一份 Markdown 文件。

**Architecture:** 纯本地 Markdown 文件系统，Obsidian 负责知识管理界面，VS Code 负责代码编辑，双方通过同一文件夹共享内容。

**Tech Stack:** Obsidian, Markdown, Git

---

### Task 1: 创建知识库目录结构

**Files:**
- Create: `d:\004_workspace\data\knowledge-base/.obsidian`（安装 Obsidian 后自动生成，也可手动）
- Create: 各分类文件夹

- [ ] **Step 1: 创建顶层目录结构**

在 `d:\004_workspace\data` 下创建：

```
knowledge-base/
├── 技术/
└── Templates/
```

- [ ] **Step 2: 初始化 Git 仓库**

```bash
cd d:\004_workspace\data\knowledge-base
git init
git add -A
git commit -m "init: 初始化知识库目录结构"
```

### Task 2: 安装 Obsidian 并打开库

- [ ] **Step 1: 下载安装 Obsidian**
  - 访问 https://obsidian.md/ 下载安装包

- [ ] **Step 2: 打开库**
  - 打开 Obsidian → "打开本地文件夹" → 选择 `d:\004_workspace\data\knowledge-base`

### Task 3: 配置核心插件

- [ ] **Step 1: 启用核心插件**
  - 设置 → 核心插件 → 开启：日记、图探索、文件恢复、大纲

### Task 4: 安装社区插件

- [ ] **Step 1: 安装 Smart Connections**
  - 设置 → 社区插件 → 浏览 → 搜索 Smart Connections → 安装并启用

- [ ] **Step 2: 安装 Dataview**
  - 社区插件 → 搜索 Dataview → 安装并启用

- [ ] **Step 3: 安装 Templater**
  - 社区插件 → 搜索 Templater → 安装并启用

### Task 5: 创建笔记模板（Templater）

**Files:**
- Create: `knowledge-base/Templates/技术笔记.md`
- Create: `knowledge-base/Templates/创作笔记.md`
- Create: `knowledge-base/Templates/日记模板.md`
- Create: `knowledge-base/Templates/读书笔记.md`

- [ ] **Step 1: 创建技术笔记模板**

```markdown
---
tags: [技术/{{title}}]
created: {{date}}
---

# {{title}}

## 概述

## 要点

## 代码示例

## 参考
```

- [ ] **Step 2: 创建创作笔记模板**

```markdown
---
tags: [创作/{{title}}]
created: {{date}}
status: 草稿
---

# {{title}}

## 设定

## 关联角色

## 背景故事

## 备注
```

- [ ] **Step 3: 创建日记模板**

```markdown
---
tags: [日记]
created: {{date}}
---

# {{date}}

## 今天做了什么

## 想法/灵感

## 明日计划
```

- [ ] **Step 4: 创建读书笔记模板**

```markdown
---
tags: [读书笔记]
created: {{date}}
book: 
author: 
status: 在读
---

# {{title}}

## 核心观点

## 摘录

## 感悟
```

### Task 6: 配置 AI 接入

- [ ] **Step 1: 配置 Smart Connections**
  - 打开 Smart Connections 设置
  - 选择 AI 提供商（OpenAI 或 Ollama）
  - 填入 API Key 或配置本地 Ollama 地址
  - 运行首次索引

### Task 7: 创建一键部署脚本

**Files:**
- Create: `d:\004_workspace\data\knowledge-base\setup.ps1`

- [ ] **Step 1: 创建 `setup.ps1`**
  - 脚本功能：创建目录、初始化 Git、安装 Ollama（可选）、拉取模型（可选）、配置模板
  - 交互式引导用户选择云端 DeepSeek 或本地 Ollama 模式
  - 包含 .gitignore 排除 Obsidian 缓存

### Task 8: 验证可用性

- [ ] **Step 1: 创建第一条笔记**
  - 用模板创建一篇技术笔记或创作笔记

- [ ] **Step 2: 验证 AI 问答**
  - 在 Smart Connections 面板中测试提问

- [ ] **Step 3: 验证 VS Code 共享**
  - 在 VS Code 中打开 `knowledge-base` 文件夹
  - 确认 Obsidian 和 VS Code 看到的是同一份文件

# Hermes Browser Test Harness

**目标**：打造 Hermes Agent 的通用浏览器自动化测试框架，基于 Midscene vision-driven 技术，实现对任意网页的探索、测试用例生成、执行验证和自学习。

## 核心特性

- **探索模式**：AI 自主探索网页，发现功能入口和元素
- **用例生成**：自动从探索结果生成测试用例 markdown
- **执行引擎**：顺序执行测试用例，vision 验证结果
- **自学习**：失败自动记录，UI 变更对比，模式提炼
- **增量更新**：网站更新后重新探索，diff 对比，自动更新用例

## 目录结构

```
hermes-browser-test/
├── PROJECT.md           # 本文件
├── README.md            # 使用说明
├── src/                 # 核心脚本
│   ├── explore.sh       # 探索模式：探索网页，生成用例
│   ├── execute.sh       # 执行模式：运行测试用例
│   ├── learn.sh         # 学习模式：记录和更新
│   └── common.sh        # 公共函数
├── config/              # 配置文件
│   ├── midscene.env     # Midscene 环境变量
│   └── sites.yaml       # 网站配置（URL、账号、登录方式）
├── skills/              # Hermes Skill
│   └── web-auto-test/   # 通用网页自动化测试 skill
├── testcases/          # 测试用例库
│   └── README.md        # 用例编写规范
├── learnings/           # 学习记录
│   ├── errors.md
│   ├── learnings.md
│   └── feature_requests.md
└── reports/             # 测试报告输出
```

## 工作流

```
┌─────────────────────────────────────────┐
│  Phase 1: 探索 (explore.sh)              │
│  connect → act探索 → 生成用例 → 保存      │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  Phase 2: 执行 (execute.sh)              │
│  读取用例 → 执行每步 → vision验证 → 记录  │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  Phase 3: 学习 (learn.sh)               │
│  分析结果 → 写入learnings → 更新用例     │
└─────────────────────────────────────────┘
```

## 快速开始

### 1. 配置网站

编辑 `config/sites.yaml`，添加网站配置：

```yaml
sites:
  - name: 我的网站
    url: https://example.com
    login:
      type: ldap          # ldap | oauth | form | none
      username: user
      password: pass
      selectors:
        username: "#username"
        password: "#password"
        submit: "button[type=submit]"
    test_paths:
      - /dashboard
      - /settings
```

### 2. 探索网站

```bash
./src/explore.sh example.com
```

AI 会：
- 连接网站
- 探索所有可交互元素
- 生成测试用例到 `testcases/example.com/`

### 3. 执行测试

```bash
./src/execute.sh example.com
```

### 4. 查看报告

```bash
cat reports/$(date +%Y%m%d)_example.com.html
```

## 三层架构

### Layer 1: 探索层 (Explore)
AI 自主导航网页，发现按钮、表单、链接等元素，建立页面地图。

### Layer 2: 执行层 (Execute)
按用例顺序执行操作，vision 验证每步结果是否满足验收标准。

### Layer 3: 学习层 (Learn)
- **错误记录**：失败写入 `learnings/errors.md`
- **模式提炼**：重复失败触发规则升级
- **用例更新**：UI 变更自动 diff 并更新用例

## 学习提升规则

| 信号 | 目标 | 触发条件 |
|------|------|---------|
| 操作失败 | 更新执行策略 | 任意 act 失败 |
| UI 变更 | 更新测试用例 | 截图 diff 差异 > 30% |
| 重复失败 | 升级到系统提示 | 同一用例失败 3 次 |
| 新发现 | 写入模式库 | 探索阶段发现 |

## Hermes Skill

```bash
# 触发探索
skill_view web-auto-test
./src/explore.sh <site>

# 触发测试执行
./src/execute.sh <site>

# 触发自学习
./src/learn.sh analyze
```

## 环境要求

- Node.js + npx
- Midscene: `npx @midscene/web@1`
- 支持的模型: Doubao Seed, Qwen3-VL, GPT-4V 等 vision 模型
- 配置: `~/.env` 或 `config/midscene.env`

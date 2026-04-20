# Hermes Browser Test Harness

基于 Midscene vision-driven 技术的通用浏览器自动化测试框架，专为 Hermes Agent 设计。

## 特性

- **探索模式**：AI 自主探索网页，发现功能入口和元素
- **用例生成**：自动从探索结果生成测试用例 markdown
- **执行引擎**：顺序执行测试用例，vision 验证结果
- **自学习**：失败自动记录，UI 变更对比，模式提炼
- **增量更新**：网站更新后重新探索，diff 对比，自动更新用例

## 项目结构

```
hermes-browser-test/
├── PROJECT.md           # 项目设计文档
├── README.md            # 本文件
├── src/                 # 核心脚本
│   ├── explore.sh       # 探索模式
│   ├── execute.sh       # 执行模式
│   ├── learn.sh        # 学习模式
│   └── common.sh        # 公共函数
├── config/              # 配置文件
│   ├── midscene.env    # Midscene 环境变量（需自行配置）
│   └── sites.yaml       # 网站配置
├── skills/              # Hermes Skill
│   └── web-auto-test/  # 通用网页自动化测试 skill
├── testcases/           # 测试用例库
├── learnings/            # 学习记录
└── reports/             # 测试报告
```

## 快速开始

### 1. 克隆项目

```bash
git clone <repo-url>
cd hermes-browser-test
```

### 2. 配置 Midscene

```bash
# 复制环境配置模板
cp config/midscene.env.example config/midscene.env

# 编辑配置，填入你的 API Key
vim config/midscene.env
```

`config/midscene.env` 内容：

```bash
MIDSCENE_MODEL_API_KEY=your-api-key-here
MIDSCENE_MODEL_NAME=seed-2-0-lite-260228
MIDSCENE_MODEL_BASE_URL=https://deepseek.akusre.com/v1
MIDSCENE_MODEL_FAMILY=doubao-vision
```

### 3. 配置网站

编辑 `config/sites.yaml`：

```yaml
sites:
  - name: mysite
    url: https://example.com
    login:
      type: ldap          # ldap | oauth | form | none
      username: your-username
      password: your-password
    test_paths:
      - /dashboard
      - /settings
```

### 4. 探索网站

```bash
./src/explore.sh mysite
```

### 5. 执行测试

```bash
./src/execute.sh mysite
```

### 6. 查看学习记录

```bash
./src/learn.sh summary
./src/learn.sh analyze
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

## 三层架构

### Layer 1: 探索层 (Explore)

AI 自主导航网页，发现按钮、表单、链接等元素，建立页面地图，自动生成测试用例。

### Layer 2: 执行层 (Execute)

按用例顺序执行操作，vision 验证每步结果是否满足验收标准。

### Layer 3: 学习层 (Learn)

- **错误记录**：失败写入 `learnings/errors.md`
- **模式提炼**：重复失败触发规则升级到 SOUL.md/AGENTS.md
- **用例更新**：UI 变更自动 diff 并更新用例

## Midscene 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `MIDSCENE_MODEL_API_KEY` | 模型 API Key | `sk-...` |
| `MIDSCENE_MODEL_NAME` | 模型名称 | `seed-2-0-lite-260228` |
| `MIDSCENE_MODEL_BASE_URL` | API 地址 | `https://deepseek.akusre.com/v1` |
| `MIDSCENE_MODEL_FAMILY` | 模型系列 | `doubao-vision` |

支持的模型：Doubao Seed, Qwen3-VL, GPT-4V 等支持 vision 的模型。

## 学习提升规则

| 信号 | 目标 | 触发条件 |
|------|------|---------|
| 操作失败 | 更新执行策略 | 任意 act 失败 |
| UI 变更 | 更新测试用例 | 截图 diff 差异 > 30% |
| 重复失败 | 升级到系统提示 | 同一用例失败 3 次 |
| 新发现 | 写入模式库 | 探索阶段发现 |

## learnings.db 表结构

```sql
CREATE TABLE learnings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT,
  task TEXT,
  outcome TEXT,           -- 'success' | 'partial' | 'failed'
  learning TEXT,          -- 核心经验
  page_pattern TEXT,      -- 域名
  error_mode TEXT,        -- 'timeout' | 'element-not-found' | 'api-error'
  model_used TEXT,
  screenshot_path TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Hermes Agent 集成

在 Hermes Agent 中使用：

```bash
# 触发探索
skill_view web-auto-test
./src/explore.sh <site>

# 触发测试执行
./src/execute.sh <site>

# 触发自学习
./src/learn.sh analyze
```

## License

MIT

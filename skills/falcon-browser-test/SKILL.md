---
name: falcon-browser-test
description: |
  Falcon会议管理系统(falcon.akusre.com)的自动化浏览器测试agent。
  基于Midscene vision-driven技术，自主探索页面、生成测试用例、执行验证、学习更新。
  
  核心能力：
  1. 探索模式：AI自主探索网站，发现功能入口，生成测试用例
  2. 执行模式：读取用例库，顺序执行，vision验证结果
  3. 学习模式：失败自动记录，UI变更对比，重复失败3次触发升级
  4. 增量更新：网站更新后重新探索，diff对比，自动更新用例
  5. 风险管控：高风险操作（删除、邀请真人）自动识别并拒绝
  
  安全特性：
  - CRITICAL操作（删除、邀请真人参会）自动拒绝
  - WRITE操作（创建、发消息）执行前clarify确认
  - README.md说明风险，禁止拉真实人员参会
  
triggers:
  - "测试falcon"
  - "falcon浏览器测试"
  - "falcon会议系统自动化"
  - "自动化回归测试falcon"
  - "执行falcon测试"

skills:
  - browser-automation
  - self-improving-agent

allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - ExecuteCode
  - delegate_task
  - clarify
---

# Falcon 会议管理系统 - 浏览器自动化测试 Skill

## ⚠️ 安全警告

**本 skill 仅用于测试环境，禁止对真实人员执行任何操作！**

| 禁止行为 | 原因 |
|---------|------|
| 邀请真实人员加入会议 | 会发送真实通知 |
| 删除真实会议 | 数据不可逆 |
| 向真人发送消息 | 骚扰/泄露风险 |

---

## 目标信息

| 项目 | 值 |
|------|-----|
| 网站 | https://falcon.akusre.com/ |
| 账号 | tangyc10 |
| 密码 | Tyc816799 |
| 登录方式 | LDAP（需先切换标签页到"LDAP"再输入账号密码）|
| 系统类型 | 会议管理系统（腾讯会议导入/发起）|

---

## 环境配置

每次使用前必须加载环境变量：
```bash
source ~/.env
```

`~/.env` 内容（已持久化）：
```bash
MIDSCENE_MODEL_API_KEY=sk-EUyOZAiNmUdggpq937jCdmsB8ZIrkY1fYaCoEsrVfCrX0Cq1
MIDSCENE_MODEL_NAME=seed-2-0-lite-260228
MIDSCENE_MODEL_BASE_URL=https://deepseek.akusre.com/v1
MIDSCENE_MODEL_FAMILY=doubao-vision
```

---

## 核心命令

```bash
# 连接网站
source ~/.env && npx @midscene/web@1 connect --url https://falcon.akusre.com/

# 登录（先切换LDAP标签）
source ~/.env && npx @midscene/web@1 act --prompt "点击LDAP标签切换到账号密码登录，输入账号tangyc10和密码Tyc816799，点击登录"

# 执行动作（每次一个完整任务）
source ~/.env && npx @midscene/web@1 act --prompt "<具体操作描述>"

# 截图
source ~/.env && npx @midscene/web@1 take_screenshot

# 关闭
source ~/.env && npx @midscene/web@1 close
```

---

## 风险管控系统

### 风险分级

| 等级 | 操作类型 | 示例 | 行为 |
|------|---------|------|------|
| 🟢 **READ** | 只读查询 | 查看、搜索、筛选、截图 | 可自主执行 |
| 🟡 **WRITE** | 有副作用 | 创建会议、导入 | 需确认 |
| 🔴 **CRITICAL** | 不可逆/高影响 | 删除、邀请真人参会 | 明确拒绝 |

### CRITICAL 操作（自动拒绝）

以下操作将**自动拒绝**，并返回安全替代方案：

1. **邀请真实人员参会**
   - 关键词：`邀请`、`invite`、`add` + 人名
   - 自动拒绝，返回：「建议使用虚拟人员名称（如 test_user_001）」

2. **删除会议**
   - 关键词：`删除`、`remove`、`delete`、`cancel`
   - 自动拒绝，返回：「CRITICAL 操作已拒绝，建议先在测试环境验证」

3. **发送通知给真人**
   - 关键词：`发送`、`send`、`notify` + 人名
   - 自动拒绝

### WRITE 操作（执行前确认）

```bash
# 创建会议、导入会议等
# 执行前使用 clarify 确认
```

### Falcon 已知风险

| 操作 | 风险等级 | 备注 |
|------|---------|------|
| 查看会议列表 | 🟢 READ | 安全 |
| 搜索/筛选 | 🟢 READ | 安全 |
| 发起腾讯会议（不加真人） | 🟡 WRITE | 建议不加真实人员 |
| 导入腾讯会议 | 🟡 WRITE | 依赖腾讯会议账号 |
| 发起本地会议 | 🟡 WRITE | 创建数据 |
| 查看会议详情 | 🟢 READ | 安全 |
| **删除会议** | 🔴 CRITICAL | 不可逆，强制拒绝 |
| **邀请真人参会** | 🔴 CRITICAL | 会发通知，强制拒绝 |

---

## 标准工作流

### Phase 1: 探索（一次性或新增页面时）

```
1. connect 登录网站
2. act: "探索页面上所有你能交互的元素，包括导航菜单、按钮、表单等"
3. take_screenshot
4. AI分析截图，输出页面功能清单
5. 基于功能清单，生成测试用例 markdown 文件
6. 保存到 ~/.hermes/browser-test/testcases/
```

### Phase 2: 执行（定期回归测试）

```
1. 读取 testcases/ 目录所有用例
2. 对每个用例：
   a. 检查风险等级
   b. READ → 直接执行
   c. WRITE → clarify确认
   d. CRITICAL → 拒绝
   e. connect 登录（如未登录）
   f. act: 执行用例中的步骤
   g. take_screenshot
   h. act: "验证上一步的结果是否符合预期：<验收标准>"
   i. 记录 pass/fail
3. 生成测试报告
```

### Phase 3: 学习（每次执行后）

```bash
# 失败用例写入 learnings.db
sqlite3 ~/.hermes/browser-test/learnings.db "INSERT INTO learnings ..."

# UI变更检测：对比截图
# 差异显著 → 更新对应测试用例
# 重复失败3次 → 更新 SOUL.md/CLAUDE.md
```

---

## 测试用例格式

保存在 `~/.hermes/browser-test/testcases/` 目录，markdown格式：

```markdown
# TC-001: [功能名称]

## 风险等级
🟡 WRITE

## 前置条件
已登录

## 测试步骤
1. 点击「发起腾讯会议」按钮
2. 在弹窗中填写会议主题
3. 点击确认创建

## 验收标准
- 页面显示会议创建成功提示
- 会议出现在「我主持的会议」列表中

## 安全备注
此用例为WRITE级别，创建的是测试会议，不邀请真实人员。
```

---

## 文件结构

```
~/.hermes/browser-test/
├── learnings.db          # SQLite学习记录
├── testcases/           # 测试用例markdown
│   └── falcon/
│       ├── TC-001_登录流程.md
│       └── TC-002_创建会议.md
├── screenshots/         # 截图存档
└── reports/             # 测试报告
```

---

## learnings.db 表结构

```sql
CREATE TABLE learnings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT,
  task TEXT,
  outcome TEXT,           -- 'success' | 'partial' | 'failed'
  learning TEXT,          -- 核心经验
  risk_level TEXT,        -- 'READ' | 'WRITE' | 'CRITICAL'
  page_pattern TEXT,      -- 'falcon.akusre.com'
  error_mode TEXT,        -- 'timeout' | 'element-not-found' | 'risk-denied'
  model_used TEXT,
  screenshot_path TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 发现模式记录

发现新pattern时写入：
```bash
# 写入 learnings.db
sqlite3 ~/.hermes/browser-test/learnings.db "INSERT INTO learnings ..."

# 同时更新 .learnings 目录
~/.openclaw/workspace/.learnings/LEARNINGS.md
```

---

## 已知问题 & 解决

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 登录页默认企业微信扫码 | 系统默认展示 | 需点击「LDAP」标签切换 |
| Midscene 401错误 | API key格式不正确 | 使用OpenAI格式key + deepseek.akusre.com/v1 |
| 截图超大 | Retina屏幕 | 使用seed-2-0-lite模型 |
| 邀请真人参会 | 高风险操作 | 🔴 自动拒绝 |

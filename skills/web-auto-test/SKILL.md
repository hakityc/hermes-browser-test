---
name: web-auto-test
description: |
  通用网页自动化测试 Harness，基于 Midscene vision-driven 技术。
  
  功能：
  1. 探索模式：对任意网站自主探索，生成测试用例
  2. 执行模式：顺序执行测试用例，vision 验证结果
  3. 学习模式：失败记录、模式提炼、增量更新
  4. 风险管控：识别高风险操作，强制确认
  
  适用场景：
  - 回归测试
  - 新功能验证
  - 网页巡检
  - 表单/登录测试
  
  安全特性：
  - 操作风险分级（Read/Write/Critical）
  - 高风险操作强制clarify确认
  - Dry-run模式支持
  - 操作日志与回滚支持
  
triggers:
  - 浏览器自动化测试
  - 网页自动化测试
  - web自动化
  - 回归测试
  - 页面巡检
  - 测试falcon
  - 执行回归测试

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

# Web Auto Test Harness

通用网页自动化测试框架，Hermes Agent 专用。

---

## 风险管控系统

### 风险分级

| 等级 | 操作类型 | 示例 | 行为 |
|------|---------|------|------|
| 🟢 **READ** | 只读查询 | 查看、搜索、筛选、截图 | 可自主执行 |
| 🟡 **WRITE** | 有副作用 | 创建会议、导入、发消息 | 需确认 |
| 🔴 **CRITICAL** | 不可逆/高影响 | 删除、移除人员、修改权限、发邮件 | 明确拒绝 |

### 风险关键词识别

**CRITICAL 关键词（触发强制拒绝）**：
```
删除、remove、delete、destroy、drop
取消、cancel、revoke
邀请（真人）、invite、add（加真人）
发送（给真人）、send、notify
清空、clear、purge、reset
修改权限、change permission、admin
撤销、undo（对已生效操作）
```

**WRITE 关键词（触发确认提示）**：
```
创建、create、new、add
编辑、edit、update、modify
提交、submit、confirm
导入、import、upload
导出、export、download
```

### 风险处理流程

```
1. 解析操作意图
2. 识别风险关键词
3. 分类风险等级
4. READ → 直接执行
   WRITE → 执行前clarify确认
   CRITICAL → 拒绝 + 说明原因 + 提供安全替代方案
```

### Dry-run 模式

设置环境变量 `DRY_RUN=true` 可模拟执行，不产生实际影响：
```bash
DRY_RUN=true ./src/execute.sh mysite
```

---

## 项目结构

```
hermes-browser-test/
├── PROJECT.md           # 项目设计文档
├── README.md            # 本文件
├── src/
│   ├── explore.sh        # 探索模式
│   ├── execute.sh        # 执行模式
│   ├── learn.sh         # 学习模式
│   └── common.sh        # 公共函数
├── config/
│   ├── midscene.env    # Midscene 环境（需自行配置）
│   └── sites.yaml       # 网站配置
├── skills/
│   └── web-auto-test/  # 本 skill
├── testcases/           # 测试用例库（本地，不上传）
├── learnings/           # 学习记录
└── reports/             # 测试报告
```

---

## 快速开始

### 1. 配置网站

编辑 `config/sites.yaml`：
```yaml
sites:
  - name: mysite
    url: https://example.com
    login:
      type: ldap
      username: your-username
      password: your-password
```

### 2. 探索网站

```bash
cd ~/hermes-browser-test
./src/explore.sh mysite
```

### 3. 执行测试

```bash
./src/execute.sh mysite
```

### 4. 查看学习

```bash
./src/learn.sh summary
./src/learn.sh analyze
```

---

## 工作流

### Phase 1: 探索 (explore.sh)

```
1. connect 登录网站
2. 截图/检查DOM（reconnaissance）
3. act: "探索所有可交互元素"
4. AI 分析 → 生成测试用例
5. 保存截图和报告
```

### Phase 2: 执行 (execute.sh)

```
1. 读取 testcases/ 用例
2. 对每个用例：
   - 检查风险等级
   - READ → 直接执行
   - WRITE → clarify确认
   - CRITICAL → 拒绝
   - act: 执行操作
   - vision: 验证结果
   - 记录 pass/fail
3. 生成 HTML 报告
```

### Phase 3: 学习 (learn.sh)

```
- 失败 → errors.md + learnings.db
- UI变更 → diff → 更新用例
- 重复失败 → 提升到 SOUL.md/AGENTS.md
```

---

## Midscene 命令

```bash
source ~/.env
npx @midscene/web@1 connect --url <url>
npx @midscene/web@1 act --prompt "<操作>"
npx @midscene/web@1 take_screenshot
npx @midscene/web@1 close
```

---

## 用例格式

```markdown
# TC-001: [功能名称]

## 风险等级
🟡 WRITE

## 前置条件
已登录

## 测试步骤
1. 点击按钮A
2. 输入内容B
3. 点击提交

## 验收标准
- 显示成功提示
- 数据已保存

## 安全备注
此用例为WRITE级别，执行前需确认。
```

---

## learnings.db 结构

```sql
CREATE TABLE learnings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT,
  task TEXT,
  outcome TEXT,           -- 'success' | 'partial' | 'failed'
  learning TEXT,          -- 核心经验
  risk_level TEXT,        -- 'READ' | 'WRITE' | 'CRITICAL'
  page_pattern TEXT,      -- 域名
  error_mode TEXT,        -- 'timeout' | 'element-not-found' | 'api-error' | 'risk-denied'
  model_used TEXT,
  screenshot_path TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## Falcon 网站风险清单

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
| 配置管理 | 🟡 WRITE | 可能影响系统 |

---

## 升级规则

| 信号 | 目标 | 条件 |
|------|------|------|
| 失败 | 更新执行策略 | 任意 act 失败 |
| UI变更 | 更新用例 | diff > 30% |
| 重复失败 | 升级到系统 | 同一用例失败 3 次 |
| 新发现 | 写入模式库 | 探索阶段 |
| 风险误判 | 更新风险库 | AI 错误分类时 |

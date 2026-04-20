---
name: web-auto-test
description: |
  通用网页自动化测试 Harness，基于 Midscene vision-driven 技术。
  
  功能：
  1. 探索模式：对任意网站自主探索，生成测试用例
  2. 执行模式：顺序执行测试用例，vision 验证结果
  3. 学习模式：失败记录、模式提炼、增量更新
  
  适用场景：
  - 回归测试
  - 新功能验证
  - 网页巡检
  - 表单/登录测试
  
triggers:
  - 浏览器自动化测试
  - 网页自动化测试
  - web自动化
  - 回归测试
  - 页面巡检

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
---

# Web Auto Test Harness

通用网页自动化测试框架，Hermes Agent 专用。

## 项目结构

```
hermes-browser-test/
├── src/
│   ├── explore.sh    # 探索模式
│   ├── execute.sh    # 执行模式
│   ├── learn.sh      # 学习模式
│   └── common.sh     # 公共函数
├── config/
│   ├── midscene.env  # Midscene 环境
│   └── sites.yaml    # 网站配置
├── testcases/        # 测试用例库
├── learnings/        # 学习记录
└── reports/         # 测试报告
```

## 快速开始

### 1. 配置网站（首次）

编辑 `config/sites.yaml`：

```yaml
sites:
  - name: falcon
    url: https://falcon.akusre.com
    login:
      type: ldap
      username: tangyc10
      password: Tyc816799
```

### 2. 探索网站

```bash
cd ~/hermes-browser-test
./src/explore.sh falcon
```

AI 会自主探索网站，生成测试用例到 `testcases/falcon/`

### 3. 执行测试

```bash
./src/execute.sh falcon
```

### 4. 查看学习

```bash
./src/learn.sh summary
./src/learn.sh analyze
```

## 工作流

### Phase 1: 探索 (explore.sh)

```
1. connect 登录网站
2. act: "探索所有可交互元素"
3. AI 分析 → 生成测试用例
4. 保存截图和报告
```

### Phase 2: 执行 (execute.sh)

```
1. 读取 testcases/ 用例
2. 对每个用例：
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

## Midscene 命令

```bash
source ~/.env
npx @midscene/web@1 connect --url <url>
npx @midscene/web@1 act --prompt "<操作>"
npx @midscene/web@1 take_screenshot
npx @midscene/web@1 close
```

## 用例格式

```markdown
# TC-001: [功能名称]

## 前置条件
已登录

## 测试步骤
1. 点击按钮A
2. 输入内容B
3. 点击提交

## 验收标准
- 显示成功提示
- 数据已保存
```

## learnings.db 结构

```sql
CREATE TABLE learnings (
  id, session_id, task, outcome,
  learning, page_pattern, error_mode,
  model_used, screenshot_path, created_at
);
```

## 已知网站配置

| 网站 | 登录类型 | 备注 |
|------|---------|------|
| falcon.akusre.com | LDAP | 需先切换到LDAP标签 |

## 升级规则

| 信号 | 目标 | 条件 |
|------|------|------|
| 失败 | 更新执行策略 | 任意 act 失败 |
| UI变更 | 更新用例 | diff > 30% |
| 重复失败 | 升级到系统 | 同一用例失败 3 次 |
| 新发现 | 写入模式库 | 探索阶段 |

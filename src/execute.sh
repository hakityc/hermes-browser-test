#!/bin/bash
# execute.sh - 执行模式：运行测试用例，验证结果
# 用法: ./execute.sh <site_name>
# 示例: ./execute.sh falcon

set -e
source "$(dirname "$0")/common.sh"

usage() {
    cat << EOF
用法: $(basename "$0") <site_name>

执行指定网站的测试用例，验证每个操作的结果。

示例:
  $(basename "$0") falcon

前提:
  - 需要先用 explore.sh 探索网站生成测试用例
  - 或在 testcases/<site_name>/ 目录放置 markdown 格式测试用例

EOF
    exit 1
}

[ $# -lt 1 ] && usage

SITE="$1"
SITE_DIR="$PROJECT_ROOT/testcases/$SITE"
SESSION_ID="exec-$(date +%Y%m%d-%H%M%S)"
RESULTS_FILE="$PROJECT_ROOT/reports/${SESSION_ID}.json"

info "🚀 开始执行测试: $SITE"
info "   用例目录: $SITE_DIR"

# 检查用例目录
if [ ! -d "$SITE_DIR" ]; then
    error "用例目录不存在: $SITE_DIR"
    info "请先运行 ./explore.sh $SITE 进行探索"
    exit 1
fi

# 加载环境
load_env

# 获取网站配置
SITE_CONFIG=$(get_site_config "$SITE" 2>/dev/null || echo "")
URL=$(echo "$SITE_CONFIG" | grep "url:" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")

if [ -z "$URL" ]; then
    error "无法获取网站 URL"
    exit 1
fi

# 统计
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# 连接网站
info "📡 连接网站..."
midscene_connect "$URL"

# 处理登录
if echo "$SITE_CONFIG" | grep -q "login:"; then
    info "🔐 执行登录..."
    LOGIN_TYPE=$(echo "$SITE_CONFIG" | grep "type:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    case "$LOGIN_TYPE" in
        ldap)
            midscene act --prompt "点击切换到LDAP账号密码登录模式"
            sleep 2
            USERNAME=$(echo "$SITE_CONFIG" | grep "username:" | head -1 | cut -d: -f2 | tr -d ' ')
            midscene act --prompt "输入账号 $USERNAME 和密码，然后点击登录按钮"
            sleep 3
            ;;
        form)
            USERNAME=$(echo "$SITE_CONFIG" | grep "username:" | head -1 | cut -d: -f2 | tr -d ' ')
            PASSWORD=$(echo "$SITE_CONFIG" | grep "password:" | head -1 | cut -d: -f2 | tr -d ' ')
            midscene act --prompt "在用户名输入框输入 $USERNAME，在密码输入框输入密码，然后点击提交按钮"
            sleep 3
            ;;
    esac
    info "✅ 登录完成"
fi

# 查找所有测试用例文件
TC_FILES=$(find "$SITE_DIR" -name "*.md" ! -name "*explore*" ! -name "*report*" | sort)

if [ -z "$TC_FILES" ]; then
    warn "未找到测试用例文件"
    info "请在 $SITE_DIR 目录添加测试用例"
    exit 0
fi

# 初始化结果
echo "[]" > "$RESULTS_FILE"

# 执行每个用例
for TC_FILE in $TC_FILES; do
    TC_NAME=$(basename "$TC_FILE" .md)
    TOTAL=$((TOTAL + 1))
    
    info ""
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "📋 执行用例: $TC_NAME"
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 读取用例内容
    TC_CONTENT=$(cat "$TC_FILE")
    
    # 提取用例信息
    STEPS=$(echo "$TC_CONTENT" | grep -E "^\d+\." | head -10 || echo "")
    CRITERIA=$(echo "$TC_CONTENT" | grep -A5 "验收标准" | head -10 || echo "")
    
    if [ -z "$STEPS" ]; then
        warn "  ⚠️ 跳过（无测试步骤）: $TC_NAME"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    info "  步骤: $(echo "$STEPS" | wc -l) 步"
    
    # 执行每一步
    STEP_NUM=1
    for STEP in $STEPS; do
        STEP_TEXT=$(echo "$TC_CONTENT" | grep -A1 "^${STEP}" | tail -1 | sed 's/^[[:space:]]*//')
        
        if [ -n "$STEP_TEXT" ]; then
            info "  📌 步骤 $STEP_NUM: $STEP_TEXT"
            midscene act --prompt "$STEP_TEXT"
            sleep 1
        fi
        STEP_NUM=$((STEP_NUM + 1))
    done
    
    # 截图记录
    midscene_screenshot
    SCREENSHOT=$(get_screenshot_path)
    
    # 验证结果
    info "  🔍 验证结果..."
    VERIFY_RESULT=$(midscene act --prompt "验证上一步操作的结果。验收标准：$CRITERIA。请描述你看到了什么，是否满足验收标准。")
    
    # 判断结果
    if echo "$VERIFY_RESULT" | grep -qi "成功\|满足\|通过\|✓\|✅\|pass\|ok"; then
        RESULT="PASS"
        PASSED=$((PASSED + 1))
        info "  ✅ 结果: PASS"
    elif echo "$VERIFY_RESULT" | grep -qi "失败\|错误\|不满足\|✗\|❌\|fail"; then
        RESULT="FAIL"
        FAILED=$((FAILED + 1))
        warn "  ❌ 结果: FAIL"
        
        # 记录失败
        log_learning "error" \
            "测试失败: $TC_NAME" \
            "用例 $TC_NAME 执行失败。\n验证结果: $VERIFY_RESULT\n截图: $SCREENSHOT" \
            "high"
    else
        RESULT="UNKNOWN"
        warn "  ⚠️ 结果: UNKNOWN"
        info "  AI 反馈: $VERIFY_RESULT"
    fi
    
    # 保存截图
    if [ -n "$SCREENSHOT" ]; then
        DEST_DIR="$PROJECT_ROOT/reports/screenshots/$(date +%Y%m%d)"
        mkdir -p "$DEST_DIR"
        cp "$SCREENSHOT" "$DEST_DIR/${TC_NAME}_${RESULT}.png" 2>/dev/null || true
    fi
    
    # 更新结果 JSON
    cat > "$RESULTS_FILE" << EOF
{
  "site": "$SITE",
  "executed_at": "$(date -Iseconds)",
  "session_id": "$SESSION_ID",
  "summary": { "total": $TOTAL, "passed": $PASSED, "failed": $FAILED, "skipped": $SKIPPED },
  "results": [
    {
      "tc_name": "$TC_NAME",
      "result": "$RESULT",
      "verify": "$VERIFY_RESULT",
      "screenshot": "$SCREENSHOT"
    }
  ]
}
EOF
done

# 关闭浏览器
midscene_close

# 生成 HTML 报告
info ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "📊 测试完成"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "  总计: $TOTAL"
info "  通过: $PASSED"
info "  失败: $FAILED"
info "  跳过: $SKIPPED"

# 生成报告
generate_report "$SITE" "$(cat "$RESULTS_FILE")"

success "✅ 测试执行完成"
info "   结果: $RESULTS_FILE"
info "   截图: $PROJECT_ROOT/reports/screenshots/$(date +%Y%m%d)/"

#!/bin/bash
# explore.sh - 探索模式：对网站进行探索，生成测试用例
# 用法: ./explore.sh <site_name> [url]
# 示例: ./explore.sh falcon https://falcon.akusre.com/

set -e
source "$(dirname "$0")/common.sh"

usage() {
    cat << EOF
用法: $(basename "$0") <site_name> [url]

探索指定网站，AI 自主发现页面元素和功能，生成测试用例。

示例:
  $(basename "$0") falcon https://falcon.akusre.com/
  $(basename "$0") github https://github.com/

EOF
    exit 1
}

[ $# -lt 1 ] && usage

SITE="$1"
URL="${2:-}"
SESSION_ID="explore-$(date +%Y%m%d-%H%M%S)"

info "🚀 开始探索模式: $SITE"
[ -n "$URL" ] && info "   URL: $URL"

# 加载环境
load_env

# 如果没有提供 URL，从配置读取
if [ -z "$URL" ]; then
    info "从配置读取 URL..."
    URL=$(grep -A5 "name: $SITE" "$PROJECT_ROOT/config/sites.yaml" 2>/dev/null | grep "url:" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
    if [ -z "$URL" ]; then
        error "未提供 URL，请通过参数或 config/sites.yaml 提供"
        exit 1
    fi
fi

# 获取网站配置（用于登录信息）
SITE_CONFIG=$(get_site_config "$SITE" 2>/dev/null || echo "")

# 创建用例目录
SITE_DIR=$(init_site_dir "$SITE")
info "用例目录: $SITE_DIR"

# 开始探索
info "📡 连接网站..."
midscene_connect "$URL"

# 检查是否需要登录
if echo "$SITE_CONFIG" | grep -q "login:"; then
    info "检测到需要登录，执行登录流程..."
    LOGIN_TYPE=$(echo "$SITE_CONFIG" | grep "type:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    if [ "$LOGIN_TYPE" = "ldap" ]; then
        midscene act --prompt "点击切换到LDAP账号密码登录模式"
        sleep 2
        USERNAME=$(echo "$SITE_CONFIG" | grep "username:" | head -1 | cut -d: -f2 | tr -d ' ')
        PASSWORD=$(echo "$SITE_CONFIG" | grep "password:" | head -1 | cut -d: -f2 | tr -d ' ')
        midscene act --prompt "输入账号 $USERNAME 和密码（不要泄露密码内容，只描述操作），然后点击登录按钮"
        sleep 3
        info "登录完成"
    fi
fi

# 探索首页
info "🔍 探索首页元素..."
midscene act --prompt "详细探索这个页面，列出所有你能看到和交互的元素，包括：
1. 导航菜单和链接
2. 按钮（名称和位置）
3. 表单输入框
4. 图片或图标
5. 任何可点击的区域
请用自然语言描述每个元素的外观和可能的功能。"

midscene_screenshot
SCREENSHOT_1=$(get_screenshot_path)

# 分析截图，生成页面报告
info "🤖 AI 分析页面结构..."
EXPLORE_RESULT=$(midscene act --prompt "基于上一步的探索结果，输出一份详细的页面功能报告，格式如下：

## 页面功能报告

### 发现的元素
| 元素描述 | 类型 | 位置 | 可能功能 |
|---------|------|------|---------|
| ... | button | ... | ... |

### 主要功能模块
1. ...
2. ...

### 建议的测试用例
1. TC-XXX: [测试场景]

保存此报告。")

# 探索更多页面（如果有子页面链接）
SUB_PAGES=$(midscene act --prompt "找出页面上可能链接到其他页面的元素，列出每个链接的描述和URL（如果能看到的话）。")

# 生成测试用例
info "📝 生成测试用例..."

TC_ID="TC-$(date +%Y%m%d)001"

cat > "$SITE_DIR/$(date +%Y%m%d)_explore_report.md" << EOF
# 探索报告: $SITE
- 探索时间: $(date +"%Y-%m-%d %H:%M:%S")
- URL: $URL
- Session: $SESSION_ID
- 截图: $SCREENSHOT_1

## 探索结果

$EXPLORE_RESULT

## 发现的子页面

$SUB_PAGES

## 生成的测试用例

$TC_ID: 首页功能验证

### 测试步骤
1. 验证页面加载完成
2. 识别所有可见元素
3. 测试主要导航（如果可用）

### 验收标准
- 页面正常加载
- 主要元素可见
- 无 JavaScript 错误

---
*此报告由 Hermes Browser Test Harness 自动生成*
EOF

# 记录学习
log_learning "learning" \
    "探索 $SITE 完成" \
    "探索了 $URL，发现主要元素和功能，生成初步测试用例 $TC_ID。截图保存在 $SCREENSHOT_1" \
    "low"

success "✅ 探索完成！"
info "   报告: $SITE_DIR/$(date +%Y%m%d)_explore_report.md"
info "   截图: $SCREENSHOT_1"

# 关闭浏览器
midscene_close

# 显示生成的报告
echo ""
info "📋 探索摘要:"
cat "$SITE_DIR/$(date +%Y%m%d)_explore_report.md"

echo ""
info "💡 后续步骤:"
echo "   1. 查看报告，补充/修改测试用例"
echo "   2. 运行 ./execute.sh $SITE 执行测试"
echo "   3. 查看 reports/ 目录获取测试报告"

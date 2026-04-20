#!/bin/bash
# common.sh - Hermes Browser Test 公共函数库

set -e

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 加载环境变量
load_env() {
    if [ -f "$PROJECT_ROOT/config/midscene.env" ]; then
        source "$PROJECT_ROOT/config/midscene.env"
    elif [ -f "$HOME/.env" ]; then
        source "$HOME/.env"
    fi
    
    # 检查必需变量
    if [ -z "$MIDSCENE_MODEL_API_KEY" ]; then
        echo "❌ MIDSCENE_MODEL_API_KEY 未设置"
        echo "   请配置 config/midscene.env 或 ~/.env"
        exit 1
    fi
}

# Midscene 命令封装
midscene() {
    source ~/.env 2>/dev/null || true
    npx @midscene/web@1 "$@"
}

# 连接网页
midscene_connect() {
    local url="$1"
    echo "🔗 连接: $url"
    midscene connect --url "$url"
    sleep 2
}

# 截图
midscene_screenshot() {
    midscene take_screenshot
    echo "📸 截图已保存"
}

# 执行动作（带重试）
midscene_act() {
    local prompt="$1"
    local max_retry="${2:-2}"
    
    midscene act --prompt "$prompt"
}

# 关闭浏览器
midscene_close() {
    midscene close 2>/dev/null || true
}

# 获取截图路径
get_screenshot_path() {
    local temp_dir="${TMPDIR:-/tmp}"
    ls -t "${temp_dir}/screenshot-"*.png 2>/dev/null | head -1
}

# 创建用例目录
init_site_dir() {
    local site="$1"
    local site_dir="$PROJECT_ROOT/testcases/$site"
    mkdir -p "$site_dir"
    echo "$site_dir"
}

# 初始化 learnings 目录
init_learnings() {
    mkdir -p "$PROJECT_ROOT/learnings"
    mkdir -p "$PROJECT_ROOT/reports"
    
    for f in errors.md learnings.md feature_requests.md; do
        if [ ! -f "$PROJECT_ROOT/learnings/$f" ]; then
            echo "# $f" > "$PROJECT_ROOT/learnings/$f"
        fi
    done
}

# 记录学习
log_learning() {
    local type="$1"      # error | learning | feature
    local title="$2"
    local content="$3"
    local priority="${4:-medium}"
    
    local file="$PROJECT_ROOT/learnings/${type}s.md"
    local id="$(date +%Y%m%d)-$(head /dev/urandom | tr -dc 'A-Z0-9' | head -3)"
    
    cat >> "$file" << EOF

## [$id] $title

**Logged**: $(date -Iseconds)
**Priority**: $priority
**Status**: pending

### 内容
$content

---
EOF
    echo "📝 记录到 $file: $title"
}

# 读取网站配置
get_site_config() {
    local site="$1"
    local config_file="$PROJECT_ROOT/config/sites.yaml"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ 配置文件不存在: $config_file"
        exit 1
    fi
    
    # 简单的 YAML 解析（后续可升级为 yq）
    grep -A 20 "^  - name: $site" "$config_file" 2>/dev/null || {
        echo "❌ 未找到网站配置: $site"
        exit 1
    }
}

# 生成报告
generate_report() {
    local site="$1"
    local results="$2"  # JSON 格式的测试结果
    local report_file="$PROJECT_ROOT/reports/$(date +%Y%m%d_%H%M%S)_${site}.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Test Report - $site - $(date +%Y-%m-%d)</title>
    <style>
        body { font-family: -apple-system, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: #1a1a2e; color: white; padding: 20px; border-radius: 8px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric { background: #f5f5f5; padding: 15px; border-radius: 8px; }
        .metric .value { font-size: 2em; font-weight: bold; }
        .metric .label { color: #666; }
        .passed { color: #2ecc71; }
        .failed { color: #e74c3c; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f8f9fa; }
        .screenshot { max-width: 300px; border: 1px solid #ddd; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Hermes Browser Test Report</h1>
        <p>Site: $site | Generated: $(date +"%Y-%m-%d %H:%M:%S")</p>
    </div>
    <pre>$results</pre>
</body>
</html>
EOF
    echo "📊 报告已生成: $report_file"
}

# 颜色输出
info() { echo "ℹ️  $*"; }
success() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
error() { echo "❌ $*"; }

# 初始化
init_learnings

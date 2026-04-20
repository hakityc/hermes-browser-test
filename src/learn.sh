#!/bin/bash
# learn.sh - 学习模式：分析结果，更新 learnings，更新用例
# 用法: 
#   ./learn.sh analyze                    # 分析所有 learnings
#   ./learn.sh summary                    # 显示学习摘要
#   ./learn.sh promote <id> <target>     # 提升学习到系统文件

set -e
source "$(dirname "$0")/common.sh"

usage() {
    cat << EOF
用法: $(basename "$0") <command>

命令:
  analyze      分析最近的学习记录，识别模式
  summary      显示所有学习记录的摘要
  promote <id> <target>  提升学习到系统文件 (SOUL.md | AGENTS.md | TOOLS.md | MEMORY.md)
  errors       显示所有错误记录
  db           直接操作 learnings.db

示例:
  $(basename "$0") analyze
  $(basidian "$0") summary
  $(basename "$0") promote LRN-20260420-001 SOUL.md

EOF
    exit 1
}

[ $# -lt 1 ] && usage

COMMAND="$1"

case "$COMMAND" in
    analyze)
        info "🔍 分析学习记录..."
        
        # 分析错误
        ERRORS=$(cat "$PROJECT_ROOT/learnings/errors.md" 2>/dev/null | grep -c "^## \[" || echo "0")
        LEARNINGS=$(cat "$PROJECT_ROOT/learnings/learnings.md" 2>/dev/null | grep -c "^## \[" || echo "0")
        FEATURES=$(cat "$PROJECT_ROOT/learnings/feature_requests.md" 2>/dev/null | grep -c "^## \[" || echo "0")
        
        echo ""
        echo "📊 学习统计:"
        echo "   错误记录: $ERRORS"
        echo "   学习记录: $LEARNINGS"
        echo "   功能请求: $FEATURES"
        echo ""
        
        # 检查重复失败
        info "🔄 检查重复失败模式..."
        
        if [ -f "$PROJECT_ROOT/reports"/*.json ] 2>/dev/null; then
            LATEST_REPORT=$(ls -t "$PROJECT_ROOT/reports"/*.json 2>/dev/null | head -1)
            if [ -n "$LATEST_REPORT" ]; then
                echo "最新报告: $LATEST_REPORT"
            fi
        fi
        
        # 检查数据库
        DB="$PROJECT_ROOT/learnings.db"
        if [ -f "$DB" ] || [ -f "$HOME/.hermes/browser-test/learnings.db" ]; then
            DB="${DB:-$HOME/.hermes/browser-test/learnings.db}"
            echo ""
            echo "📊 数据库统计:"
            sqlite3 "$DB" "SELECT COUNT(*) as total FROM learnings;" 2>/dev/null || true
            sqlite3 "$DB" "SELECT outcome, COUNT(*) as count FROM learnings GROUP BY outcome;" 2>/dev/null || true
            sqlite3 "$DB" "SELECT page_pattern, COUNT(*) as count FROM learnings GROUP BY page_pattern;" 2>/dev/null || true
        fi
        
        # 识别模式
        echo ""
        info "🧠 识别的模式:"
        
        # 统计高频错误模式
        if [ -f "$HOME/.hermes/browser-test/learnings.db" ]; then
            sqlite3 "$HOME/.hermes/browser-test/learnings.db" << 'SQL' 2>/dev/null
.headers on
.mode list
SELECT '高频错误模式:';
SELECT error_mode, COUNT(*) as cnt FROM learnings WHERE error_mode IS NOT NULL AND error_mode != 'none' GROUP BY error_mode ORDER BY cnt DESC LIMIT 5;
SELECT '需关注的页面:';
SELECT page_pattern, COUNT(*) as cnt FROM learnings GROUP BY page_pattern ORDER BY cnt DESC LIMIT 5;
SQL
        fi
        
        echo ""
        info "💡 改进建议:"
        
        # 检查是否有重复失败
        if [ -f "$HOME/.hermes/browser-test/learnings.db" ]; then
            REPEATS=$(sqlite3 "$HOME/.hermes/browser-test/learnings.db" "SELECT task FROM learnings WHERE outcome='failed' GROUP BY task HAVING COUNT(*) >= 3;" 2>/dev/null)
            if [ -n "$REPEATS" ]; then
                echo "   ⚠️  以下用例连续失败 3+ 次，建议提升到系统提示:"
                echo "$REPEATS" | while read line; do echo "      - $line"; done
            else
                echo "   ✅ 无连续失败用例"
            fi
        fi
        ;;
        
    summary)
        echo ""
        echo "📋 学习记录摘要"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for type in errors learnings feature_requests; do
            FILE="$PROJECT_ROOT/learnings/${type}.md"
            if [ -f "$FILE" ]; then
                COUNT=$(grep -c "^## \[" "$FILE" 2>/dev/null || echo "0")
                echo ""
                echo "📁 ${type}s.md: $COUNT 条记录"
                grep "^## \[" "$FILE" 2>/dev/null | tail -5 | while read line; do
                    echo "   $line"
                done
            fi
        done
        ;;
        
    promote)
        ID="$2"
        TARGET="$3"
        
        if [ -z "$ID" ] || [ -z "$TARGET" ]; then
            error "需要指定 ID 和目标文件"
            usage
        fi
        
        # 查找学习记录
        FOUND=""
        for type in errors learnings feature_requests; do
            FILE="$PROJECT_ROOT/learnings/${type}.md"
            if [ -f "$FILE" ]; then
                ENTRY=$(grep -A20 "^## \[$ID\]" "$FILE" 2>/dev/null || echo "")
                if [ -n "$ENTRY" ]; then
                    FOUND="$ENTRY"
                    break
                fi
            fi
        done
        
        if [ -z "$FOUND" ]; then
            error "未找到学习记录: $ID"
            exit 1
        fi
        
        # 追加到目标文件
        TARGET_FILE="$HOME/.openclaw/workspace/$TARGET"
        if [ ! -f "$TARGET_FILE" ]; then
            warn "目标文件不存在: $TARGET_FILE"
            read -p "创建? [y/N] " -n 1 -r; echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi
        
        echo "" >> "$TARGET_FILE"
        echo "## [$ID] (提升)" >> "$TARGET_FILE"
        echo "$FOUND" >> "$TARGET_FILE"
        echo "" >> "$TARGET_FILE"
        
        # 更新原记录状态
        for type in errors learnings feature_requests; do
            FILE="$PROJECT_ROOT/learnings/${type}.md"
            if [ -f "$FILE" ]; then
                sed -i '' "s/^## \[$ID\]/## [$ID] (已提升到 $TARGET)/" "$FILE" 2>/dev/null || true
            fi
        done
        
        success "已提升 $ID 到 $TARGET"
        ;;
        
    db)
        shift
        DB="${PROJECT_ROOT}/learnings.db"
        if [ ! -f "$DB" ] && [ -f "$HOME/.hermes/browser-test/learnings.db" ]; then
            DB="$HOME/.hermes/browser-test/learnings.db"
        fi
        
        if [ ! -f "$DB" ]; then
            error "数据库不存在"
            exit 1
        fi
        
        sqlite3 "$DB" "$@"
        ;;
        
    *)
        error "未知命令: $COMMAND"
        usage
        ;;
esac

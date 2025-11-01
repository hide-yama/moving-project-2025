#!/bin/bash

# 未完了タスク抽出スクリプト
# タスク一覧.mdから未完了タスク（- [ ]）のみを抽出して未完了タスク一覧.mdを生成

INPUT_FILE="タスク一覧.md"
OUTPUT_FILE="未完了タスク一覧.md"

# 作業ディレクトリの確認
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 入力ファイルの存在チェック
if [ ! -f "$INPUT_FILE" ]; then
    echo "エラー: $INPUT_FILE が見つかりません"
    exit 1
fi

# 一時ファイル
TEMP_FILE=$(mktemp)

# ヘッダー作成
cat > "$OUTPUT_FILE" << 'EOF'
# 未完了タスク一覧

**自動生成ファイル - 直接編集しないでください**

このファイルは `generate_uncompleted_tasks.sh` スクリプトにより自動生成されます。
タスクを完了したら `タスク一覧.md` を更新し、このスクリプトを再実行してください。

---

EOF

# 最終更新日時を追記
echo "最終生成: $(date '+%Y年%m月%d日 %H:%M')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# タスク一覧.mdを解析
awk '
BEGIN {
    current_section = ""
    current_subsection = ""
    section_buffer = ""
    subsection_buffer = ""
    task_buffer = ""
    section_has_uncompleted = 0
    subsection_has_uncompleted = 0
    in_uncompleted_task = 0
    task_indent = 0
}

# セクションヘッダー（## で始まる行）
/^##/ {
    # 前のサブセクションを出力判定
    flush_subsection()
    # 前のセクションを出力判定
    flush_section()

    # 新しいセクション開始
    current_section = $0
    section_buffer = $0 "\n"
    section_has_uncompleted = 0
    current_subsection = ""
    subsection_buffer = ""
    next
}

# サブセクションヘッダー（### で始まる行）
/^###/ {
    # 前のサブセクションを出力判定
    flush_subsection()

    # 新しいサブセクション開始
    current_subsection = $0
    subsection_buffer = $0 "\n"
    subsection_has_uncompleted = 0
    next
}

# 未完了タスク（- [ ]）の行（インデントなし、つまり親タスク）
/^- \[ \]/ {
    flush_task()
    in_uncompleted_task = 1
    task_buffer = $0 "\n"
    task_indent = 0
    section_has_uncompleted = 1
    subsection_has_uncompleted = 1
    next
}

# 完了タスク（- [x]）の行（インデントなし）
/^- \[x\]/ {
    flush_task()
    in_uncompleted_task = 0
    task_buffer = ""
    next
}

# インデントされたタスク（子タスク）
/^[[:space:]]+- \[/ {
    if (in_uncompleted_task) {
        task_buffer = task_buffer $0 "\n"
    }
    next
}

# その他のインデント行（タスクの詳細）
/^[[:space:]]+/ {
    if (in_uncompleted_task) {
        task_buffer = task_buffer $0 "\n"
    }
    next
}

# 空行
/^$/ {
    if (in_uncompleted_task) {
        task_buffer = task_buffer "\n"
    } else if (current_subsection != "") {
        subsection_buffer = subsection_buffer "\n"
    } else if (current_section != "") {
        section_buffer = section_buffer "\n"
    }
    next
}

# その他の行
{
    if (in_uncompleted_task) {
        task_buffer = task_buffer $0 "\n"
    } else if (current_subsection != "") {
        subsection_buffer = subsection_buffer $0 "\n"
    } else if (current_section != "") {
        section_buffer = section_buffer $0 "\n"
    }
}

function flush_task() {
    if (in_uncompleted_task && task_buffer != "") {
        subsection_buffer = subsection_buffer task_buffer
    }
    task_buffer = ""
    in_uncompleted_task = 0
}

function flush_subsection() {
    flush_task()
    if (subsection_has_uncompleted && subsection_buffer != "") {
        section_buffer = section_buffer subsection_buffer
    }
    subsection_buffer = ""
    subsection_has_uncompleted = 0
    current_subsection = ""
}

function flush_section() {
    if (section_has_uncompleted && section_buffer != "") {
        print section_buffer
    }
    section_buffer = ""
    section_has_uncompleted = 0
    current_section = ""
}

END {
    flush_subsection()
    flush_section()
}
' "$INPUT_FILE" >> "$OUTPUT_FILE"

# 生成完了メッセージ
echo "✅ 未完了タスク一覧を生成しました: $OUTPUT_FILE"
echo ""
echo "📊 統計情報:"
TOTAL_TASKS=$(grep -c "^[[:space:]]*- \[" "$INPUT_FILE" || echo "0")
COMPLETED_TASKS=$(grep -c "^[[:space:]]*- \[x\]" "$INPUT_FILE" || echo "0")
UNCOMPLETED_TASKS=$(grep -c "^[[:space:]]*- \[ \]" "$INPUT_FILE" || echo "0")

echo "  総タスク数: $TOTAL_TASKS"
echo "  完了: $COMPLETED_TASKS"
echo "  未完了: $UNCOMPLETED_TASKS"

if [ $TOTAL_TASKS -gt 0 ]; then
    PROGRESS=$((COMPLETED_TASKS * 100 / TOTAL_TASKS))
    echo "  進捗率: ${PROGRESS}%"
fi

# 一時ファイル削除
rm -f "$TEMP_FILE"

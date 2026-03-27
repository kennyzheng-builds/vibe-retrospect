#!/bin/bash
# Parse Claude Code session logs (.jsonl) and extract key information
# Usage: bash parse-sessions.sh <project-dir-in-claude-projects>
#
# The session logs are in ~/.claude/projects/{project-id}/
# Each .jsonl file is one conversation session.
#
# This script extracts:
# 1. User messages (the human's decisions, feedback, questions)
# 2. Key decision moments
# 3. Timeline of the development process
# 4. Session summaries

PROJECT_DIR="$1"

if [ -z "$PROJECT_DIR" ]; then
  echo "Usage: bash parse-sessions.sh <path-to-claude-project-dir>"
  echo "Example: bash parse-sessions.sh ~/.claude/projects/-home-node-myproject-workspace/"
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Directory not found: $PROJECT_DIR"
  exit 1
fi

OUTPUT_DIR="${2:-./session-analysis}"
mkdir -p "$OUTPUT_DIR"

echo "=== Vibe Retrospect: Session Log Analysis ==="
echo "Project dir: $PROJECT_DIR"
echo "Output dir: $OUTPUT_DIR"
echo ""

# Count sessions
SESSION_COUNT=$(ls "$PROJECT_DIR"/*.jsonl 2>/dev/null | wc -l)
echo "Found $SESSION_COUNT session log(s)"
echo ""

# For each session, extract user messages and basic assistant responses
SESSION_NUM=0
for JSONL in "$PROJECT_DIR"/*.jsonl; do
  SESSION_NUM=$((SESSION_NUM + 1))
  SESSION_ID=$(basename "$JSONL" .jsonl)
  SESSION_FILE="$OUTPUT_DIR/session-${SESSION_NUM}.md"

  LINE_COUNT=$(wc -l < "$JSONL")
  FILE_SIZE=$(du -h "$JSONL" | cut -f1)

  # Get first and last timestamps
  FIRST_TS=$(head -1 "$JSONL" | python3 -c "import sys,json; d=json.loads(sys.stdin.readline()); print(d.get('timestamp','unknown'))" 2>/dev/null)
  LAST_TS=$(tail -1 "$JSONL" | python3 -c "import sys,json; d=json.loads(sys.stdin.readline()); print(d.get('timestamp','unknown'))" 2>/dev/null)

  echo "Session $SESSION_NUM: $SESSION_ID"
  echo "  Lines: $LINE_COUNT, Size: $FILE_SIZE"
  echo "  Time: $FIRST_TS → $LAST_TS"

  # Extract user messages and short assistant text responses
  python3 -c "
import json, sys

session_file = '$JSONL'
output_file = '$SESSION_FILE'

user_msgs = []
assistant_texts = []
decisions = []
feedback = []
problems = []

with open(session_file, 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = entry.get('type', '')
        message = entry.get('message', {})
        timestamp = entry.get('timestamp', '')

        if msg_type == 'user':
            content = message.get('content', [])
            for block in content:
                if isinstance(block, dict) and block.get('type') == 'text':
                    text = block['text']
                    user_msgs.append({'ts': timestamp, 'text': text})

                    # Detect decisions (user confirming or rejecting)
                    lower = text.lower()
                    decision_keywords = ['可以', '不要', '先不做', '改成', '方案', '确认', '同意',
                                        '不对', '太', '应该', '必须', '别', '停', '重要',
                                        'ok', 'good', 'no', 'yes', 'stop', 'change']
                    if any(kw in lower for kw in decision_keywords) and len(text) < 500:
                        decisions.append({'ts': timestamp, 'text': text})

                    # Detect feedback on collaboration
                    feedback_keywords = ['以后', '下次', '不要再', '记住', '规则', '规范',
                                         '从现在起', '习惯', 'remember', 'always', 'never']
                    if any(kw in lower for kw in feedback_keywords) and len(text) < 500:
                        feedback.append({'ts': timestamp, 'text': text})
                elif isinstance(block, str):
                    user_msgs.append({'ts': timestamp, 'text': block})

        elif msg_type == 'assistant':
            content = message.get('content', [])
            for block in content:
                if isinstance(block, dict) and block.get('type') == 'text':
                    text = block['text']
                    # Only keep short text responses (not tool calls or long code blocks)
                    if len(text) < 2000 and '\`\`\`' not in text[:100]:
                        assistant_texts.append({'ts': timestamp, 'text': text[:500]})

with open(output_file, 'w') as f:
    f.write(f'# Session $SESSION_NUM Analysis\n\n')
    f.write(f'Session ID: \`$SESSION_ID\`\n')
    f.write(f'Time: {user_msgs[0][\"ts\"] if user_msgs else \"unknown\"} → {user_msgs[-1][\"ts\"] if user_msgs else \"unknown\"}\n')
    f.write(f'User messages: {len(user_msgs)}\n\n')

    f.write('## User Messages (Chronological)\n\n')
    for msg in user_msgs:
        text = msg['text'][:1000]
        f.write(f'**[{msg[\"ts\"][:19]}]**\n')
        f.write(f'{text}\n\n---\n\n')

    if decisions:
        f.write('## Key Decisions Detected\n\n')
        for d in decisions:
            f.write(f'- [{d[\"ts\"][:19]}] {d[\"text\"][:200]}\n')
        f.write('\n')

    if feedback:
        f.write('## Collaboration Feedback Detected\n\n')
        for fb in feedback:
            f.write(f'- [{fb[\"ts\"][:19]}] {fb[\"text\"][:200]}\n')
        f.write('\n')

print(f'  → Extracted {len(user_msgs)} user messages, {len(decisions)} decisions, {len(feedback)} feedback items')
" 2>/dev/null

  echo ""
done

# Generate summary
python3 -c "
import os, glob

output_dir = '$OUTPUT_DIR'
summary_file = os.path.join(output_dir, 'SUMMARY.md')

with open(summary_file, 'w') as f:
    f.write('# Session Analysis Summary\n\n')
    f.write('Total sessions: $SESSION_COUNT\n\n')
    f.write('## Session Files\n\n')
    for i in range(1, $SESSION_COUNT + 1):
        sf = os.path.join(output_dir, f'session-{i}.md')
        if os.path.exists(sf):
            size = os.path.getsize(sf)
            f.write(f'- session-{i}.md ({size//1024}KB)\n')
    f.write('\n')
    f.write('## How to Use\n\n')
    f.write('Read each session file chronologically to understand the development journey.\n')
    f.write('Pay special attention to:\n')
    f.write('- **Key Decisions**: Where the user confirmed or rejected approaches\n')
    f.write('- **Collaboration Feedback**: Rules the user established during the project\n')
    f.write('- **User Messages**: The full context of what the user was thinking\n')

print(f'Summary written to {summary_file}')
"

echo ""
echo "=== Analysis Complete ==="
echo "Output: $OUTPUT_DIR/"
echo "Files:"
ls -la "$OUTPUT_DIR/"

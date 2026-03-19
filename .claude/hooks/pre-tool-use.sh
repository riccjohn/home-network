#!/usr/bin/env bash
# pre-tool-use.sh — blocks Read/Write/Edit on .env* files except .env.example.
# Receives JSON on stdin with tool_name and tool_input.
# Exit 2 blocks the tool call and surfaces the message to the agent.

input=$(cat)

file_path=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" <<< "$input" 2>/dev/null || echo "")

if [[ -z "$file_path" ]]; then
  exit 0
fi

basename="${file_path##*/}"

if [[ "$basename" == .env* && "$basename" != ".env.example" && "$basename" != ".env.dev.example" ]]; then
  echo "BLOCKED: '$basename' may contain secrets and cannot be read or modified by agents."
  echo "Use .env.example for variable references and documentation instead."
  exit 2
fi

exit 0

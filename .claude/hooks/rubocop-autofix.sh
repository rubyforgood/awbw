#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ ! "$FILE_PATH" =~ \.rb$ ]]; then
  exit 0
fi
bundle exec rubocop -A --format quiet "$FILE_PATH" 2>/dev/null
exit 0

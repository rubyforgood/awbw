#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ ! "$FILE_PATH" =~ \.rb$|\.erb$ ]]; then
  exit 0
fi
# Get path relative to project root
REL_PATH="${FILE_PATH#$CLAUDE_PROJECT_DIR/}"
OUTPUT=$(bundle exec brakeman --only-files "$REL_PATH" --no-pager --format text --quiet --no-summary 2>/dev/null)
if [ -n "$OUTPUT" ] && ! echo "$OUTPUT" | grep -q "No warnings found"; then
  echo "Brakeman warnings in $REL_PATH:" >&2
  echo "$OUTPUT" >&2
fi
exit 0

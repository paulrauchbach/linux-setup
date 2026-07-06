#!/usr/bin/env bash
# Claude Code statusLine script - token count in yellow

input=$(cat)

total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')

if [ -z "$total_tokens" ] || [ "$total_tokens" = "null" ]; then
  exit 0
fi

# Format as abbreviated thousands, e.g. "1.5k" or "12.3k"
formatted=$(awk -v n="$total_tokens" 'BEGIN {
  k = n / 1000
  if (k >= 10) {
    printf "%.1fk", k
  } else {
    printf "%.1fk", k
  }
}')

printf "\033[33m%s\033[0m" "$formatted"

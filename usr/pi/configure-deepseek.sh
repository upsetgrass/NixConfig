#!/usr/bin/env bash
set -euo pipefail
umask 077

jq_bin=$1
coreutils_bin=$2
models_dir="$HOME/.pi/agent"
models_file="$models_dir/models.json"
key_command="!$coreutils_bin/cat $HOME/.config/deepseek/api-key"

if [[ -L $models_file ]]; then
  printf 'Refusing to replace symlink: %s\n' "$models_file" >&2
  exit 1
fi

if [[ -f $models_file ]]; then
  current_command=$("$jq_bin" -r '.providers.deepseek.apiKey // empty' "$models_file")
  [[ $current_command != "$key_command" ]] || exit 0
fi

"$coreutils_bin/mkdir" -p "$models_dir"
temp_file=$("$coreutils_bin/mktemp" "$models_dir/.models.json.XXXXXX")
trap '"$coreutils_bin/rm" -f "$temp_file"' EXIT

if [[ -f $models_file ]]; then
  "$jq_bin" --arg key_command "$key_command" \
    '.providers = (.providers // {}) | .providers.deepseek = (.providers.deepseek // {}) | .providers.deepseek.apiKey = $key_command' \
    "$models_file" > "$temp_file"
else
  "$jq_bin" -n --arg key_command "$key_command" \
    '{providers: {deepseek: {apiKey: $key_command}}}' > "$temp_file"
fi

"$coreutils_bin/chmod" 600 "$temp_file"
"$coreutils_bin/mv" "$temp_file" "$models_file"
trap - EXIT

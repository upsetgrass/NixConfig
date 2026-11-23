#!/usr/bin/env bash
set -euo pipefail
umask 077

jq_bin=$1
coreutils_bin=$2
catalog_file=$3
cmp_bin=$4
models_dir="$HOME/.pi/agent"
models_file="$models_dir/models.json"

if [[ -L $models_file ]]; then
  printf 'Refusing to replace symlink: %s\n' "$models_file" >&2
  exit 1
fi

"$coreutils_bin/mkdir" -p "$models_dir"
temp_file=$("$coreutils_bin/mktemp" "$models_dir/.models.json.XXXXXX")
trap '"$coreutils_bin/rm" -f "$temp_file"' EXIT

# Preserve local providers, credentials, transport settings and extra models.
# The catalog owns metadata for its model IDs, retaining local extra fields.
input_file=/dev/null
if [[ -f $models_file ]]; then
  input_file=$models_file
fi
"$jq_bin" --slurp --slurpfile catalog "$catalog_file" '
  (.[0] // {}) |
  reduce ($catalog[0].providers | to_entries[]) as $provider (. // {};
    (.providers[$provider.key] // {}) as $local |
    ($local.models // []) as $localModels |
    ($provider.value.models // []) as $managedModels |
    .providers[$provider.key] = (
      ($provider.value * $local) + {
        models: (
          [$managedModels[] as $model |
            ([$localModels[] | select(.id == $model.id)][0] // {}) * $model] +
          [$localModels[] | select(.id as $id | all($managedModels[]; .id != $id))]
        )
      }
    )
  )
' "$input_file" > "$temp_file"

if [[ -f $models_file ]] && "$cmp_bin" -s "$temp_file" "$models_file"; then
  exit 0
fi
"$coreutils_bin/chmod" 600 "$temp_file"
"$coreutils_bin/mv" -f "$temp_file" "$models_file"
trap - EXIT

#!/usr/bin/env bash
set -eu

browser="${1:-edge}"
if [ "$#" -gt 0 ]; then shift; fi
case "$browser" in
  edge)
    candidates=(microsoft-edge-stable microsoft-edge)
    script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
    export EDGE_USER_DATA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nix-edge"
    "$script_dir/../edge/apply-settings.sh"
    ;;
  chrome) candidates=(google-chrome-stable google-chrome) ;;
  *) echo "Usage: $0 {edge|chrome} [browser arguments...]" >&2; exit 2 ;;
esac

# Match the native GTK Fcitx module on this GNOME/X11 host.
export GTK_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
for candidate in "${candidates[@]}"; do
  executable="$(command -v "$candidate" || true)"
  if [ -n "$executable" ] && [ -x "$executable" ]; then
    if [ "$browser" = edge ]; then
      exec "$executable" --ozone-platform=x11 \
        --user-data-dir="$EDGE_USER_DATA_DIR" --profile-directory=Default \
        --restore-last-session --no-first-run --no-default-browser-check "$@"
    fi
    exec "$executable" --ozone-platform=x11 "$@"
  fi
done
echo "$browser is not installed in PATH; install it or enter ~/nix/shell.nix." >&2
exit 127

#!/usr/bin/env bash
set -eu

browser="${1:-edge}"
if [ "$#" -gt 0 ]; then shift; fi
case "$browser" in
  edge) candidates=(microsoft-edge-stable microsoft-edge) ;;
  chrome) candidates=(google-chrome-stable google-chrome) ;;
  *) echo "Usage: $0 {edge|chrome} [browser arguments...]" >&2; exit 2 ;;
esac

# Match the native GTK Fcitx module on this GNOME/X11 host.
export GTK_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
for candidate in "${candidates[@]}"; do
  if [ -x "/usr/bin/$candidate" ]; then
    exec "/usr/bin/$candidate" --ozone-platform=x11 "$@"
  fi
done
echo "$browser is not installed in /usr/bin; install the browser first." >&2
exit 127

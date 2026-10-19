#!/usr/bin/env bash
set -eu

# This host uses GNOME/X11. Snap includes GTK's XIM module; connect to
# Fcitx5's XIM frontend without relying on a sandboxed Fcitx D-Bus module.
export GTK_IM_MODULE=xim
export XMODIFIERS=@im=fcitx
export MOZ_ENABLE_WAYLAND=0

exec /snap/bin/firefox "$@"

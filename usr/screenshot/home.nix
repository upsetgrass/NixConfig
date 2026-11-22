{ lib, pkgs, ... }:

let
  bindingPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/nix-screenshot-preview/";
  bindingSchema = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${bindingPath}";
  mediaKeysSchema = "org.gnome.settings-daemon.plugins.media-keys";
  # Ubuntu's GNOME reads dconf. Nix glib's gsettings lacks the dconf module
  # here and would write to an unrelated keyfile instead.
  gsettings = "/usr/bin/gsettings";

  # Disable mpv's normal mouse controls: double-click or Escape closes it.
  previewKeys = pkgs.writeText "screenshot-preview-input.conf" ''
    MBTN_LEFT ignore
    MBTN_LEFT_DBL quit
    ESC quit
  '';

  preview = pkgs.writeShellScriptBin "screenshot-preview" ''
    set -euo pipefail
    screenshot_dir="$(${pkgs.xdg-user-dirs}/bin/xdg-user-dir PICTURES)/截图"
    if [ ! -d "$screenshot_dir" ]; then
      echo "Screenshot directory not found: $screenshot_dir" >&2
      exit 1
    fi

    # GNOME writes PNG screenshots here; choose the newest by modification time.
    latest="$(${pkgs.findutils}/bin/find "$screenshot_dir" -maxdepth 1 -type f -iname '*.png' -printf '%T@ %p\n' | ${pkgs.coreutils}/bin/sort -nr | ${pkgs.gnused}/bin/sed -n '1s/^[^ ]* //p')"
    if [ -z "$latest" ]; then
      echo "No PNG screenshots found in $screenshot_dir" >&2
      exit 1
    fi

    # Preserve screenshot pixels (including the captured application's zoom).
    # Avoid enlarging small captures or applying the desktop DPI scale twice.
    # Only screenshots larger than the screen are reduced to fit.
    exec ${pkgs.mpv}/bin/mpv --no-config --no-border --ontop --no-osc --input-default-bindings=no --input-conf=${previewKeys} --keep-open=yes --window-scale=1 --hidpi-window-scale=no --video-unscaled=downscale-big --autofit-larger=100%x100% -- "$latest"
  '';
in
{
  home.packages = [ preview ];

  # Add our key without replacing any of the user's existing GNOME shortcuts.
  home.activation.screenshotPreviewShortcut = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && ${gsettings} list-schemas | ${pkgs.gnugrep}/bin/grep -qx ${mediaKeysSchema}; then
      existing="$(${gsettings} get ${mediaKeysSchema} custom-keybindings)"
      ${gsettings} set '${bindingSchema}' name '预览最新截图'
      ${gsettings} set '${bindingSchema}' command '${preview}/bin/screenshot-preview'
      ${gsettings} set '${bindingSchema}' binding '<Primary><Shift><Alt>e'
      case "$existing" in
        *"'${bindingPath}'"*) ;;
        '@as []'|'[]') ${gsettings} set ${mediaKeysSchema} custom-keybindings "['${bindingPath}']" ;;
        *) ${gsettings} set ${mediaKeysSchema} custom-keybindings "''${existing%]}, '${bindingPath}']" ;;
      esac
    else
      echo 'Skipping screenshot shortcut registration (no GNOME session bus).'
    fi
  '';
}

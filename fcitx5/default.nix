{
  pkgs ? import (import ../npins).nixpkgs { config.allowUnfree = true; },
  stopServicesOnExit ? false,
  oriSource ? (import ../npins).ori-fcitx5,
}:

let
  inherit (pkgs) lib;
  # npins supplies a fixed, hashed theme source without evaluation-time Git access.
  oriTheme = pkgs.runCommand "fcitx5-ori-light" {} ''
    mkdir -p "$out/share/fcitx5/themes"
    cp -r ${oriSource}/OriLight "$out/share/fcitx5/themes/OriLight"
  '';

  # Each line becomes a separate candidate for the same /emoji query.
  emojiFile = ./emoji.mb;
  emojiAddon = pkgs.runCommand "fcitx5-emoji-menu" {} ''
    install -Dm644 ${emojiFile} "$out/share/fcitx5/data/quickphrase.d/emoji-menu.mb"
  '';

  fontConfig = pkgs.writeText "fcitx5-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <include ignore_missing="yes">${pkgs.fontconfig.out}/etc/fonts/fonts.conf</include>
      <dir>${pkgs.arphic-ukai}/share/fonts</dir>
      <dir>/usr/share/fonts</dir>
      <dir>/usr/local/share/fonts</dir>
      <dir prefix="xdg">fonts</dir>
      <dir>~/.local/share/fonts</dir>
      <dir>~/.fonts</dir>
      <cachedir prefix="xdg">fontconfig</cachedir>
    </fontconfig>
  '';

  # Convert the Sogou cell dictionaries into native libime dictionaries.
  sogouDirectory = ./dictionaries/sogou;
  sogouFiles = builtins.filter (name: lib.hasSuffix ".scel" name)
    (builtins.attrNames (builtins.readDir sogouDirectory));
  sogouDictionary = pkgs.runCommand "fcitx5-pinyin-sogou" {
    src = sogouDirectory;
  } ''
    mkdir -p "$out/share/fcitx5/pinyin/dictionaries"
    ${lib.concatStringsSep "\n" (lib.imap0 (index: name: ''
      # scel2org5 prints dictionary metadata on stderr even on success.
      # Keep successful conversions quiet, but preserve diagnostics on failure.
      if ${pkgs.qt6Packages.fcitx5-chinese-addons}/bin/scel2org5 \
        "$src"/${lib.escapeShellArg name} -o sogou-${toString index}.org \
        >sogou-${toString index}.log 2>&1; then
        :
      else
        status=$?
        cat sogou-${toString index}.log >&2
        exit "$status"
      fi
      if ${pkgs.libime}/bin/libime_pinyindict sogou-${toString index}.org \
        "$out/share/fcitx5/pinyin/dictionaries/sogou-${toString index}.dict" \
        >sogou-${toString index}-compile.log 2>&1; then
        :
      else
        status=$?
        cat sogou-${toString index}-compile.log >&2
        exit "$status"
      fi
    '') sogouFiles)}
  '';

  # Native Pinyin engine with Sogou extension dictionaries.
  addons = [
    pkgs.qt6Packages.fcitx5-chinese-addons
    sogouDictionary
    oriTheme
    emojiAddon
    (pkgs.writeTextDir "share/fcitx5/data/quickphrase.d/custom-emoji.mb" ''
      smile 😄
      smile 😊
      laugh 😂
      heart ❤️
      thumbsup 👍
      cry 😭
      party 🎉
    '')
  ];

  fcitx5 = pkgs.qt6Packages.fcitx5-with-addons.override {
    inherit addons;
    withConfigtool = true;
  };

  pagingSettings = {
    "Hotkey/PrevPage" = { "0" = "minus"; "1" = "Page_Up"; };
    "Hotkey/NextPage" = {
      "0" = "equal";
      "1" = "plus";
      "2" = "Shift+plus";
      "3" = "Page_Down";
    };
  };
  pagingConfig = pkgs.writeText "fcitx5-paging" (lib.generators.toINI {} pagingSettings);

  # Plain Fcitx5 files, also reusable with Home Manager's xdg.configFile.
  configFiles = {
    config = pkgs.writeText "fcitx5-config" (lib.generators.toINI {} (pagingSettings // {
      Hotkey.EnumerateWithTriggerKeys = "False";
      "Hotkey/TriggerKeys" = { "0" = "Shift_L"; "1" = "Shift_R"; };
      "Hotkey/AltTriggerKeys"."0" = "";
      "Hotkey/EnumerateGroupForwardKeys"."0" = "";
      "Hotkey/EnumerateGroupBackwardKeys"."0" = "";
      Behavior = {
        ActiveByDefault = "False";
        ShareInputState = "No";
      };
    }));

    profile = pkgs.writeText "fcitx5-profile" (lib.generators.toINI {} {
      "Groups/0" = {
        Name = "Default";
        "Default Layout" = "us";
        DefaultIM = "pinyin";
      };
      "Groups/0/Items/0" = { Name = "keyboard-us"; Layout = ""; };
      "Groups/0/Items/1" = { Name = "pinyin"; Layout = ""; };
      GroupOrder."0" = "Default";
    });

    "conf/pinyin.conf" = pkgs.writeText "fcitx5-pinyin.conf" ''
      EmojiEnabled=True
      QuickPhraseKey=slash
    '';

    "conf/quickphrase.conf" = pkgs.writeText "fcitx5-quickphrase.conf" ''
      Spell=False
    '';

    "conf/punctuation.conf" = pkgs.writeText "fcitx5-punctuation.conf" ''
      Enabled=True
      HalfWidthPuncAfterLetterOrNumber=False
    '';

    "conf/classicui.conf" = pkgs.writeText "fcitx5-classicui.conf" ''
      Font="Times New Roman,AR PL UKai CN 16"
      MenuFont="Times New Roman,AR PL UKai CN 16"
      TrayFont="Times New Roman,AR PL UKai CN 16"
      Theme=OriLight
      DarkTheme=OriLight
      UseDarkTheme=False
      UseAccentColor=False
    '';
  };

  environment = ''
    set -eu

    # Isolate only the daemon's XDG paths; applications keep their own paths.
    config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-fcitx5"
    data_root="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-fcitx5"
    cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-fcitx5"
    ${pkgs.coreutils}/bin/mkdir -p "$config_root/fcitx5/conf" "$data_root" "$cache_root"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: source: ''
      if [ ! -e "$config_root/fcitx5/${name}" ]; then
        ${pkgs.coreutils}/bin/install -m 600 ${source} "$config_root/fcitx5/${name}"
      fi
    '') configFiles)}

    # Install into the documented per-user dictionary path as well, so an
    # existing session never depends on an older add-on search path.
    ${pkgs.coreutils}/bin/mkdir -p "$data_root/fcitx5/data/quickphrase.d"
    ${pkgs.coreutils}/bin/install -m 600 ${emojiFile} \
      "$data_root/fcitx5/data/quickphrase.d/emoji-menu.mb"

    export XDG_CONFIG_HOME="$config_root"
    export XDG_DATA_HOME="$data_root"
    export XDG_CACHE_HOME="$cache_root"
    export XDG_DATA_DIRS="${fcitx5}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    export FONTCONFIG_FILE=${fontConfig}
  '';

  launcher = pkgs.writeShellScriptBin "fcitx5-nix" ''
    ${environment}
    exec ${fcitx5}/bin/fcitx5 "$@"
  '';

  configtool = pkgs.writeShellScriptBin "fcitx5-configtool" ''
    ${environment}
    exec ${fcitx5}/bin/fcitx5-config-qt "$@"
  '';

  firefoxLauncher = pkgs.writeShellScriptBin "firefox-fcitx5"
    (builtins.readFile ./firefox-fcitx5.sh);

  edgeLauncher = pkgs.writeShellScriptBin "edge-fcitx5" ''
    exec ${pkgs.bash}/bin/bash ${./chromium-fcitx5.sh} edge "$@"
  '';
  chromeLauncher = pkgs.writeShellScriptBin "chrome-fcitx5" ''
    exec ${pkgs.bash}/bin/bash ${./chromium-fcitx5.sh} chrome "$@"
  '';

  # Explicitly apply new UI defaults to an existing writable GUI configuration.
  # Wait for the old daemon to save and exit before changing its config file.
  applySettings = pkgs.writeShellScriptBin "fcitx5-nix-apply" ''
    ${environment}
    uid="$(${pkgs.coreutils}/bin/id -u)"
    if ${pkgs.procps}/bin/pgrep -u "$uid" -x 'fcitx5|\.fcitx5-wrapped' >/dev/null; then
      ${fcitx5}/bin/fcitx5-remote -e
      for attempt in $(${pkgs.coreutils}/bin/seq 1 50); do
        if ! ${pkgs.procps}/bin/pgrep -u "$uid" -x 'fcitx5|\.fcitx5-wrapped' >/dev/null; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 0.1
      done
      if ${pkgs.procps}/bin/pgrep -u "$uid" -x 'fcitx5|\.fcitx5-wrapped' >/dev/null; then
        echo "Fcitx5 has not exited. Close its configuration window and try again."
        exit 1
      fi
    fi
    global_config="$config_root/fcitx5/config"
    if [ ! -e "$global_config.before-paging" ]; then
      ${pkgs.coreutils}/bin/cp -p "$global_config" "$global_config.before-paging"
    fi
    paging_temp="$(${pkgs.coreutils}/bin/mktemp "$global_config.XXXXXXXX")"
    ${pkgs.gawk}/bin/awk '
      NR == FNR {
        if (/^\[/) section = $0
        if (section != "") replacement[section] = replacement[section] $0 "\n"
        next
      }
      /^\[/ {
        skip = ($0 in replacement)
        if (skip) { printf "%s", replacement[$0]; used[$0] = 1 }
      }
      !skip { print }
      END {
        for (section in replacement)
          if (!(section in used)) printf "\n%s", replacement[section]
      }
    ' ${pagingConfig} "$global_config" > "$paging_temp"
    ${pkgs.coreutils}/bin/mv "$paging_temp" "$global_config"
    ${lib.concatMapStringsSep "\n" (name: ''
      target="$config_root/fcitx5/${name}"
      if [ ! -e "$target.before-ui-settings" ]; then
        ${pkgs.coreutils}/bin/cp -p "$target" "$target.before-ui-settings"
      fi
      config_temp="$(${pkgs.coreutils}/bin/mktemp "$target.XXXXXXXX")"
      ${pkgs.gawk}/bin/awk -F= '
        function appendMissing( key) {
          for (key in settings) { print settings[key]; delete settings[key] }
        }
        NR == FNR { if (NF >= 2) settings[$1] = $0; next }
        /^\[/ { appendMissing(); inSection = 1 }
        !inSection && $1 in settings {
          print settings[$1]; delete settings[$1]; next
        }
        { print }
        END { appendMissing() }
      ' ${configFiles.${name}} "$target" > "$config_temp"
      ${pkgs.coreutils}/bin/mv "$config_temp" "$target"
    '') [ "conf/classicui.conf" "conf/pinyin.conf" "conf/quickphrase.conf" "conf/punctuation.conf" ]}
    echo "Applied emoji menu, Chinese punctuation, OriLight and Kai/Times fonts. Starting Fcitx5."
    ${fcitx5}/bin/fcitx5 -d >"$cache_root/fcitx5.log" 2>&1 </dev/null
    # Only acknowledge this configuration after the daemon owns its D-Bus name.
    for attempt in $(${pkgs.coreutils}/bin/seq 1 50); do
      if ${fcitx5}/bin/fcitx5-remote >/dev/null 2>&1; then
        printf '%s\n' "$0" > "$config_root/fcitx5/.nix-applied-version"
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    echo "Fcitx5 did not become ready; see $cache_root/fcitx5.log" >&2
    exit 1
  '';
  # Export shell variables so a parent shell can compose this application.
  sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };
in
pkgs.mkShell (sessionVariables // {
  packages = [ launcher configtool applySettings firefoxLauncher edgeLauncher chromeLauncher fcitx5 ];

  passthru = { inherit fcitx5 addons configFiles launcher configtool applySettings fontConfig emojiFile sogouDictionary sessionVariables stopServicesOnExit; };

  shellHook = ''
    nix_fcitx5_preexisting=0
    nix_fcitx5_owned_pids=""
    if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x 'fcitx5|\.fcitx5-wrapped' >/dev/null; then
      nix_fcitx5_preexisting=1
    fi

    if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "No graphical session detected; Fcitx5 was not started."
    elif ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x fcitx >/dev/null; then
      echo "Fcitx 4/Sogou is still running. Exit it first, then run: fcitx5-nix -d"
    elif ! ${pkgs.gnugrep}/bin/grep -Fxq ${lib.escapeShellArg "${applySettings}/bin/fcitx5-nix-apply"} \
      "''${XDG_CONFIG_HOME:-$HOME/.config}/nix-fcitx5/fcitx5/.nix-applied-version" 2>/dev/null; then
      echo "New Fcitx5 configuration detected; applying automatically."
      if ! ${applySettings}/bin/fcitx5-nix-apply; then
        echo "Automatic apply failed; close the config window and retry fcitx5-nix-apply."
      fi
    elif ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x 'fcitx5|\.fcitx5-wrapped' >/dev/null; then
      echo "Fcitx5 is already running; keeping the existing instance."
    else
      fcitx5_log_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-fcitx5"
      ${pkgs.coreutils}/bin/mkdir -p "$fcitx5_log_dir"
      if fcitx5-nix -d >"$fcitx5_log_dir/fcitx5.log" 2>&1 </dev/null; then
        echo "Fcitx5 started in the background; ${if stopServicesOnExit then "it stops when this shell exits." else "it continues running after this shell exits."}"
      else
        echo "Fcitx5 failed to start; see $fcitx5_log_dir/fcitx5.log"
      fi
    fi
    ${pkgs.lib.optionalString stopServicesOnExit ''
      if [ "$nix_fcitx5_preexisting" = 0 ]; then
        nix_fcitx5_owned_pids="$(${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x 'fcitx5|\.fcitx5-wrapped' || true)"
      fi
      nix_fcitx5_cleanup() {
        local pid
        for pid in $nix_fcitx5_owned_pids; do
          # Target only the daemon recorded at entry, not an unrelated service.
          if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x 'fcitx5|\.fcitx5-wrapped' | ${pkgs.gnugrep}/bin/grep -qx "$pid"; then
            kill -TERM "$pid" 2>/dev/null || true
          fi
        done
      }
      trap nix_fcitx5_cleanup EXIT
      echo "Exit cleanup enabled: this shell's Fcitx5 stops on exit."
    ''}
    echo "GUI settings: fcitx5-configtool"
    echo "Configuration updates apply automatically; force reapply: fcitx5-nix-apply"
    echo "Stop Fcitx5: fcitx5-remote -e"
    echo "English by default; Shift toggles Pinyin; in Pinyin type /emoji to browse emoji."
  '';
})

{ lib, pkgs, sources, ... }:

let
  proxyUrl = "http://127.0.0.1:7897";
  noProxy = "localhost,127.0.0.1,192.168.0.0/16";
in
{
  # 登录环境变量由 Home Manager 统一生成到 hm-session-vars.sh。
  home.sessionVariables = {
    http_proxy = proxyUrl;
    HTTP_PROXY = proxyUrl;
    https_proxy = proxyUrl;
    HTTPS_PROXY = proxyUrl;
    no_proxy = noProxy;
    NO_PROXY = noProxy;

    HISTTIMEFORMAT = "%F %T ";
    VISUAL = "vim";
    EDITOR = "vim";
    LESS = "-IR";
    NIXPKGS_ALLOW_UNFREE = "1";

    # 无 Flake：nixpkgs 和 Home Manager 都使用 npins 固定的源码。
    NIX_PATH = "nixpkgs=${sources.nixpkgs}:home-manager=${sources.home-manager}";
  };

  home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "$HOME/.local/share/pi-node/current/bin"
    "$HOME/.costrict/bin"
    "/usr/local/go/bin"
  ];

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoreboth" ];
    historyFile = "$HOME/.bash_history";
    historyFileSize = 5000;
    historySize = 5000;

    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      ll = "ls -lhF";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      mkdirp = "mkdir -pv";

      rv32gcc = "riscv64-linux-gnu-gcc -march=rv32g -mabi=ilp32";
      rv64gcc = "riscv64-linux-gnu-gcc";
      beijing = "cat /home/happy_grass/work/beijing_serve/readme.md";
      beijing_vpn = "univpn & beijing";
      clash = "clash-verge";
      claude-danger = "claude --allow-dangerously-skip-permissions";
      claude-history = "claude --resume";
      codex-history = "codex resume";
      drawio-svg = "drawio -x -f svg";
      goldendict = ''QT_XCB_GL_INTEGRATION=none QT_QUICK_BACKEND=software QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu" goldendict'';
      hms = "home-manager switch";
    };

    initExtra = lib.mkBefore ''
      # 代理开关只影响当前终端。
      proxy_on() {
        export http_proxy=${lib.escapeShellArg proxyUrl}
        export HTTP_PROXY="$http_proxy"
        export https_proxy=${lib.escapeShellArg proxyUrl}
        export HTTPS_PROXY="$https_proxy"
        export no_proxy=${lib.escapeShellArg noProxy}
        export NO_PROXY="$no_proxy"
      }

      proxy_off() {
        unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY no_proxy NO_PROXY
      }

      proxy_status() {
        if [[ -n "''${http_proxy:-}" || -n "''${https_proxy:-}" ]]; then
          printf 'proxy enabled: http=%s https=%s no_proxy=%s\n' \
            "''${http_proxy:-}" "''${https_proxy:-}" "''${no_proxy:-}"
        else
          printf '%s\n' 'proxy disabled'
        fi
      }

      # 每次显示提示符前同步历史，保证多个终端和 fzf Ctrl-R 可见。
      __history_sync() {
        builtin history -a
        builtin history -n
      }
      case $(declare -p PROMPT_COMMAND 2>/dev/null) in
        "declare -a"*)
          if [[ " ''${PROMPT_COMMAND[*]} " != *" __history_sync "* ]]; then
            PROMPT_COMMAND+=(__history_sync)
          fi
          ;;
        *)
          case ";''${PROMPT_COMMAND//[[:space:]]/};" in
            *";__history_sync;"*) ;;
            *) PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }__history_sync" ;;
          esac
          ;;
      esac

      shopt -s histappend checkwinsize

      if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(${pkgs.coreutils}/bin/dircolors -b "$HOME/.dircolors")"
      else
        eval "$(${pkgs.coreutils}/bin/dircolors -b)"
      fi

      if [[ -x /usr/bin/lesspipe ]]; then
        eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"
      fi

      bind 'set completion-ignore-case on'
      bind 'set menu-complete-display-prefix on'
      bind 'set colored-stats on'
      bind 'set mark-symlinked-directories on'

      __command_alert() {
        local command_status=$?
        local icon=error
        if (( command_status == 0 )); then
          icon=terminal
        fi
        notify-send --urgency=low -i "$icon" \
          "$(builtin history | tail -n1 | sed -e 's/^[[:space:]]*[0-9]\+[[:space:]]*//;s/[;&|][[:space:]]*alert$//')"
      }
      alias alert='__command_alert'

      # 保留原有的 cd 后目录预览行为。
      cd() {
        builtin cd "$@" && ls -a --color=auto -F
      }

      # Conda 仍由其安装目录提供，只在文件存在时加载。
      if [[ -r "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
      fi

      # Starship 初始化前注册终端标题更新函数。
      __update_terminal_title() {
        case "''${TERM-}" in
          xterm*|rxvt*) printf '\033]0;%s@%s: %s\007' "$USER" "''${HOSTNAME%%.*}" "$PWD" ;;
        esac
      }
      starship_precmd_user_func=__update_terminal_title
    '';
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
    config.global = {
      warn_timeout = "0s";
      hide_env_diff = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      add_newline = false;
      format = "$cmd_duration$username@$hostname:$directory$character";
      cmd_duration = {
        min_time = 0;
        show_milliseconds = true;
        format = "[Time Taken $duration ]($style)";
        style = "bold yellow";
      };
      username = {
        show_always = true;
        format = "[$user]($style)";
        style_user = "bold green";
        style_root = "bold green";
      };
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style)";
        style = "bold green";
      };
      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        format = "[$path]($style)";
        style = "bold blue";
      };
      character = {
        success_symbol = ''[\$](none)'';
        error_symbol = ''[\$](none)'';
      };
    };
  };
}

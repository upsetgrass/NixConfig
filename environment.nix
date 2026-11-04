{
  pkgs ? import (import ./npins).nixpkgs { config.allowUnfree = true; },
  nixpkgsPath ? pkgs.path,
  enableProxy ? true,
  proxyUrl ? "http://127.0.0.1:7897",
  noProxy ? "localhost,127.0.0.1,192.168.0.0/16",
}:

let
  inherit (pkgs) lib;
  proxyVariables = {
    http_proxy = proxyUrl;
    HTTP_PROXY = proxyUrl;
    https_proxy = proxyUrl;
    HTTPS_PROXY = proxyUrl;
    no_proxy = noProxy;
    NO_PROXY = noProxy;
  };

  # Enable nix-direnv without replacing an existing user direnvrc.
  direnvConfig = pkgs.writeTextDir "direnv/direnvrc" ''
    if [[ -r "$HOME/.config/direnv/direnvrc" ]]; then
      source "$HOME/.config/direnv/direnvrc"
    fi
    source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
  '';
in
{
  # 代理环境变量：沿用 ~/.bashrc 中的本地代理端口，同时提供大小写版本，
  # 兼容只识别其中一种命名方式的工具。enableProxy=false 时不写入代理。
  sessionVariables = lib.optionalAttrs enableProxy proxyVariables // {
    # 通用终端变量：显示历史时间，统一编辑器，并让 less 支持忽略大小写
    # 搜索及 ANSI 颜色，避免帮助页中的颜色转义被直接打印。
    HISTTIMEFORMAT = "%F %T ";
    VISUAL = "vim";
    EDITOR = "vim";
    LESS = "-IR";

    # 允许 nixpkgs 中标记为 unfree 的软件参与求值和构建。
    NIXPKGS_ALLOW_UNFREE = "1";

    # direnv 会从这里加载用户配置和 nix-direnv。
    DIRENV_CONFIG = "${direnvConfig}/direnv";
  };

  shellHook = ''
    # 代理开关：只修改当前 shell，不写入系统或 ~/.bashrc。
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

    # Explicitly clear inherited proxy variables when enableProxy is false.
    ${if enableProxy then "proxy_on" else "proxy_off"}

    # nixpkgs：让后续使用 <nixpkgs> 的命令复用 npins 固定的源码版本。
    nixpkgs_path=${lib.escapeShellArg (toString nixpkgsPath)}
    case ":''${NIX_PATH-}:" in
      *":nixpkgs=$nixpkgs_path:"*) ;;
      *) export NIX_PATH="nixpkgs=$nixpkgs_path''${NIX_PATH:+:$NIX_PATH}" ;;
    esac
    unset nixpkgs_path

    # 以下设置仅适用于交互式 Bash，避免脚本或非交互命令收到 alias、bind、
    # PS1 等交互功能的影响。
    if [[ $- == *i* ]]; then
      # 颜色：加载用户自定义 dircolors（若存在），否则使用 GNU 默认颜色表。
      if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(${pkgs.coreutils}/bin/dircolors -b "$HOME/.dircolors")"
      else
        eval "$(${pkgs.coreutils}/bin/dircolors -b)"
      fi

      # 颜色别名：仅在终端输出时着色，不污染管道和重定向结果。
      alias ls='ls --color=auto'
      alias grep='grep --color=auto'
      alias fgrep='fgrep --color=auto'
      alias egrep='egrep --color=auto'

      # 文件和目录查看别名。
      alias ll='ls -lhF'
      alias la='ls -A'
      alias l='ls -CF'
      alias ..='cd ..'
      alias ...='cd ../..'
      alias ....='cd ../../..'
      alias mkdirp='mkdir -pv'

      # RISC-V 编译工具别名。
      alias rv32gcc='riscv64-linux-gnu-gcc -march=rv32g -mabi=ilp32'
      alias rv64gcc='riscv64-linux-gnu-gcc'

      # 北京服务器和 VPN 工作流别名。
      alias beijing='cat /home/happy_grass/work/beijing_serve/readme.md'
      alias beijing_vpn='univpn & beijing'

      # 开发工具和历史会话别名。
      alias clash='clash-verge'
      alias claude-danger='claude --allow-dangerously-skip-permissions'
      alias claude-history='claude --resume'
      alias codex-history='codex resume'

      # Draw.io 格式转换别名。
      alias drawio-svg='drawio -x -f svg'

      # Goldendict 使用软件渲染，规避部分 Qt/OpenGL 环境中的黑屏或崩溃。
      alias goldendict='QT_XCB_GL_INTEGRATION=none QT_QUICK_BACKEND=software QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu" goldendict'

      # 长任务完成提醒：内部函数先保存上一条命令的状态，再由 alert alias
      # 调用，避免复杂的多层引号影响 Nix 字符串解析。
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

      # lesspipe：让 less 能预处理压缩包等非纯文本文件；系统未提供时跳过。
      if [[ -x /usr/bin/lesspipe ]]; then
        eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"
      fi

      # Bash 补全：使用 nixpkgs 提供的 bash-completion，避免依赖发行版路径。
      if ! shopt -oq posix; then
        source ${pkgs.bash-completion}/share/bash-completion/bash_completion
      fi

      # Tab 补全：忽略大小写，标记文件类型和符号链接目录，并突出公共前缀。
      bind 'set completion-ignore-case on'
      bind 'set menu-complete-display-prefix on'
      bind 'set colored-stats on'
      bind 'set mark-symlinked-directories on'

      # direnv：在每次提示符刷新前自动加载或卸载当前目录的 .envrc。
      eval "$(${pkgs.direnv}/bin/direnv hook bash)"

      # 终端标题独立于 PS1 更新，因此不会被 Starship 覆盖。
      __update_terminal_title() {
        case "''${TERM-}" in
          xterm*|rxvt*) printf '\033]0;%s@%s: %s\007' "$USER" "''${HOSTNAME%%.*}" "$PWD" ;;
        esac
      }
      starship_precmd_user_func=__update_terminal_title

      # Starship 是唯一提示符实现，并负责显示命令执行时间等信息。
      eval "$(${pkgs.starship}/bin/starship init bash)"
      STARSHIP_START_TIME=
    fi
  '';
}

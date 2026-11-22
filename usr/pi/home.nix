{ lib, pkgs, ... }:

let
  pi = import ./resume-package.nix { inherit pkgs; };

  # Pi 插件（npm 包）版本固定在这里，便于换机时一条命令恢复。
  piPlugins = [
    "npm:@josephakern/pi-memory@0.3.0" # AI 记忆（MEMORY.md + topic 文件）
    "npm:pi-language-tutor@0.5.1" # 语言学习助教（提示词批改 + 助手回复双语翻译）
    "npm:@laboon85/pi-arxiv@0.1.6" # 阅读公开 arXiv 论文
    "npm:pi-web-access@0.48.0" # 网页搜索与正文提取
    "npm:pi-open-tui@0.4.6" # 定制终端界面，需要 Pi 1.5.0 或更新版本
  ];

  superpowers = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "22f0b463e7a5e579904dd6211a520321035526f7"; # v7.0.2
    hash = "sha256-rP5YsyGuPd9YSW/Fj3aukrq1bLuV+nwwQMK4JaZQgkI=";
  };
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "pi-import-codex" ''
      export PI_SESSION_MANAGER_MODULE="${pi}/lib/node_modules/pi-monorepo/dist/core/session-manager.js"
      exec ${pkgs.nodejs_24}/bin/node ${./import-codex.mjs} "$@"
    '')

    # 恢复 Pi 插件：pi 的插件清单在本机 settings.json 里（该文件含代理等
    # 本机设置，不入库），所以用这个脚本按上面的固定版本重新装一遍。
    # 用法：pi-install-plugins        （已装且版本一致的会跳过）
    (pkgs.writeShellScriptBin "pi-install-plugins" ''
      set -euo pipefail
      ${lib.concatMapStringsSep "\n" (p: "${pi}/bin/pi install ${lib.escapeShellArg p}") piPlugins}
      ${pi}/bin/pi list
    '')
  ];

  # Pi reloads models.json when /model opens and resolves !commands at request
  # time. Merge only the credential source into the user's private models.json.
  home.activation.deepseekPiAuth = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.bash}/bin/bash ${./configure-deepseek.sh} \
      ${pkgs.jq}/bin/jq ${pkgs.coreutils}/bin
  '';

  # 含密钥的 settings.json/models.json 保留为本机文件。
  # 所有 Pi 会话都遵守 Git 写操作显式授权规则（非权限沙箱）。
  home.file.".pi/agent/APPEND_SYSTEM.md".source = ./APPEND_SYSTEM.md;

  home.file.".pi/agent/keybindings.json" = {
    source = ./keybindings.json;
    force = true;
  };

  home.file.".pi/agent/extensions/plan-mode".source =
    "${pi}/lib/node_modules/pi-monorepo/examples/extensions/plan-mode";

  home.file.".pi/agent/skills/systematic-debugging".source =
    "${superpowers}/skills/systematic-debugging";

  # 经本地修改的 ub-mode：保留开发流程，不自动执行 Git 写操作。
  home.file.".pi/agent/skills/ub-mode".source = ./skills/ub-mode;

  home.file.".pi/agent/skills/memory" = {
    source = ./skills/memory;
    force = true;
  };
}

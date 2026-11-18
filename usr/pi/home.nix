{ lib, pkgs, ... }:

let
  # Pi 插件（npm 包）版本固定在这里，便于换机时一条命令恢复。
  piPlugins = [
    "npm:@josephakern/pi-memory@0.3.0" # AI 记忆（MEMORY.md + topic 文件）
    "npm:pi-language-tutor@0.5.1" # 语言学习助教（提示词批改 + 助手回复双语翻译）
  ];
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "pi-import-codex" ''
      export PI_SESSION_MANAGER_MODULE="${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/dist/core/session-manager.js"
      exec ${pkgs.nodejs_24}/bin/node ${./import-codex.mjs} "$@"
    '')

    # 恢复 Pi 插件：pi 的插件清单在本机 settings.json 里（该文件含代理等
    # 本机设置，不入库），所以用这个脚本按上面的固定版本重新装一遍。
    # 用法：pi-install-plugins        （已装且版本一致的会跳过）
    (pkgs.writeShellScriptBin "pi-install-plugins" ''
      set -euo pipefail
      ${lib.concatMapStringsSep "\n" (p: "${pkgs.pi-coding-agent}/bin/pi install ${p}") piPlugins}
      ${pkgs.pi-coding-agent}/bin/pi list
    '')
  ];

  # Pi reloads models.json when /model opens and resolves !commands at request
  # time. Merge only the credential source into the user's private models.json.
  home.activation.deepseekPiAuth = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.bash}/bin/bash ${./configure-deepseek.sh} \
      ${pkgs.jq}/bin/jq ${pkgs.coreutils}/bin
  '';

  # 含密钥的 settings.json/models.json 保留为本机文件。
  home.file.".pi/agent/keybindings.json" = {
    source = ./keybindings.json;
    force = true;
  };

  home.file.".pi/agent/skills/memory" = {
    source = ./skills/memory;
    force = true;
  };
}

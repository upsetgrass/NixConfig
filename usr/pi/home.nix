{ ... }:

{
  # 配置中可能包含 API key 的 settings.json/models.json 保留为本机文件，
  # 仓库只声明无敏感信息的键位和 memory skill。
  home.file.".pi/agent/keybindings.json" = {
    source = ./keybindings.json;
    force = true;
  };

  home.file.".pi/agent/skills/memory" = {
    source = ./skills/memory;
    force = true;
  };
}

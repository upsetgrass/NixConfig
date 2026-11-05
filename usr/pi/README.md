# Pi Home Manager 配置

Pi 和 Node.js 由 `usr/packages.nix` 安装。应用配置：

```bash
home-manager switch
pi --list-models ai901
```

Home Manager 管理：

- `~/.pi/agent/keybindings.json`
- `~/.pi/agent/skills/memory`

`auth.json`、`models.json` 和 `settings.json` 可能包含 API key、代理或本机模型，
继续保留为本机文件，不应复制进 Git 或 Nix Store。

可以通过 `/skill:memory` 显式加载 memory skill，或直接要求 Pi 记住长期信息。

# Pi

统一 Nix shell 加载 pi/default.nix，提供 Nix 管理的 Pi 与 Node.js 24。
运行 nix-shell pi/ 后，pi 命令应来自 Nix store。
Pi 版本由当前 nixpkgs 决定；本机目前为 0.80.3，与全局 npm 安装的版本不同。

中转站、模型和默认选项分别保存在 pi/models.json、pi/settings.json，
作为非敏感配置的记录。本机 Pi 已独立配置在 ~/.pi/agent/ 下；这些仓库文件
不会在启动时自动改写本机配置。迁移到新机器时，将对应字段合并到本机的
models.json、settings.json，并在本机 auth.json 中为 ai901 设置 API Key。
不要将凭据写入仓库。Pi 配置与其他应用相互独立。

进入 nix-shell 后可运行 pi --list-models ai901 检查模型。

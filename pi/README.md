# Pi

统一 Nix shell 加载 pi/default.nix，提供 Nix 管理的 Pi 与 Node.js 24。
运行 nix-shell pi/ 后，pi 命令应来自 Nix store。
Pi 版本由当前 nixpkgs 决定；本机目前为 0.80.3，与全局 npm 安装的版本不同。

中转站、模型和默认选项分别保存在 pi/models.json、pi/settings.json，
作为非敏感配置的记录。本机 Pi 已独立配置在 ~/.pi/agent/ 下；这些仓库文件
不会在启动时自动改写本机配置。迁移到新机器时，将对应字段合并到本机的
models.json、settings.json，并在本机 auth.json 中为 ai901 设置 API Key。
不要将凭据写入仓库。Pi 配置与其他应用相互独立。

快捷键记录在 pi/keybindings.json：Shift+Enter 换行、Enter 发送，
并保留 Ctrl+J 作为换行备用键。本机文件位于 ~/.pi/agent/keybindings.json。
如果终端把 Shift+Enter 和 Enter 发送成相同字节，Pi 的快捷键配置无法区分它们。
GNOME Terminal 3.44 / VTE 0.68 存在这个限制；Ctrl+J 仍可换行。
VS Code 内置终端若自定义了 Shift+Enter，应向终端发送 CSI-u 序列
\u001b[13;2u，而不是普通回车或 Alt+Enter 序列。

ai901 配置列出中转站的六个 GPT 对话模型与两个 DeepSeek 对话模型。
gpt-image-2 和 gpt-image-2.5 是图片生成模型，不作为 Pi 对话模型列出。

进入 nix-shell 后可运行 pi --list-models ai901 检查模型。

## Memory 技能

Pi 0.80.3 内置文件式持久记忆：全局索引位于 `~/.pi/agent/memory/MEMORY.md`，
项目索引位于 `<repo>/.pi/memory/MEMORY.md`。仓库内的 `skills/memory/SKILL.md`
在其上补充一套读写与清理流程（何时记录、如何去重、索引/主题文件格式、
不得写入凭据等）。

`default.nix` 的 `shellHook` 会把该技能链接到 pi 的全局技能目录：

```
~/.pi/agent/skills/memory -> <本仓库>/pi/skills/memory
```

链接指向工作树而非 Nix store 副本，修改 `SKILL.md` 后无需重建 shell。
进入 nix-shell 后可用 `/skill:memory` 显式加载，或直接说「记住 …」触发。
删除 `default.nix` 中的两行 `shellHook` 即可停用；链接本身可手动删除。

注意：项目记忆会随仓库共享，不要写入密码、令牌或 API Key。

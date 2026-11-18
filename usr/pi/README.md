# Pi Home Manager 配置

Pi 和 Node.js 由 `usr/packages.nix` 安装。应用配置：

```bash
home-manager switch
pi --list-models ai901
```

Home Manager 管理：

- `~/.pi/agent/keybindings.json`
- `~/.pi/agent/skills/memory`
- `pi-import-codex`、`pi-install-plugins` 两个命令

## 键位

`usr/pi/keybindings.json` 现在的内容：

```json
{
  "tui.input.newLine": ["ctrl+enter", "shift+enter", "ctrl+j"],
  "tui.input.submit": "enter"
}
```

- `Ctrl+Enter`、`Shift+Enter` 需要终端能上报扩展按键（Pi 用 Kitty keyboard
  protocol 区分它们）。GNOME Terminal 3.44（VTE 0.68）**做不到**：它把
  `Ctrl+Enter`/`Shift+Enter` 都当普通 `Enter` 发出，按下去还是会提交。
  想真正生效就换 Kitty / Ghostty / WezTerm / iTerm2 / Windows Terminal，
  或 VTE ≥ 0.76 的终端（新版 GNOME Console、Ptyxis 等）。
- `Ctrl+J` 在任何终端都能换行，是当前机器上最可靠的键。
- 改完 `keybindings.json` 后在 Pi 里执行 `/reload`，用 `/hotkeys` 查看生效结果。

## 插件（Pi packages）

版本固定在 `usr/pi/home.nix` 的 `piPlugins` 列表里，目前是：

| 插件 | 作用 |
|---|---|
| `npm:@josephakern/pi-memory@0.3.0` | AI 记忆：`MEMORY.md` 索引 + 按需读取的 topic 文件（本机由 `/skill:memory` 或「记住…」触发） |
| `npm:pi-language-tutor@0.5.1` | 语言学习助教：后台批改你提示词里的拼写/语法/措辞，并把助手回复双语翻译 |

Pi 的插件清单存在本机 `~/.pi/agent/settings.json` 的 `packages` 字段里（该文件
含 `httpProxy` 等本机设置，所以不入库）。换机器或重装后一条命令按固定版本恢复：

```bash
pi-install-plugins   # = pi install 上面每个包，然后 pi list
```

日常增删插件仍然用 Pi 自带命令，装完记得把版本同步进 `home.nix` 的 `piPlugins`：

```bash
pi install npm:<包名>@<版本>
pi remove npm:<包名>
pi list
```

### 去哪里找 Pi 插件

- **官方插件画廊**：<https://pi.dev/packages>（npm 包里带 `pi-package` 关键字就会被收录）
- **npm 搜索**：<https://www.npmjs.com/search?q=keywords:pi-package>，或 
  `npm search keywords:pi-package`
- **GitHub**：搜 topic [`pi-package`](https://github.com/topics/pi-package)，也可以直接
  `pi install git:github.com/<owner>/<repo>@<tag>`
- **Pi 官方文档**：`docs/packages.md`（包结构、`pi` manifest、资源过滤）

装第三方包前先看源码：包里的扩展代码会执行，skill 还能让模型跑命令。

## 会话选择器排序

`/resume`（或 `pi --resume`）默认按 **Threaded**（按 fork 家族分组）排序。
Pi 1.4.0/1.5.2 **没有**可以写进配置的排序项，排序状态也不持久化，
打开选择器后按：

- `Ctrl+S` 循环切换 `Threaded` → `Recent`（按时间，最近在前）→ `Relevance`
- `Ctrl+P` 显示/隐藏路径，`Ctrl+N` 只看已命名会话

想要「一打开就按时间排」，目前只能在选择器里按一次 `Ctrl+S`。

`auth.json`、`models.json` 和 `settings.json` 可能包含 API key、代理或本机模型，
继续保留为本机文件，不应复制进 Git 或 Nix Store。Pi 的 Home Manager activation
只向本机 `models.json` 的 `deepseek` provider 写入读取密钥文件的命令。

可以通过 `/skill:memory` 显式加载 memory skill，或直接要求 Pi 记住长期信息。

## DeepSeek 备用入口

在 DeepSeek 开放平台创建 API Key 后，将它单独写入
`~/.config/deepseek/api-key`：

```bash
install -d -m 700 ~/.config/deepseek
umask 077
vim ~/.config/deepseek/api-key
chmod 600 ~/.config/deepseek/api-key
home-manager switch
```

文件里只写一行原始 API Key，不加引号或变量名。Pi 请求时执行
`~/.pi/agent/models.json` 中的读取命令，因此修改 Key 后下一次请求即可生效。

AI901 的 GPT 模型出现 502 `Upstream service temporarily unavailable` 时，
在 Pi 当前会话内用 `/model` 选择 `deepseek/deepseek-flash`。不要按 `Ctrl+S`
保存默认模型，除非确实要改变新会话的默认 provider。

## 导入 Codex 历史

`pi-import-codex` 扫描 `~/.codex` 与 `~/.codex-deepseek` 的活动和归档会话，
读取 JSONL 历史并以 SQLite 索引补全缺少的最终事件，按原工作目录生成独立 Pi 会话：

```bash
pi-import-codex --dry-run
pi-import-codex --apply
```

在原项目目录启动 Pi，输入 `/resume`，即可选择导入的会话。
名称优先使用 Codex 会话名称索引中的最新标题，其次是显式名称和初始标题。
Pi 的 `/resume` 中也可以按 Tab 切到所有目录。

同步现有导入记录的标题，并将同一 fork 家族的旧副本移出列表：

```bash
pi-import-codex --reconcile --dry-run
pi-import-codex --reconcile --apply
```

同一项目内按明确的 `forked_from_id` 关系分组，保留 Codex 最近更新的一份，
不会仅凭同名合并独立会话。旧 Pi 副本移到 `~/.pi/agent/imports/codex/backups/`，
保留全部内容；操作清单见同目录的 `last-reconcile.json`。
原 Codex 会话和 Pi 中继续写入的正文均不会改写。更新后重新打开 Pi 的会话选择器。

提问、助手反馈、可读取的思考文本、工具参数/输出/文件补丁和压缩摘要都会保留。
工具历史转换成静态文本，不会重新执行；原始系统指令和加密思考数据不导入。
已有图片数据或仍存在的本机图片会嵌入，丢失的图片只保留路径/引用。
原压缩点之前的消息仍可翻阅，继续聊天的上下文从对应摘要恢复；
回滚操作会保留为历史提示，不还原 Codex 的交互运行状态。
不复制 Codex 的计费统计，也不修改项目文件或原 Codex 历史。

清单和校验报告保存在 `~/.pi/agent/imports/codex/manifest.json` 与
`last-report.json`，权限为 `600`。重复运行会跳过已导入线程，
不会覆盖已在 Pi 继续的内容；这是一份导入时的快照，不做双向同步。
历史内容和报告不进入 Git 或 Nix Store。

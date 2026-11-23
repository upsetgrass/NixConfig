# Pi Home Manager 配置

Pi 和 Node.js 由 `usr/packages.nix` 安装。Pi 1.5.2 在 `resume-package.nix`
中单独固定，不改变其他软件使用的 Nixpkgs 版本。应用配置：

```bash
home-manager switch
pi --list-models ai901
```

Home Manager 管理：

- `~/.pi/agent/keybindings.json`
- `~/.pi/agent/extensions/plan-mode`
- `~/.pi/agent/APPEND_SYSTEM.md`（所有会话的 Git 写操作显式授权规则）
- `~/.pi/agent/skills/memory`、`~/.pi/agent/skills/systematic-debugging`、`~/.pi/agent/skills/ub-mode`
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
- `/hotkeys` 的 `Action` 列和内置动作说明由 `localize-hotkeys.mjs` 翻译为中文；
  快捷键和扩展提供的说明保持原样。修改翻译后需重新构建并启动 Pi。

## 计划模式

Home Manager 自动加载 Pi 包随附的官方 Plan Mode 扩展，无需通过 npm 安装。
运行 `home-manager switch` 后，已打开的会话可用 `/reload` 加载扩展。
新会话默认不开启计划模式；用 `/plan` 在当前会话中开启或关闭。

## 插件（Pi packages）

版本固定在 `usr/pi/home.nix` 的 `piPlugins` 列表里，目前是：

| 插件 | 作用 |
|---|---|
| `npm:@josephakern/pi-memory@0.3.0` | AI 记忆：`MEMORY.md` 索引 + 按需读取的 topic 文件（本机由 `/skill:memory` 或「记住…」触发） |
| `npm:pi-language-tutor@0.5.1` | 语言学习助教：后台批改你提示词里的拼写/语法/措辞，并把助手回复双语翻译 |
| `npm:@laboon85/pi-arxiv@0.1.6` | 阅读公开 arXiv 论文；LaTeX 转 Markdown 需要 `pandoc`，PDF 页文本和图片功能可用 Poppler |
| `npm:pi-web-access@0.48.0` | 网页搜索与正文提取 |
| `npm:pi-open-tui@0.4.6` | 定制终端界面，用 `/open-tui` 打开设置；图标缺字时在 Appearance → Icons 选 `unicode` |

Pi 的插件清单存在本机 `~/.pi/agent/settings.json` 的 `packages` 字段里（该文件含 `httpProxy` 等本机设置，所以不入库）。
新增 npm 包时，在 `piPlugins` 的中括号内加一行 `"npm:包名@版本"` 或
`"npm:@组织/包名@版本"`（行尾不加逗号），再执行：

```bash
home-manager switch
pi-install-plugins
```

这个脚本只安装清单中的包，不会卸载清单之外的包。要移除 npm 包，先从
`piPlugins` 删除对应项，再用 `pi remove npm:包名` 更新 Pi 本机的配置并卸载；
如果原来是通过 `pi install -l` 安装的，就在相同项目里用 `pi remove -l npm:包名`。
用 `pi list` 检查结果，已打开的会话执行 `/reload` 加载变更。

纯 skill 不需要走 npm 安装脚本。例如 `systematic-debugging` 固定到上游
Superpowers 的源码版本，由 Home Manager 链接到用户 skills 目录，只加载这一个
skill。启用后可用 `/skill:systematic-debugging` 显式调用。

`ub-mode` 是从 unclebob/ub-mode 的提交
`3da62bf3fcfd2034de41f30d920d2739e566171f` 本地改写的独立 skill，
其内容在 `usr/pi/skills/ub-mode/SKILL.md`，按上游 MIT 许可保留 LICENSE。
只安装这个 skill，不加入 npm 的 `piPlugins` 列表。运行 `home-manager switch`
后，在已有会话执行 `/reload`，用 `/skill:ub-mode` 显式调用。
本地版本保留「先做出来、再做对、按良好实践交付」的流程，但不自动进行
`git add/commit/push` 或其他 Git 写操作；只有用户明确要求**执行某一项具体操作**
时才可执行。询问“该如何做”只提供说明，不执行命令；获准提交不等于获准推送。
全局 `APPEND_SYSTEM.md` 同样规定了此行为，以覆盖不加载该 skill 的任务。
这些是提示词约束，不是 Git 写入的技术性拦截或安全沙箱。

### 去哪里找 Pi 插件

- **官方插件画廊**：<https://pi.dev/packages>（npm 包里带 `pi-package` 关键字就会被收录）
- **npm 搜索**：<https://www.npmjs.com/search?q=keywords:pi-package>，或 
  `npm search keywords:pi-package`
- **GitHub**：搜 topic [`pi-package`](https://github.com/topics/pi-package)，也可以直接
  `pi install git:github.com/<owner>/<repo>@<tag>`
- **Pi 官方文档**：`docs/packages.md`（包结构、`pi` manifest、资源过滤）

装第三方包前先看源码：包里的扩展代码会执行，skill 还能让模型跑命令。

## 会话选择器

`resume-package.nix` 让 `/resume` 和 `pi --resume` 的列表随终端高度变化，
不再固定为最多 10 条。原有的搜索、排序、翻页和目录切换不变。
修改后运行 `home-manager switch`，再启动新的 Pi 进程。升级 Pi 时如果
构建提示找不到选择器，请检查上游实现并更新或移除本地补丁。

`/resume`（或 `pi --resume`）默认按 **Threaded**（按 fork 家族分组）排序。
Pi 1.4.0/1.5.2 **没有**可以写进配置的排序项，排序状态也不持久化，
打开选择器后按：

- `Ctrl+S` 循环切换 `Threaded` → `Recent`（按时间，最近在前）→ `Relevance`
- `Ctrl+P` 显示/隐藏路径，`Ctrl+N` 只看已命名会话

想要「一打开就按时间排」，目前只能在选择器里按一次 `Ctrl+S`。

`auth.json`、`models.json` 和 `settings.json` 可能包含 API key、代理或本机模型，
继续保留为本机文件，不应复制进 Git 或 Nix Store。Home Manager activation
将 `usr/pi/models.json` 的公开模型清单合并到本机 `models.json`，保留已有
provider、凭据、连接设置和清单之外的模型；同 ID 的模型由仓库声明的元数据
覆盖，其他本机字段保留。随后写入 DeepSeek 的密钥读取命令。

## 中转站模型清单

`usr/pi/models.json` 管理 AI901 的公开模型配置，不包含 API Key。
运行 `home-manager switch` 后，已有会话重新打开 `/model` 即可加载，
不改变当前会话模型或新会话默认模型。

已加入通过 AI901 `/v1/models` 确认存在的 `gpt-6.2-astra`、`gpt-6.2-sol`、
`claude-opus-5-5` 和 `claude-haiku-4-5-20251001`。当前按类别保留的强/快候选为：

| 类别 | 偏能力 | 偏速度 | 选择依据 |
|---|---|---|---|
| Anthropic | `claude-opus-5-5` | `claude-haiku-4-5-20251001` | 按 Opus / Haiku 产品档位推断；未做实测基准 |
| OpenAI | `gpt-6.2-astra` | `gpt-6.2-sol` | 按 Astra / Sol 名称推断；中转站没有提供速度或能力元数据 |
| DeepSeek | `deepseek-v4.1-flash` | `deepseek-flash` | 保留现有 V4.1 / Flash 条目；速度和效果尚未实测 |

以上只是按型号命名和家族定位做的候选，不代表已验证的跑分或延迟。
截图里的 GPT Image 与 Seedance 属于图像/视频生成，不加入这份用于对话的
OpenAI Responses 模型清单。新增的 Claude 与 GPT-6.2 条目没有服务端能力元数据，
因此沿用 Pi 默认上下文、输出上限和文本输入配置；`reasoning: true` 也仅表示
允许 Pi 提供推理档位，具体是否支持取决于中转站。

以后中转站新增模型，在 `providers.ai901.models` 中加入对应条目，再运行
`home-manager switch`。Pi 不会自动发现自定义中转站的新模型，
`pi update --models` 只更新 Pi 自带的模型目录。不要把本机含密钥的
`~/.pi/agent/models.json` 复制回仓库。

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

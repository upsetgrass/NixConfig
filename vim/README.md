# 独立 Neovim 环境

运行：

```bash
nix-shell ~/nix/vim/vim.nix
vim 文件名
```

这个 shell 中的 `vim` 是 Nix 构建的 Neovim。它使用临时的 XDG 配置、数据、状态和缓存目录，不读取外部 Vim/Neovim 配置；退出后临时目录会清理。`<leader>` 默认为空格键。

## 快捷键

| 按键 | 用途 |
| --- | --- |
| `<leader>e` | 打开/关闭项目目录树 |
| `<leader>r` | 打开/关闭右侧文件大纲树 |
| `Ctrl-w w` | 切换目录、正文、大纲 |
| `<leader>f` | fzf 查找项目文件 |
| `<leader>g` | fzf 搜索项目文本 |
| `<leader>fc` | 切换 fzf 文件名匹配的大小写模式 |
| `<leader>tt` | 打开/关闭浮动终端 |
| `<leader>h` | 打开/关闭 `~/nix/vim/help.md` 帮助浮窗 |
| 项目树 `a` | 新增文件或目录（目录名以 `/` 结尾） |
| 项目树 `r` | 重命名选中文件或目录 |
| 项目树 `d` / `D` / `Delete` | 确认后移到系统回收站，不永久删除 |

## 项目目录树

目录名现在会追加 `/`，与文件仅靠颜色区分的问题因此也得到改善。树内：`Enter` 打开文件，`a` 新增文件或目录，`r` 重命名，`d` 或 `D` 移到回收站，`?` 查看完整帮助。

删除使用 `gio trash`，不是永久删除；树内的 `d`、`D`、`Delete` 和批量书签删除 `bd` 都已改成回收站操作，并保留确认提示。恢复文件请在桌面回收站中选择“还原”；nvim-tree 没有文件系统操作的编辑器级撤销栈。普通文本编辑仍可用 `u`/`Ctrl-r` 撤销和重做。

从树中打开文件后，可按 `<leader>ef` 直接回到树，也可使用标准窗口切换 `Ctrl-w h`。再次按 `<leader>e` 则会关闭树。

## fzf 大小写

默认忽略大小写：输入 `readme` 可以匹配 `README.md`。按 `<leader>fc` 可切换文件名选择器的匹配模式；状态栏会提示当前模式。项目文本搜索默认也忽略大小写。

## 文件大纲、类和方法

大纲侧栏通过 `<leader>r` 打开或关闭，位于右侧；项目文件树通过 `<leader>e` 打开或关闭，位于左侧。正文居中。大纲优先使用 LSP 的文档符号，因此能显示类、接口、结构体、枚举、方法、函数、字段等层级；没有可用 LSP 时，会使用 Treesitter provider 从语法树中提取结构。Markdown 使用标题层级作为大纲。

`<leader>o` 只切换已打开的大纲与正文的焦点；`<leader>of` 和 `<leader>oc` 可以直接聚焦指定区域。在大纲中按 `Enter` 跳到符号。大纲图标使用 `[C]`、`[f]` 等纯文本类型标记，避免终端字体缺少 Nerd Font 时出现乱码。默认只展开前两层，`Tab` 可展开/折叠当前节点。

在任意窗格输入 `:q` 或 `:qw` 都会退出整个 Neovim，而不必逐个关闭两侧树。`:q` 遇到未保存文件会阻止退出；`:qw` 会先保存所有已修改文件。`:q!` 和 `:qw!` 可强制退出。

Scala 已加入 Treesitter parser 和 Metals LSP。即使项目没有成功导入，右侧大纲也会通过 Treesitter 显示 `trait`、`object`、`class`、`def` 等结构；进入包含 `build.sbt`、`build.sc` 或 `pom.xml` 的项目后，Metals 才能进一步提供跨文件类关系、定义跳转和引用查找。第一次启动 Metals 可能需要下载项目依赖。

大纲展示的是**当前文件内**的符号层级，不是整个项目的继承关系图。查跨文件父类或调用点请用 `Ctrl-Enter` / `Ctrl-Space`；`:LspInfo` 可确认 Metals 是否已连接。

当前还加入了 Go、Java、C#、PHP、Ruby、Scala、Zig、TSX 等常见语言的 Treesitter parser，并启用了 Go 的 `gopls`。

## 语法高亮语言

已启用 Treesitter 高亮：Markdown、C、C++、Python、Scala/Chisel、JSON、Lua、Verilog/SystemVerilog，以及 Go、Java、C#、PHP、Ruby、Rust、TypeScript/TSX、Nix、YAML、TOML、HTML、CSS 等。`.v`、`.sv`、`.svh` 会自动按 SystemVerilog 解析；Chisel 源码按 Scala 解析。

如果某个文件没有高亮，可用 `:set filetype?` 查看文件类型，再用 `:TSInstallInfo`（本配置 parser 已由 Nix 固定安装）或 `:Inspect` 检查 Treesitter 状态。

## 大纲标记含义

右侧大纲中的方括号是符号类型，不是错误信息：`[C]` 类（Class），`[I]` 接口（Interface），`[S]` 结构体（Struct），`[E]` 枚举（Enum），`[m]` 方法（Method），`[f]` 函数（Function），`[c]` 构造函数（Constructor），`[v]` 变量/字段（Variable/Field），`[k]` 常量（Constant），`[p]` 属性（Property），`[M]` 模块（Module），`[T]` 类型别名（TypeAlias）。前面的 `>`/`v` 表示折叠状态，`|` 和 `+` 是层级引导线。

## 项目恢复

退出时会按项目根目录保存一个独立状态文件，下一次从该项目启动时恢复：上次打开的文件、缓冲区、光标和滚动位置、当前焦点、左侧文件树是否打开、右侧大纲是否打开，以及文件树展开的目录和滚动位置。状态保存在 `~/nix/vim/state/sessions`，不使用外部 Neovim 配置或插件。

推荐先进入项目目录再运行 `vim`，例如 `cd ~/work/Nanhu-V5-guanchuan && vim`。这样会恢复上次的中央文件、左侧目录树和右侧大纲。若使用 `vim other.scala` 明确指定文件，则该文件优先；退出后仍会更新项目会话。

如果不希望恢复某个项目，删除对应的状态文件即可；状态文件名是项目路径的 SHA-256 值。以具体文件启动时仍以命令行指定的文件为准，不会被旧会话覆盖。

`~/nix/vim/state/` 只保存这套独立 Neovim 的项目会话 JSON：打开的文件、光标/滚动位置、左右侧栏状态和文件树展开目录。它不是插件目录，也不是项目源代码；删除对应 JSON 只会让该项目下次从默认布局启动。

## Git 辅助

Git 仓库中会显示新增、修改、删除行的标记和行号高亮，并在当前行显示 blame 信息。`[h` / `]h` 跳到上一个/下一个变更块，`<leader>gp` 预览变更，`<leader>gb` 查看当前行完整 blame。

## LSP、补全和语法

打开支持的语言文件后自动启动 LSP。普通模式下：`Ctrl-Enter` 跳转定义，`Ctrl-Space` 查找引用；另外保留 `gd`、`gr`、`gD`、`gi`、`K` 和 `<leader>rn`。插入模式补全使用 `↑`/`↓` 选择、`Tab` 确认、`Ctrl-Space` 手动弹出、`Ctrl-e` 关闭。

Treesitter 负责语法高亮；`:LspInfo` 查看 LSP 连接，`:Inspect` 查看 Treesitter 节点。

## Markdown 图片

`snacks.nvim` 已启用图片文档功能。为避免部分终端对行内占位符支持不完整导致布局变形，当前使用浮动预览而不是强制把图片嵌入文本行。把光标放在 `![说明](图片路径)` 上按 `<leader>i` 预览；`:checkhealth snacks` 可检查终端和图片依赖。图片路径相对于 Markdown 文件目录。

## 终端和其他命令

按 `<leader>tt` 可在不退出 Neovim 的情况下打开 shell；在终端窗口中直接输入任意命令。按 `Esc` 回到普通模式，再按 `q` 关闭窗口。`:ToggleTerm` 也可以执行同样的操作。

## LSP 服务器

当前包含 Nix、Lua、Shell、C/C++、Python、Rust、Markdown、HTML、CSS 和 TypeScript/JavaScript 的服务器。部分服务器需要项目根目录、构建数据库或项目依赖才能提供完整跳转结果。

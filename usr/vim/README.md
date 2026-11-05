# 独立 Neovim 环境

运行：

```bash
home-manager switch
vim 文件名
```

这个 shell 中的 `vim` 是 Nix 构建的 Neovim。它使用临时的 XDG 配置、数据、状态和缓存目录，不读取外部 Vim/Neovim 配置；退出后临时目录会清理。`<leader>` 默认为空格键。

## 快捷键

| 按键 | 用途 |
| --- | --- |
| `<leader>e` | 打开/关闭项目目录树 |
| `<leader>r` | 打开/关闭右侧文件大纲树 |
| `Ctrl-w w` | 切换目录、正文、大纲 |
| `<leader>f` | 在整个 Vim 底部的全宽窗口中用 fzf 查找项目文件 |
| `<leader>g` | 在整个 Vim 底部的全宽窗口中用 fzf 搜索项目文本 |
| `<leader>fc` | 切换 fzf 文件名匹配的大小写模式 |
| `<leader>tt` | 打开/关闭浮动终端 |
| `:shell` | 打开交互式终端分屏；在 shell 中输入 `exit` 返回 |
| 终端内 `Ctrl-]` | 返回外层 Neovim 普通模式；再按 `<leader>tt` 关闭终端 |
| `<leader>h` | 打开/关闭 `~/work/NixConfig/usr/vim/help.md` 帮助浮窗 |
| `<leader>mp` | 打开/关闭当前 Markdown 文件的浏览器实时预览 |
| `<leader>cv` | 复制当前文件绝对路径到系统剪贴板和 Vim 默认寄存器 |
| Visual 模式 `Ctrl-Shift-C` / `<leader>y` | 复制选中内容到系统剪贴板，可粘贴到外部程序 |
| `<leader>l` | 打开/关闭当前文件的 Git blame 列表 |
| `gd` / `Ctrl-Enter` | 跳转到定义 |
| `gr` / `Ctrl-Space` | 查找引用（包括调用位置） |
| `<leader>ci` / `<leader>co` | 查看谁调用当前函数 / 当前函数调用谁（需要服务器支持） |
| `Ctrl-o` | 跳转后返回之前的位置 |
| 项目树 `a` | 新增文件或目录（目录名以 `/` 结尾） |
| 项目树 `<leader>o` | 左右分屏打开选中文件（垂直分屏） |
| 项目树 `<leader>p` | 上下分屏打开选中文件（水平分屏） |
| 项目树 `r` | 重命名选中文件或目录 |
| 项目树 `d` / `D` / `Delete` | 确认后移到系统回收站，不永久删除 |

`Ctrl-w` 只在普通模式中保留为窗口命令前缀。插入、可视、选择、操作等待、命令行和终端输入模式中的 `Ctrl-w` 均已禁用，因此插入模式下误按不会再删除前一个单词。需要切换窗口时先按 `Esc` 回到普通模式，再使用 `Ctrl-w w` 或 `Ctrl-w h/j/k/l`；终端输入模式先按 `Ctrl-]`（或 `Ctrl-\` 后按 `Ctrl-n`）回到普通模式。

## 项目目录树

状态栏右侧的 `行号,列号` 按字符计数：一个中文或英文字符都算一列，不使用字节列号或屏幕显示宽度。
正文文件路径显示在窗口顶部，底部保留行列号和阅读进度；项目树和终端的名称仍显示在底部。

目录名现在会追加 `/`，与文件仅靠颜色区分的问题因此也得到改善。树内：`Enter` 打开文件，`a` 新增文件或目录，`r` 重命名，`d` 或 `D` 移到回收站，`?` 查看完整帮助。

项目树默认显示被 `.gitignore` 忽略的文件和目录，例如 `build/`。在项目树中按大写 `I` 可临时切换显示/隐藏 Git 忽略内容，按 `R` 手动刷新。

项目树只使用三类 Git 状态颜色：白色表示干净或被 `.gitignore` 忽略，蓝色表示未跟踪，绿色表示任意尚未提交的已跟踪变更（修改、暂存、重命名、删除或冲突）。普通目录也保持白色，不再使用主题默认的青色；文件夹会继承内部文件状态。树中不会额外显示 `?`、`M`、`S` 等文字标记。Git 操作后项目树会在保存文件、离开终端或关闭终端时自动刷新，按 `R` 仍可手动刷新；重新聚焦 Neovim、在项目树中移动或停顿都不会触发后台重载，避免选中节点自行跳动。

大型项目的 Git 状态检测超时已从 nvim-tree 默认的 400ms 提高到 3 秒；恢复项目会话并打开目录树时也会重新应用 Git 高亮，避免树形结构恢复了但颜色全部退回白色。

删除使用 `gio trash`，不是永久删除；树内的 `d`、`D`、`Delete` 和批量书签删除 `bd` 都已改成回收站操作，并保留确认提示。恢复文件请在桌面回收站中选择“还原”；nvim-tree 没有文件系统操作的编辑器级撤销栈。普通文本编辑仍可用 `u`/`Ctrl-r` 撤销和重做。

从树中打开文件后，可按 `<leader>ef` 直接回到树，也可使用标准窗口切换 `Ctrl-w h`。再次按 `<leader>e` 则会关闭树。

## fzf 大小写

同时查看多个文件：先在正文打开一个文件，再用 `<leader>ef` 回到项目树，选中另一个文件，按 `<leader>o` 左右分屏或 `<leader>p` 上下分屏打开。用 `Ctrl-w w` 轮流切换窗口，或 `Ctrl-w h/j/k/l` 按方向切换；`:close` 关闭当前分屏，`:q` 仍会退出整个 Neovim。在项目树内 `<leader>o` 用于分屏，在正文内仍用于切换大纲焦点。

默认忽略大小写：输入 `readme` 可以匹配 `README.md`。按 `<leader>fc` 可切换文件名选择器的匹配模式；状态栏会提示当前模式。项目文本搜索默认也忽略大小写。

## 文件大纲、类和方法

大纲侧栏通过 `<leader>r` 打开或关闭，位于右侧；项目文件树通过 `<leader>e` 打开或关闭，位于左侧。正文居中。大纲优先使用 LSP 的文档符号，因此能显示类、接口、结构体、枚举、方法、函数、字段等层级；没有可用 LSP 时，会使用 Treesitter provider 从语法树中提取结构。Markdown 使用标题层级作为大纲。

`<leader>o` 只切换已打开的大纲与正文的焦点；`<leader>of` 和 `<leader>oc` 可以直接聚焦指定区域。在大纲中按 `Enter` 跳到符号。大纲图标使用 `[C]`、`[f]` 等纯文本类型标记，避免终端字体缺少 Nerd Font 时出现乱码。默认只展开前两层，`Tab` 可展开/折叠当前节点。

在任意窗格输入 `:q` 或 `:qw` 都会退出整个 Neovim，而不必逐个关闭两侧树。`:q` 遇到未保存文件会阻止退出；`:qw` 会先保存所有已修改文件。`:q!` 和 `:qw!` 可强制退出。

Scala 已加入 Treesitter parser 和 Metals LSP。即使项目没有成功导入，右侧大纲也会通过 Treesitter 显示 `trait`、`object`、`class`、`def` 等结构；进入包含 `build.sbt`、`build.sc` 或 `pom.xml` 的项目后，Metals 才能进一步提供跨文件类关系、定义跳转和引用查找。第一次启动 Metals 可能需要下载项目依赖。

大纲展示的是**当前文件内**的符号层级，不是整个项目的继承关系图。查跨文件父类或调用点请用 `Ctrl-Enter` / `Ctrl-Space`；`:LspInfo` 可确认 Metals 是否已连接。

当前还加入了 Go、Java、C#、PHP、Ruby、Scala、Zig、TSX 等常见语言的 Treesitter parser，并启用了 Go 的 `gopls`。

## 语法高亮语言

`indent-blankline.nvim` 自动显示缩进虚线，每层宽度跟随文件的缩进设置，空行也会显示引导线。Markdown、文本、YAML 等自然语言或配置文件默认使用两个空格；Scala、C/C++、Lua、Python、Rust、Go、Java、JavaScript/TypeScript、Shell、Nix、Verilog/SystemVerilog 等编程语言使用四个空格。Makefile 是特殊例外：按 `Tab` 会插入 GNU Make 命令所要求的真实 Tab 字符，并按标准宽度 8 显示，避免 `missing separator` / `缺失分隔符`。项目树、大纲和终端不显示缩进引导线。`:IBLDisable` 临时关闭，`:IBLEnable` 重新开启。

已启用 Treesitter 高亮：Markdown、C、C++、Python、Scala/Chisel、JSON、Lua、Verilog/SystemVerilog，以及 Go、Java、C#、PHP、Ruby、Rust、TypeScript/TSX、Nix、YAML、TOML、HTML、CSS 等。`.v`、`.sv`、`.svh` 会自动按 SystemVerilog 解析；Chisel 源码按 Scala 解析。

如果某个文件没有高亮，可用 `:set filetype?` 查看文件类型，再用 `:TSInstallInfo`（本配置 parser 已由 Nix 固定安装）或 `:Inspect` 检查 Treesitter 状态。

## 大纲标记含义

右侧大纲中的方括号是符号类型，不是错误信息：`[C]` 类（Class），`[I]` 接口（Interface），`[S]` 结构体（Struct），`[E]` 枚举（Enum），`[m]` 方法（Method），`[f]` 函数（Function），`[c]` 构造函数（Constructor），`[v]` 变量/字段（Variable/Field），`[k]` 常量（Constant），`[p]` 属性（Property），`[M]` 模块（Module），`[T]` 类型别名（TypeAlias）。前面的 `>`/`v` 表示折叠状态，`|` 和 `+` 是层级引导线。

## 项目恢复

退出时会按项目根目录保存一个独立状态文件，下一次从该项目启动时恢复：上次显示的代码窗口数量、左右/上下嵌套分屏布局、每个窗口打开的文件及其光标和滚动位置、后台缓冲区、当前焦点、左侧文件树是否打开、右侧大纲是否打开，以及文件树展开的目录和滚动位置。终端、fzf 和帮助浮窗属于临时界面，不会在下次启动时恢复。会话根目录在启动时锁定；打开个人帮助、终端或项目外文件不会覆盖当前项目的状态。状态保存在 `~/.local/state/nvim-nix/sessions`，不使用外部 Neovim 配置或插件。

推荐先进入项目目录再运行 `vim`，例如 `cd ~/work/Nanhu-V5-guanchuan && vim`。这样会恢复上次的中央文件、左侧目录树和右侧大纲。若使用 `vim other.scala` 明确指定文件，则该文件优先；退出后仍会更新项目会话。

为保证目录树完全按上次的展开状态恢复，切换正文文件时不会自动展开其所在目录。需要在树中定位当前文件时，按 `<leader>E`。

如果不希望恢复某个项目，删除对应的状态文件即可；状态文件名是项目路径的 SHA-256 值。以具体文件启动时仍以命令行指定的文件为准，不会被旧会话覆盖。

`~/.local/state/nvim-nix/sessions/` 只保存这套独立 Neovim 的项目会话 JSON：打开的文件、光标/滚动位置、左右侧栏状态和文件树展开目录。它不是插件目录，也不是项目源代码；删除对应 JSON 只会让该项目下次从默认布局启动。
该目录位于仓库之外；其他人部署配置后，首次退出项目时会在各自机器上自动创建并保存会话。

使用 `:w`、`<leader>w` 或其他正常保存命令时，都会在写入前删除当前文件每一行的行尾空格和 Tab。Markdown 的两个空格硬换行也会被删除。

## Git 辅助

Git 仓库中会显示新增、修改、删除行的标记和行号高亮，并在当前行显示 blame 信息。`[h` / `]h` 跳到上一个/下一个变更块，`<leader>gp` 预览变更，`<leader>gb` 查看当前行完整 blame。`<leader>l` 使用 Fugitive 打开当前文件的完整 blame 列表，再按一次关闭该列表并保留正文窗口。

## LSP、补全和语法

打开支持的语言文件后自动启动 LSP。普通模式下：`Ctrl-Enter` 跳转定义，`Ctrl-Space` 查找引用；另外保留 `gd`、`gr`、`gD`、`gi`、`K` 和 `<leader>rn`。插入模式补全使用 `↑`/`↓` 选择、`Tab` 确认、`Ctrl-Space` 手动弹出、`Ctrl-e` 关闭。

Treesitter 负责语法高亮；`:LspInfo` 查看 LSP 连接，`:Inspect` 查看 Treesitter 节点。

## Markdown 图片

`snacks.nvim` 已启用图片文档功能。为避免部分终端对行内占位符支持不完整导致布局变形，当前使用浮动预览而不是强制把图片嵌入文本行。把光标放在 `![说明](图片路径)` 上按 `<leader>i` 预览；`:checkhealth snacks` 可检查终端和图片依赖。图片路径相对于 Markdown 文件目录。

## Markdown 整篇预览

打开 `.md` 文件后按 `<leader>mp`，`markdown-preview.nvim` 会使用系统默认浏览器打开渲染后的整篇文档；再次按 `<leader>mp` 关闭预览服务。预览包含标题、列表、表格、代码块、任务列表、链接和图片，编辑或保存文件后浏览器会自动刷新。预览只监听本机 `127.0.0.1`，不会向局域网开放。

也可以直接使用 `:MarkdownPreview`、`:MarkdownPreviewStop` 和 `:MarkdownPreviewToggle`。该命令只对 Markdown 缓冲区启用；若浏览器没有自动打开，命令行会显示本地预览 URL，可复制到浏览器访问。

## 终端和其他命令

鼠标选中正文会进入 Visual 模式。按 `Ctrl-Shift-C` 或 `<leader>y` 可将选区复制到系统剪贴板，然后可在终端、浏览器等外部程序粘贴。GNOME Terminal 默认截获 `Ctrl-Shift-C`；若该组合键没有触发 Neovim Visual 复制，请在终端设置中关闭或修改“复制”快捷键，或直接使用 `<leader>y`。Nix 环境包含 X11 的 `xclip` 和 Wayland 的 `wl-copy` 剪贴板提供程序。

已启用 `autoread`。当磁盘文件被外部程序修改且当前缓冲区没有未保存修改时，重新聚焦 Vim、切换缓冲区或短暂停留后会自动执行 `checktime` 并重新读取文件；当前缓冲区有未保存内容时不会静默覆盖。

按 `<leader>tt` 打开浮动 shell，运行 `ls`、`make`、`git status` 等简单命令。终端中的 `Esc` 会传给正在运行的程序；按 `Ctrl-]` 回到外层普通模式，再按 `<leader>tt` 关闭浮窗。

也可以使用 Neovim 原生按键：先按 `Ctrl-\`，松开后再按 `Ctrl-n`，退出终端输入模式并保留 shell 运行。然后用 `Ctrl-w k` 切到上方文档，或 `Ctrl-w w` 轮流切换窗口；回到终端窗口按 `i` 继续输入命令。普通模式下的窗口切换按键不会显示在命令行中。

需要完整的交互式 shell（例如执行 `git commit`）时输入 `:shell`（本配置将其映射为 `:Shell`），会在底部打开终端分屏。提交信息编辑完成后用 `:wq` 退出编辑器，回到 shell 后输入 `exit`，终端分屏会自动关闭并回到原 Neovim 窗口。Neovim 本身不提供 Vim 的 `:shell` 命令。`VIMINIT` 在本配置启动时被清除，避免系统 Vim 误执行 Neovim 的 Lua 配置。

## LSP 服务器

当前包含 Nix、Lua、Shell、C/C++、Python、Rust、Markdown、HTML、CSS、TypeScript/JavaScript、Scala 和 Go 的服务器。

| 语言 | 服务器与项目要求 |
| --- | --- |
| C / C++ | `clangd`，开启后台索引和 clang-tidy。项目应提供 `compile_commands.json`，包含真实的头文件路径和编译参数；CMake 项目可用 `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` 生成。其他构建目录可在 `.clangd` 中设置 `CompileFlags.CompilationDatabase`。 |
| Scala / Chisel | `metals`，识别 `build.sbt`、`build.sc`、Gradle 或 Maven 项目。打开 Scala 文件后接受构建导入提示，或执行 `:MetalsImportBuild` 手动导入；需要 JDK、项目构建工具及依赖下载可用。Chisel 的跳转按 Scala 项目处理。 |
| Lua | `lua-language-server`，支持普通 Lua 文件。项目可用 `.luarc.json` / `.luarc.jsonc` 指定运行时和库；本配置目录没有这类文件时自动识别 Neovim 的 LuaJIT 和 `vim` API。 |

把光标放在函数或符号名称上，`gd` 跳到定义，`gr` 列出引用，`<leader>ci` 列出调用者，`<leader>co` 列出被调用函数；结果列表用 `Enter` 打开，`:copen` 重新打开列表。调用层级是否可用取决于服务器。`:LspInfo` 查看连接，`:checkhealth vim.lsp` 查看启动问题。
当前 LuaLS 不提供调用层级接口，Lua 中用 `gr` 查找调用位置；`<leader>ci` / `<leader>co` 用于支持该接口的服务器。

引用/调用列表用 `:cclose` 关闭，或在列表中按 `q`；`:copen` 可重新打开。`:LspInfo` 打开 LSP 健康检查，`:MetalsLog` 打开当前项目的 `.metals/metals.log`，跳到日志末尾；日志窗口按 `q` 关闭，用 `:edit!` 重新加载最新内容。`:messages` 查看 Neovim 收到的提示。普通模式 `Ctrl-Space` 同时兼容终端发送的 `Ctrl-@`；`Ctrl-Enter` 需要终端支持独立传输这个组合键，否则使用 `gd`。

C、Scala 和 Lua 已使用 Treesitter 高亮，并加强关键字、类型、函数、字符串、数字、参数和注释的颜色区分；LSP 类型/函数颜色与语法高亮保持一致。语法高亮不依赖项目构建导入是否成功。

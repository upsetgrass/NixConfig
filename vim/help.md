# 零散
- `Ctrl-w w`    切换窗口
- `<leader>r`   打开/关闭右侧文件大纲树
- `Ctrl-w w`    切换目录、正文、大纲
- `fzf`
  - `<leader>f`   查找项目文件(不区分大小写)
  - `<leader>g`   搜索项目文本(不区分大小写)
  - `<leader>fc`  切换文件名匹配的大小写模式
- `<leader>cv`    复制当前文件绝对路径；终端中用 `Ctrl-Shift-v`，或退出终端输入模式后按 `p` 粘贴
- `<leader>tt`    打开/关闭浮动终端
- `<leader>h`     打开/关闭本帮助
- `Ctrl+o`        回到跳转前的位置
- `:close`        关闭光标所在窗口
- `<leader>gp`    浮窗预览光标所在的变更块
- `<leader>gb`    查看当前行的提交作者、时间和提交信息
- `:%s/[src]/[dest]/g`  将src批量替换为dest
# 项目树
- `<leader>e`     打开/关闭项目目录树
  - `<leader>o/p` 左右/上下分屏选中的项目目录树的文件
  - `a`           在项目目录树中，新增文件/目录
  - `r`           在项目目录树中，重命名
  - `d/D`         移到回收站（不会永久删除）

# 终端
- `:shell`     底部打开终端分屏
  - `exit`     退出底部分屏
  - `Ctrl+\,n` 保持底部分屏，切换到普通模式

# LSP
- `:LspInfo`: 查看 LSP 状态
- metal
  - `:MetalsImportBuild` Scala 项目,导入构建，让 Metals 索引项目
  - `:MetalsLog`: 查看项目日志（`q` 关闭，`:edit!` 刷新）
- `gd` / `Ctrl-Enter`  跳转符号（类、函数、变量）定义
- `gr` / `Ctrl-Space`  查找符号（类、函数、变量）引用
- `<leader>ci`         查找哪些函数/方法调用了当前函数/方法
- `<leader>co`         查看当前函数调用了哪些函数
- `:cclose`            关闭引用列表
- `Ctrl+o`             回到跳转前的位置

# 基本
- `(n)dd` : 删除n行(并存储删除内容到"vim剪切板")
- `.`     : 重复上一条命令
- `u`     : 撤回上一步操作
- `Ctrl+r`: 反撤回上一步操作
- `(n)yy` : 复制n行到vim剪切板
- `(n)p`  : 粘贴n次
- `:n`    : 移动到n行
- `:+-n`  : 向上向下移动n行
- `@:`    : 重复Ex命令(`:`)

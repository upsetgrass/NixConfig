# 独立 Fcitx5 拼音环境

```bash
nix-shell ~/nix/fcitx5/fcitx5.nix
```

进入 shell 时自动后台启动 Fcitx5，退出 shell、关闭终端后继续运行，直到主动退出或注销桌面。再次进入 shell 不重复启动已运行的实例。没有图形会话或检测到 Fcitx 4 运行时不会自动启动。此配置不会更改登录自启动设置。

本机是 Ubuntu GNOME/X11，原搜狗使用 `/usr/bin/fcitx`（Fcitx 4），环境变量已设为 `fcitx`。已启动应用是否能直接接上 Fcitx5 取决于它的输入法模块；无法输入时，完全退出应用，再从这个 shell 启动。启动成功不等于所有应用都已完成输入法集成。

## 关闭搜狗并试用

先构建包，构建成功后再关闭搜狗，这样下载或构建失败不会影响当前输入：

```bash
nix-build ~/nix/fcitx5/fcitx5.nix -A fcitx5 --no-out-link
```

关闭搜狗：优先右键 Fcitx/搜狗托盘，选择“退出”。如果它又被搜狗守护进程拉起，或找不到退出菜单，可在普通终端执行：

```bash
# 先停止本用户的搜狗守护进程和服务，再退出 Fcitx 4。
pkill -u "$(id -u)" -f '^/opt/sogoupinyin/files/bin/sogoupinyin-(watchdog|service)([[:space:]]|$)'
pkill -u "$(id -u)" -x fcitx
```

`pkill` 找不到进程时返回非零是正常的。这些操作仅停止当前进程，不删除搜狗、词库或自启动配置。`fcitx-remote -c` 只切到英文，不会退出框架。

然后执行 `nix-shell ~/nix/fcitx5/fcitx5.nix`。如果是在 shell 已打开之后才退出搜狗，执行 `fcitx5-nix -d` 启动即可。

默认英文；单独按下并松开左 Shift 或右 Shift 切换中英文，新窗口默认英文。

中文状态下输入 `/emoji`，会出现含 327 种 emoji 的候选列表，无需记英文名称。按 `-` 上一页、`+` 下一页（直接按 `=` 也可下一页），也支持 PageUp/PageDown 和鼠标滚轮；数字键或空格确认，Esc 取消。表情涵盖笑脸、手势、爱心、动物、食物、物品和符号。仍保留 `/smile` 等旧快捷词。`emoji.mb` 是项目中的词表，修改后重新进入 shell 并重启输入法即可更新。

## 中英文标点与 emoji 修复

英文状态的逗号、句号为 `,.`，中文状态为 `，。`。标点插件默认开启，并关闭“字母或者数字之后输入半角标点”。`Ctrl+.` 仍可手动切换中英文标点；若误触后变成半角，可以再按一次。

快捷短语关闭英文拼写补全（`Spell=False`），避免 `/emoji` 的候选中混入英文。启动器会同步项目的 emoji 词表到独立用户数据目录，用户目录和包内提供同一份词表。

升级已有配置时，关闭配置窗口，重新执行 `nix-shell ~/nix/fcitx5/fcitx5.nix`，再运行 `fcitx5-nix-apply`。它会备份并更新相关设置，普通启动依旧保留 GUI 修改。

## GUI 配置

在这个 nix-shell 中执行：

```bash
fcitx5-configtool
```

也可右键 Fcitx5 托盘选择“配置”。GUI 可以修改输入法列表、切换键、候选框外观，以及拼音和其他插件设置。默认文件仅在缺失时创建，GUI 保存的修改会在重启后保留。GUI 启动器与守护进程使用相同的独立 XDG 目录。

- 配置：`${XDG_CONFIG_HOME:-~/.config}/nix-fcitx5/fcitx5/`
- 学习词库：`${XDG_DATA_HOME:-~/.local/share}/nix-fcitx5/fcitx5/`
- 启动日志：`${XDG_CACHE_HOME:-~/.cache}/nix-fcitx5/fcitx5.log`

Nix 声明提供首次使用的默认值，后续以可写配置为准。修改 `fcitx5.nix` 中默认值不会覆盖已存在的文件；希望重新应用某个文件时，先退出 Fcitx5，将对应文件改名备份，再重新进入 shell。原有 `~/.config/fcitx5` 和搜狗配置保持原样。

## 字体和 Ori 浅色主题

候选框、菜单和托盘使用 `Times New Roman,AR PL UKai CN 16`：英文为 Times New Roman 常规体，中文为文鼎楷体简体。Nix 包含楷体字体，并通过独立 Fontconfig 配置向输入法及其配置工具提供字体；英文的新罗马字体使用本机已安装的版本。

主题为 Ori 官方仓库 Reverier-Xu/Ori-fcitx5 的 `OriLight`，固定提交 `d2cf5df38f11e4e14dcf9436af5b9f8fa0087c55`。关闭深色模式跟随和系统强调色，保持 Ori 浅色外观。首次构建需要联网下载主题和字体。

旧用户升级时，先关闭配置窗口，重新进入 shell，再执行：

```bash
nix-shell ~/nix/fcitx5/fcitx5.nix
fcitx5-nix-apply
```

`fcitx5-nix-apply` 会先让旧实例退出并保存，再备份并更新外观、拼音的斜杠触发键、快捷短语和标点设置，最后后台启动新的输入法包。其他 GUI 设置保留。避免了旧实例退出时覆盖新配置的情况；正常启动时仍不会覆盖 GUI 修改。此命令也可以用于以后重新应用项目的字体和主题预设。

这些设置控制 Fcitx5 候选框、菜单和托盘。文字提交到编辑器、浏览器后，显示字体由应用自身的字体设置决定。

## 拼音突然不可用

在本配置的 nix-shell 中执行以下命令，使用同一个带中文插件的包重新启动：

```bash
fcitx5-nix -r -d
```

然后点击输入框，按 Shift 切换中文，输入 `nihao` 验证。不要直接运行系统中的 `fcitx5`，它不一定包含本配置的拼音插件或使用本配置目录。若启动命令报错，请保留终端输出。

## 退出 Fcitx5，恢复搜狗

先在 Fcitx5 的 nix-shell 中执行，或右键 Fcitx5 托盘选择“退出”：

```bash
fcitx5-remote -e
```

然后在普通终端执行：

```bash
/usr/bin/fcitx -d
nohup /opt/sogoupinyin/files/bin/sogoupinyin-service >/dev/null 2>&1 &
nohup /opt/sogoupinyin/files/bin/sogoupinyin-watchdog >/dev/null 2>&1 &
```

按原来的中英文切换键；如果没有选到搜狗，用 Fcitx 4 托盘菜单选择搜狗输入法。某个应用未恢复时，完全退出后重新启动。没有修改自启动配置，因此注销后重新登录也会按原设置启动搜狗。

## 包与 Home Manager

参照 `~/work/nix_config/usr/gui/fcitx5/`，使用 Fcitx5 原生拼音和维基百科中文词库，不是搜狗引擎。无需原项目的个人词库、日语/韩语输入法或自定义 Home Manager 模块。

独立构建输入法包：

```bash
nix-build ~/nix/fcitx5/fcitx5.nix -A fcitx5 --no-out-link
```

以后接入 Home Manager 时可复用导出的包、插件和配置文件：

```nix
{ pkgs, lib, ... }:
let
  fcitx = import ./fcitx5.nix { inherit pkgs; };
in {
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = fcitx.addons;
  };
  home.sessionVariables.FONTCONFIG_FILE = fcitx.fontConfig;
  xdg.configFile = lib.mapAttrs' (name: source:
    lib.nameValuePair "fcitx5/${name}" { inherit source; }
  ) fcitx.configFiles;
}
```

此时使用 Home Manager 的正常启动方式和标准 XDG 目录，无需运行 `fcitx5-nix`。非 NixOS 桌面的 GTK/Qt 输入法模块、Wayland 前端还需按桌面环境集成；若应用中无法输入中文，先检查 `fcitx5-diagnose`。

翻页键升级：关闭配置窗口，重新进入 nix-shell，执行 `fcitx5-nix-apply`。该命令会备份全局配置，仅更新上一页／下一页这两个快捷键分组，保留 Shift 切换等其他设置。

## Firefox 浏览器中文输入（本机 Snap / X11）

提供 `firefox-fcitx5.sh`，仅为 Firefox 设置 `GTK_IM_MODULE=xim`、`XMODIFIERS=@im=fcitx` 和 `MOZ_ENABLE_WAYLAND=0`，通过 Snap 自带的 GTK XIM 模块连接已运行的 Fcitx5。它是当前 GNOME/X11 主机的兼容入口；Wayland 会话不应照搬。

先用 Firefox 菜单的“退出”彻底结束所有窗口（包括隐私窗口），再运行：

```bash
~/nix/fcitx5/firefox-fcitx5.sh
```

重新进入本 nix-shell 后也可运行 `firefox-fcitx5`。如果旧浏览器进程仍在，新命令只会把窗口请求转交给它，新的输入法变量不会生效。Fcitx5 必须仍在运行；点击网页输入框或地址栏后按 Shift 切到中文。

本机用户目录的 `firefox_firefox.desktop` 和 `firefox.desktop` 已改为调用上述脚本，菜单／收藏栏重新启动 Firefox 时也会使用这些设置。未修改系统文件和浏览器用户资料。已有用户入口会先备份为 `.before-fcitx5`；要撤销时恢复备份，若无备份则移除对应用户 desktop 文件，桌面会重新使用系统入口。

此修改已经通过脚本语法和 desktop 文件格式检查；沙箱无法启动桌面浏览器，仍需在实际网页中验证。

## emoji 排序、浏览器与配置分享

`emoji.mb` 中同为 `emoji` 关键词的词条按文件内顺序展示；把常用表情整行移动到前面即可。保存后重新进入 nix-shell，运行 `fcitx5-nix-apply`，同步词表并重启。

本机另提供 Edge 的 X11 启动入口：`~/nix/fcitx5/chromium-fcitx5.sh edge`；Chrome 安装后可用同一脚本加 `chrome` 参数。在新的 nix-shell 中也可用 `edge-fcitx5`、`chrome-fcitx5`。启动前用浏览器菜单完全退出旧进程。Edge 的用户菜单入口已设置为使用该脚本；本机尚未发现 Chrome 的系统安装，因此未创建 Chrome 菜单入口。Google 搜索是网页，可在任一浏览器访问。

分享时请复制整个 `fcitx5/` 目录，而不只是两个文件：`fcitx5.nix` 还读取 `firefox-fcitx5.sh`、`chromium-fcitx5.sh`。GUI 保存到 `~/.config/nix-fcitx5/fcitx5/` 的修改不会自动回写到项目；要分享这些修改，需把对应选项写入 `fcitx5.nix` 的 `configFiles`。学习词库也不会随项目自动分享。

首次使用者会得到 Nix 声明的默认配置。当前浏览器脚本面向本机 GNOME/X11 与系统浏览器路径；其他系统需要适配。楷体由 Nix 提供，Times New Roman 使用宿主已安装字体，未安装时会回退。需要联网及可用的 Nix 环境来下载依赖。

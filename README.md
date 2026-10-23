# 常用应用的 Nix 环境

统一启动：

```bash
nix-shell ~/nix/shell.nix
```

也可以运行 `nix-shell ~/nix`，或进入此目录后执行 `nix-shell`。

进入后可以直接使用：

- 通用软件：`git`、`drawio`、`gtkwave`、`nix-direnv`、`ripgrep`。
- `vim 文件名`：加载项目内的 Neovim、插件和工具。
- Fcitx5：图形会话中自动后台启动；已运行时保留当前实例；检测到搜狗/Fcitx 4 时提示先退出。退出 shell 后继续运行。
- `fcitx5-configtool`：输入法 GUI 设置。
- `fcitx5-nix-apply`：备份并应用项目内的字体、主题、emoji、标点和翻页设置，然后重启输入法。
- `microsoft-edge`、`microsoft-edge-stable`：Nix 提供的 Edge 及配置包装命令。
- `edge-fcitx5`、`firefox-fcitx5`、`chrome-fcitx5`：浏览器输入法兼容入口；Edge 优先使用 Nix 包，其他浏览器需已安装。
- `edge-apply-settings`：在 Edge 完全退出后，应用恢复上次会话、左侧垂直标签和默认折叠标签窗格的设置。
- `edge-account-status`：检查独立 Profile 中是否存在账号 `934768061@qq.com`。
- `edge-import-system-profile`：一次性复制系统 Edge Profile 到 Nix Edge Profile；执行前必须退出全部 Edge 进程。

每个应用原有的独立 nix-shell 入口仍可使用。统一入口复用它们的依赖和启动逻辑，Vim 的隔离目录只作用于 Vim 进程，不影响后台 Fcitx5。

## 增加软件

无需额外配置的通用软件统一添加到根目录的 `application.nix`，保持 `shell.nix` 只负责组合各模块。

在新目录编写返回 `pkgs.mkShell` 的配置，然后在 `shell.nix` 的 `applications` 中添加：

```nix
myApp = import ./my-app/my-app.nix { inherit pkgs; };
```

统一入口通过 `inputsFrom` 合并各应用的依赖和 `shellHook`，无需复制包列表或启动脚本。所有应用使用同一个传入的 `pkgs`。

应用需要的环境变量在自身配置中定义，同时通过 `passthru.sessionVariables` 导出，供统一入口合并。`inputsFrom` 本身不会继承环境变量。公共变量写在 `environment.nix` 中，它们优先于应用默认值；目前该文件为空，供后续迁移使用。

## 配置与迁移

此入口提供交互式 shell，不设置登录自启动，也不改变桌面上已经运行的程序的环境。后续接入 Home Manager 时，可逐步将共享变量转为 `home.sessionVariables`，把各应用的包、配置和服务分别交给 Home Manager 管理。

Fcitx5 的 GUI 修改保存在用户配置目录，不会自动写回 Git 项目；详细使用方式见 `fcitx5/README.md`。分享统一环境请提供整个项目目录。首次运行需要下载依赖。

## Edge

进入 `nix-shell ~/nix/shell.nix` 后，`microsoft-edge` 和 `microsoft-edge-stable` 指向 Nix store 中的 Edge 包装命令，而不是 `/usr/bin`。Nix Edge 固定使用 `~/.config/nix-edge`，与系统 Edge 的 `~/.config/microsoft-edge` 隔离，因此不会被已运行的系统 Edge 接管。包装命令启动前会在 Nix Edge 未运行时原子更新默认 Profile 的 `Preferences`，并传递 `--restore-last-session`：恢复上次会话、启用左侧垂直标签、默认折叠标签窗格，同时关闭购物、优惠券、推荐、新标签页内容等推广入口。启动器加载仓库内的 MV3 广告和追踪域名拦截规则，并启用 Edge 内置的侵入式广告过滤。

首次使用前，若要保留当前系统 Edge 的登录状态、标签和书签，先完全退出 Edge，再在 Nix shell 中运行 `edge-import-system-profile`。该命令只在 Nix Profile 尚不存在时复制，绝不覆盖现有 Nix Profile。跨机器时该仓库会应用相同的 Edge 配置；当前旧式 `nix-shell` 入口仍使用各机器的 `<nixpkgs>`，因此不能锁定完全相同的 Edge 二进制版本。账号凭据、Cookie 和最近会话属于本机私有数据，不能安全地随 Git 或 Nix 配置复制。每台新机器应在 Nix Edge 中登录账号；启用 Edge 同步后可同步浏览器数据。

Nix shell 之外的普通终端不会修改全局 `PATH`，因此此时 `which microsoft-edge` 仍显示 `/usr/bin/microsoft-edge`，这是预期行为。运行 `nix-shell ~/nix/shell.nix` 后再执行 `which microsoft-edge`，应显示 `/nix/store/...-microsoft-edge-nix-launcher/bin/microsoft-edge`。

已登录的 Microsoft 账号由 Edge 的用户 Profile 管理，不能也不应把密码写入 Nix 配置。本机默认 Profile 只记住 `934768061@qq.com`，这不等同于已登录；可运行 `edge-account-status` 检查记录。请在 Nix Edge 右上角个人资料菜单中选择登录，在 Microsoft 登录页填写密码并启用同步。密码不要填写进仓库、Nix 表达式或 Nix store。直接运行系统二进制而不经过桌面菜单或 `edge-fcitx5` 时，可先运行 `edge-apply-settings`。

## 退出时清理后台输入法

默认退出后保留后台 Fcitx5。希望退出时一并停止本次 shell 启动的输入法，使用：

```bash
nix-shell ~/nix/shell.nix --arg stopServicesOnExit true
```

然后执行 `exit` 或按 Ctrl+D。shell 内的 PATH、输入法等环境变量随 shell 退出而结束；清理选项还会向进入时新启动的 Fcitx5 发送正常退出信号。进入前已经运行的 Fcitx5 不会被关闭。若希望默认清理，可把 `shell.nix` 的参数默认值改为 `true`。

此选项只管理统一入口启动的 Fcitx5。之后手动重启替换的输入法、手动启动的浏览器及其他后台程序不在自动清理范围内；浏览器请自行退出。未来增加后台服务时，由对应软件配置管理其生命周期，统一入口仅传递清理开关。

`stopServicesOnExit` 的进程记录和退出清理由 `fcitx5/fcitx5.nix` 实现，`shell.nix` 仅传递参数。独立使用同样支持：`nix-shell ~/nix/fcitx5/fcitx5.nix --arg stopServicesOnExit true`。

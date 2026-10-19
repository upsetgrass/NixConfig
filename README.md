# 常用应用的 Nix 环境

统一启动：

```bash
nix-shell ~/nix/shell.nix
```

也可以运行 `nix-shell ~/nix`，或进入此目录后执行 `nix-shell`。

进入后可以直接使用：

- `vim 文件名`：加载项目内的 Neovim、插件和工具。
- Fcitx5：图形会话中自动后台启动；已运行时保留当前实例；检测到搜狗/Fcitx 4 时提示先退出。退出 shell 后继续运行。
- `fcitx5-configtool`：输入法 GUI 设置。
- `fcitx5-nix-apply`：备份并应用项目内的字体、主题、emoji、标点和翻页设置，然后重启输入法。
- `edge-fcitx5`、`firefox-fcitx5`、`chrome-fcitx5`：本机浏览器输入法兼容入口，浏览器需已安装。

每个应用原有的独立 nix-shell 入口仍可使用。统一入口复用它们的依赖和启动逻辑，Vim 的隔离目录只作用于 Vim 进程，不影响后台 Fcitx5。

## 增加软件

在新目录编写返回 `pkgs.mkShell` 的配置，然后在 `shell.nix` 的 `applications` 中添加：

```nix
myApp = import ./my-app/my-app.nix { inherit pkgs; };
```

统一入口通过 `inputsFrom` 合并各应用的依赖和 `shellHook`，无需复制包列表或启动脚本。所有应用使用同一个传入的 `pkgs`。

应用需要的环境变量在自身配置中定义，同时通过 `passthru.sessionVariables` 导出，供统一入口合并。`inputsFrom` 本身不会继承环境变量。公共变量写在 `environment.nix` 中，它们优先于应用默认值；目前该文件为空，供后续迁移使用。

## 配置与迁移

此入口提供交互式 shell，不设置登录自启动，也不改变桌面上已经运行的程序的环境。后续接入 Home Manager 时，可逐步将共享变量转为 `home.sessionVariables`，把各应用的包、配置和服务分别交给 Home Manager 管理。

Fcitx5 的 GUI 修改保存在用户配置目录，不会自动写回 Git 项目；详细使用方式见 `fcitx5/README.md`。分享统一环境请提供整个项目目录。首次运行需要下载依赖。

## 退出时清理后台输入法

默认退出后保留后台 Fcitx5。希望退出时一并停止本次 shell 启动的输入法，使用：

```bash
nix-shell ~/nix/shell.nix --arg stopServicesOnExit true
```

然后执行 `exit` 或按 Ctrl+D。shell 内的 PATH、输入法等环境变量随 shell 退出而结束；清理选项还会向进入时新启动的 Fcitx5 发送正常退出信号。进入前已经运行的 Fcitx5 不会被关闭。若希望默认清理，可把 `shell.nix` 的参数默认值改为 `true`。

此选项只管理统一入口启动的 Fcitx5。之后手动重启替换的输入法、手动启动的浏览器及其他后台程序不在自动清理范围内；浏览器请自行退出。未来增加后台服务时，由对应软件配置管理其生命周期，统一入口仅传递清理开关。

`stopServicesOnExit` 的进程记录和退出清理由 `fcitx5/fcitx5.nix` 实现，`shell.nix` 仅传递参数。独立使用同样支持：`nix-shell ~/nix/fcitx5/fcitx5.nix --arg stopServicesOnExit true`。

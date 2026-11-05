# Fcitx5 Home Manager 配置

Fcitx5 由 `~/work/NixConfig/usr/fcitx5/home.nix` 接入 Home Manager，
软件、主题、搜狗词库、emoji 和包装命令由 `default.nix` 构建。

```bash
home-manager switch
systemctl --user status fcitx5-nix.service
```

常用命令：

- `fcitx5-configtool`：打开使用独立配置目录的 GUI 设置。
- `fcitx5-nix-apply`：备份并重新应用主题、字体、emoji、标点和翻页设置。
- `systemctl --user restart fcitx5-nix.service`：重启 Home Manager 管理的输入法。
- `firefox-fcitx5`、`edge-fcitx5`、`chrome-fcitx5`：浏览器输入法兼容入口。

运行数据位于 `~/.config/nix-fcitx5`、`~/.local/share/nix-fcitx5` 和
`~/.cache/nix-fcitx5`，不会写入 Git。修改仓库内主题、词库或配置后，先运行
Home Manager switch，再按需执行 `fcitx5-nix-apply`。

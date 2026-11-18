# NixConfig

本仓库集中保存 Nix 配置。目前使用 Home Manager 管理用户软件、Bash 环境、
Vim、Fcitx5 和 Pi，后续还可以增加开发 shell、独立软件包或 NixOS 配置。
仓库不使用 Flake；`npins/` 固定 nixpkgs、Home Manager 和外部 Fcitx5 主题。

仓库位置：

```text
~/work/NixConfig
```

## 结构

- `usr/default.nix`：仓库内的 Home Manager 用户配置入口。
- `usr/packages.nix`：组合无需额外 Home Manager 配置的软件和应用包。
- `usr/environment.nix`：代理、PATH、Bash、alias、补全、direnv、fzf 和 Starship。
- `usr/vim/`：隔离配置的 Neovim 包装器、插件和语言工具。
- `usr/fcitx5/`：Fcitx5 构建、主题、词库、包装命令和用户 systemd 服务。
- `usr/pi/`：Pi 包、键位、memory skill 与 DeepSeek 备用凭据配置；
  包含 API key 的本机配置不进入 Git。
- `usr/edge/`：可选 Edge 包装器，默认不安装。
- `default.nix`：使用 npins 固定版本构建 activation package。
- `npins/`：固定外部源码版本，`default.nix` 不应手工修改。

## 使用

Home Manager 的标准入口保持为一个薄文件：

```nix
{ imports = [ ~/work/NixConfig/usr ]; }
```

该文件位于 `~/.config/home-manager/home.nix`，只负责导入本仓库。

首次部署或没有 `home-manager` 命令时：

```bash
git clone git@github.com:upsetgrass/NixConfig.git ~/work/NixConfig
mkdir -p ~/.config/home-manager
printf '%s\n' '{ imports = [ ~/work/NixConfig/usr ]; }' \
  > ~/.config/home-manager/home.nix
cd ~/work/NixConfig
nix-build default.nix -o result
./result/activate
```

部署一次后，Home Manager 本身会进入用户 profile。以后使用：

```bash
home-manager build
home-manager switch
```

Bash alias `hms` 等价于上述 `switch` 命令。新终端会自动获得所有软件和环境，
不再需要 `nix-shell`、`.envrc` 或 `nsh`。

## 版本更新

普通构建只读取已固定的 pin。更新前先查看变化：

```bash
npins show
npins update --dry-run
npins update nixpkgs home-manager
home-manager switch
```

`ori-fcitx5` 已冻结，普通 `npins update` 不会移动它。

## Edge

Edge 配置保留在仓库，但沿用旧配置中的默认关闭状态，因为首次安装需要下载较大的
浏览器包。需要启用时，在 `usr/default.nix` 的 `imports` 中加入：

```nix
./edge/home.nix
```

然后运行 `hms`。

## 本机数据

- `~/.pi/agent/auth.json`、`models.json` 和 `settings.json` 可能包含 API key，
  继续作为本机文件，不进入 Git 或 Nix Store；Home Manager 只更新
  `models.json` 中 DeepSeek 的密钥读取命令。
- Edge Profile、Cookie、账号令牌和 Fcitx5 运行时缓存不进入仓库。
- 修改 Home Manager 管理的文件后必须重新运行 `hms` 才会生效。

Pi 的 DeepSeek 备用配置和 API Key 填写位置见
[`usr/pi/README.md`](usr/pi/README.md#deepseek-备用入口)。

Codex 不由本仓库安装或管理；使用 `npx`/npm 安装的 Codex，
其配置和凭据保存在 `~/.codex/`。

Codex 历史导入 Pi 的用法见 [Pi 配置说明](usr/pi/README.md#导入-codex-历史)；
`pi-import-codex --apply` 按原项目目录导入，重复运行会跳过已导入的会话。

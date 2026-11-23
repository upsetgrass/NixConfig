# NixConfig

本仓库集中保存 Nix 配置。目前使用 Home Manager 管理用户软件、Bash 环境、
Vim、Fcitx5 和 Pi，后续还可以增加开发 shell、独立软件包或 NixOS 配置。
仓库不使用 Flake；`npins/` 固定 nixpkgs、Home Manager 和外部 Fcitx5 主题。

仓库位置：

```text
~/work/NixConfig
```

## 结构

- `usr/`：用户配置入口及各软件配置；密钥扫描脚本为 `usr/check-secrets.py`。
- `usr/default.nix`：仓库内的 Home Manager 用户配置入口。
- `default.nix`：使用 npins 固定版本构建 activation package。
- `usr/packages.nix`：组合无需额外 Home Manager 配置的软件和应用包。
- `usr/environment.nix`：代理、PATH、Bash、alias、补全、direnv、fzf 和 Starship。
- `usr/vim/`：隔离配置的 Neovim 包装器、插件和语言工具。
- `usr/fcitx5/`：Fcitx5 构建、主题、词库、包装命令和用户 systemd 服务。
- `usr/pi/`：Pi 包、键位、memory skill 与 DeepSeek 备用凭据配置；
  包含 API key 的本机配置不进入 Git。
- `usr/edge/`：可选 Edge 包装器，默认不安装。
- `npins/`：固定外部源码版本，`default.nix` 不应手工修改。

## 快速开始（首次部署）

以下以 Ubuntu、Bash，以及将仓库放在 `~/work/NixConfig` 为例。请保持该位置：
当前 Vim 配置等文件也使用这个路径。仓库不使用 Flake；首次构建不需要预先安装
Home Manager 或 npins。

1. **准备 Nix 和 Git。** 安装完成后重新打开终端，确认：

   ```bash
   command -v nix-build git
   ```

   若找不到 `nix-build`，先确认 Nix 已安装且初始化脚本已被新终端加载；
   不要用 `nix-shell` 代替下文的首次激活。

2. **克隆到固定位置。** 使用 SSH 地址需要先配置好这台电脑的 GitHub SSH 密钥：

   ```bash
   mkdir -p ~/work
   git clone git@github.com:upsetgrass/NixConfig.git ~/work/NixConfig
   cd ~/work/NixConfig
   ```

   如果仓库允许 HTTPS 克隆，也可以改用 HTTPS 地址。不要只改变克隆目录而忘记
   修改后续的导入路径和仓库中写死的路径。

3. **修改本机信息。** 用户名不在顶层 `default.nix`，而在 `usr/default.nix`：
   将 `home.username` 和 `home.homeDirectory` 改成新电脑的 `whoami` 与 `$HOME`。
   同时检查 `usr/environment.nix` 中的 `127.0.0.1:7897` 代理；如果新电脑
   没有运行这个代理，先调整或移除 `home.sessionVariables` 中的代理变量，
   否则激活后的新终端可能无法联网。

4. **创建 Home Manager 的薄入口。** 如果已有同名文件，先备份它：

   ```bash
   mkdir -p ~/.config/home-manager
   printf '%s\n' '{ imports = [ ~/work/NixConfig/usr ]; }' \
     > ~/.config/home-manager/home.nix
   ```

   其中 `~/work/NixConfig/usr` 必须是**实际存在**的本地路径；
   `~/.config/home-manager/home.nix` 只负责指向仓库。

5. **备份并移走冲突的 Bash 启动文件。** Home Manager 不会直接覆盖已有的
   `~/.profile`、`~/.bashrc`（以及可能存在的 `~/.bash_profile`）。
   在**当前终端保持打开**的情况下执行：

   ```bash
   backup="$HOME/hm-before-nixconfig-$(date +%Y%m%d-%H%M%S)"
   mkdir -m 700 "$backup"
   for name in .profile .bashrc .bash_profile; do
     if [ -e "$HOME/$name" ] || [ -L "$HOME/$name" ]; then
       mv -- "$HOME/$name" "$backup/"
     fi
   done
   ```

   保留备份，不要删除原配置。如果激活时还提示其他文件冲突，只备份、移走
   **报错指定的文件**，再重试；不要使用 `sudo` 或强制覆盖。

6. **构建并首次激活。** 在仓库根目录执行：

   ```bash
   cd ~/work/NixConfig
   nix-build default.nix -o result
   ./result/activate
   ```

   顶层 `default.nix` 使用 npins 固定的 nixpkgs 和 Home Manager 构建
   `activationPackage`。`result` 是当前目录中指向该构建结果（`/nix/store`）的
   **符号链接**，不是需要手工编辑的文件；仓库已忽略它。`activate` 则将构建好的
   用户软件、配置文件链接和用户服务安装/切换到当前用户环境。首次激活不需要
   进入 `nix-shell`。

7. **新开终端，再使用 `hms`。** 成功激活后，关闭并重新打开终端，使新的
   `~/.profile`、`~/.bashrc` 和 PATH 生效。之后更新仓库配置时运行：

   ```bash
   cd ~/work/NixConfig
   hms
   ```

   `hms` 是 `home-manager switch` 的 Bash 别名；首次激活已经安装配置，
   此处再运行一次可验证薄入口和后续更新流程。也可以执行
   `home-manager build` 只构建而不激活。后续不需要 `nix-shell`、`.envrc` 或 `nsh`。

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

## 密钥检查

```bash
# 在仓库根目录运行；只读检查，不修改文件或 Git 状态
cd ~/work/NixConfig
python3 usr/check-secrets.py

# 脚本检查当前工作区（含未跟踪文件）、Git 索引及本地分支、标签和 reflog
# 可达的提交历史，并匹配常见密钥格式与密钥字段赋值。
# 输出仅包含范围、文件路径、行号和命中类别，不输出匹配行或密钥原文。
# 命中是待人工核实的线索，不一定是真实或仍有效的凭据。
#
# 检查范围不包括二进制文件内容、符号链接目标、Git LFS 外部对象，以及
# 尚未获取到本地的远端历史；脚本是启发式检查，不替代专业 secret scanner。
# 若怀疑凭据曾提交，检查后仍应轮换凭据，并另行检查远端历史。
```

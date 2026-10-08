{ pkgs ? import <nixpkgs> {} }:

let
  outlineTreesitterProvider = pkgs.vimUtils.buildVimPlugin {
    name = "outline-treesitter-provider.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "epheien";
      repo = "outline-treesitter-provider.nvim";
      rev = "22dda7329cf608368cbf725effd43daf98c27f32";
      hash = "sha256-PFRiaQPxh+PPFGF1+yMIJIM/tGDOH7CO0xyoayDn78I=";
    };
    doCheck = false;
    postPatch = ''
      substituteInPlace lua/outline/providers/treesitter/aerial/init.lua \
        --replace-fail "for id, node in pairs(matches) do" "for id, nodes in pairs(matches) do
      local node = type(nodes) == 'table' and nodes[1] or nodes"
    '';
  };

  neovim = pkgs.neovim.override {
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
    configure.packages.plugins.start = with pkgs.vimPlugins; [
      nvim-tree-lua
      fzf-lua
      project-nvim
      outline-nvim
      outlineTreesitterProvider
      toggleterm-nvim
      gitsigns-nvim
      blink-cmp
      nvim-lspconfig
      (nvim-treesitter.withPlugins (parsers: map (name: builtins.getAttr name parsers) [
        "bash" "c" "cpp" "c_sharp" "css" "go" "html" "java"
        "javascript" "json" "lua" "markdown" "markdown_inline"
        "nix" "php" "python" "ruby" "rust" "scala" "systemverilog" "toml"
        "tsx" "typescript" "vim" "vimdoc" "yaml" "zig"
      ]))
      snacks-nvim
    ];
  };

  editorTools = with pkgs; [
    fzf fd ripgrep imagemagick glib
    nil lua-language-server bash-language-server clang-tools pyright
    rust-analyzer marksman vscode-langservers-extracted typescript-language-server
    metals gopls
  ];

  vim = pkgs.writeShellScriptBin "vim" ''
    set -eu

    runtime_dir="$(${pkgs.coreutils}/bin/mktemp -d "''${TMPDIR:-/tmp}/nvim-nix.XXXXXXXX")"
    cleanup() {
      ${pkgs.coreutils}/bin/rm -rf -- "$runtime_dir"
    }
    trap cleanup EXIT

    ${pkgs.coreutils}/bin/mkdir -p \
      "$runtime_dir/config" "$runtime_dir/data/nvim" \
      "$runtime_dir/state" "$runtime_dir/cache"

    export XDG_CONFIG_HOME="$runtime_dir/config"
    export XDG_DATA_HOME="$runtime_dir/data"
    export XDG_STATE_HOME="$runtime_dir/state"
    export XDG_CACHE_HOME="$runtime_dir/cache"
    export XDG_CONFIG_DIRS="$runtime_dir/empty-config-dirs"
    export XDG_DATA_DIRS="$runtime_dir/empty-data-dirs"
    unset VIMINIT EXINIT VIM VIMRUNTIME NVIM_APPNAME NVIM_RPLUGIN_MANIFEST
    unset LUA_PATH LUA_CPATH LUA_INIT LUA_INIT_5_1

    ${neovim}/bin/nvim -u ${./init.lua} "$@"
  '';
in

pkgs.mkShell {
  packages = [ vim ] ++ editorTools;

  shellHook = ''
    unalias vim 2>/dev/null || true
    unset -f vim 2>/dev/null || true
    hash -r
    export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
    echo "nvim-nix shell: vim -> ${neovim}/bin/nvim"
  '';
}

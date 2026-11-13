{
  pkgs ? import (import ../../npins).nixpkgs { config.allowUnfree = true; },
  sources ? import ../../npins,
}:

let
  outlineTreesitterProvider = pkgs.vimUtils.buildVimPlugin {
    name = "outline-treesitter-provider.nvim";
    src = sources.outline-treesitter-provider;
    doCheck = false;
    postPatch = ''
      substituteInPlace lua/outline/providers/treesitter/aerial/init.lua \
        --replace-fail "for id, node in pairs(matches) do" "for id, nodes in pairs(matches) do
      local node = type(nodes) == 'table' and nodes[1] or nodes"
    '';
  };

  scalaHighlightOverrides = pkgs.runCommand "nvim-scala-highlight-overrides" { } ''
    mkdir -p "$out/queries/scala"
    cat > "$out/queries/scala/highlights.scm" <<'EOF'
    ; extends

    ; Scala's upstream query treats many uppercase identifiers as types. Chisel
    ; commonly uses uppercase signal names, so declarations such as `val X86PC`
    ; must retain variable highlighting instead of inheriting the type colour.
    (val_definition
      pattern: (identifier) @variable
      (#set! priority 200))

    (var_definition
      pattern: (identifier) @variable
      (#set! priority 200))

    (val_declaration
      name: (identifier) @variable
      (#set! priority 200))

    (var_declaration
      name: (identifier) @variable
      (#set! priority 200))
    EOF
  '';

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
      vim-fugitive
      indent-blankline-nvim
      markdown-preview-nvim
      blink-cmp
      nvim-lspconfig
      onedark-nvim
      (nvim-treesitter.withPlugins (parsers: map (name: builtins.getAttr name parsers) [
        "bash" "c" "cpp" "c_sharp" "css" "go" "html" "java"
        "javascript" "json" "lua" "make" "markdown" "markdown_inline"
        "nix" "php" "python" "ruby" "rust" "scala" "systemverilog" "toml"
        "tsx" "typescript" "vim" "vimdoc" "yaml" "zig"
      ]))
      scalaHighlightOverrides
      snacks-nvim
    ];
  };

  editorTools = with pkgs; [
    fzf fd ripgrep imagemagick glib xclip wl-clipboard xdg-utils
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
    echo "nvim-nix shell: vim -> ${neovim}/bin/nvim"
  '';
}

{ pkgs ? import (import ./npins).nixpkgs { config.allowUnfree = true; } }:

pkgs.mkShell {
  packages = with pkgs; [
    git
    gh # GitHub CLI
    drawio
    gtkwave
    direnv
    nix-direnv
    npins
    starship
    bash-completion
    ripgrep
    lazygit
    htop
    gparted
    # dingdingTalk
    # weChat
    # vscode
    # tencent meeting
    # typora
    # WPS Office
    # securelink
  ];
}

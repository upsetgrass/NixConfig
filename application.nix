{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    git
    drawio
    gtkwave
    nix-direnv
    ripgrep
  ];
}

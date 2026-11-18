{ pkgs ? import (import ../../npins).nixpkgs { config.allowUnfree = true; } }:

pkgs.mkShell {
  packages = with pkgs; [
    nodejs_24
    (import ./resume-package.nix { inherit pkgs; })
  ];

  # Expose the repo-managed memory skill to pi. The symlink points at the
  # working tree (not a Nix store copy), so edits take effect immediately.
  shellHook = ''
    mkdir -p "$HOME/.pi/agent/skills"
    ln -sfn "${builtins.toString ./skills/memory}" "$HOME/.pi/agent/skills/memory"
  '';
}

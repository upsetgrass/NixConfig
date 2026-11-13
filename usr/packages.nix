{ lib, pkgs, sources, ... }:

let
  applicationShell = import ./application.nix { inherit pkgs; };
  vimShell = import ./vim/default.nix { inherit pkgs sources; };
  fcitx5Shell = import ./fcitx5/default.nix {
    inherit pkgs;
    oriSource = sources.ori-fcitx5;
  };
  piShell = import ./pi/default.nix { inherit pkgs; };

  shellPackages = shell: shell.nativeBuildInputs or [ ];
  homeManager = pkgs.callPackage "${sources.home-manager}/home-manager" {
    path = sources.home-manager;
  };
  # The wrapped config tool and the raw Fcitx5 package both provide
  # bin/fcitx5-configtool. Keep the wrappers in the user profile; they retain
  # the raw Fcitx5 package as a runtime dependency.
  fcitx5Packages = lib.filter
    (package: package != fcitx5Shell.fcitx5)
    (shellPackages fcitx5Shell);
in
{
  home.packages = lib.unique (
    shellPackages applicationShell
    ++ shellPackages vimShell
    ++ fcitx5Packages
    ++ shellPackages piShell
    ++ [ homeManager ]
  );
}

{ ... }:

let
  sources = import ../npins;
in
{
  _module.args.sources = sources;

  imports = [
    ./packages.nix
    ./environment.nix
    ./screenshot/home.nix
    ./fcitx5/home.nix
    ./pi/home.nix
  ];

  home.username = "happy_grass";
  home.homeDirectory = "/home/happy_grass";
  home.stateVersion = "26.05";

  nixpkgs.config.allowUnfree = true;

  programs.home-manager = {
    enable = true;
    path = builtins.toString sources.home-manager;
  };
}

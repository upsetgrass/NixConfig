let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {
    config.allowUnfree = true;
  };
  home = import "${sources.home-manager}/modules" {
    configuration = ./usr;
    inherit pkgs;
  };
in
home.activationPackage

{
  pkgs ? import <nixpkgs> {},
  # false: retain background services; true: stop this shell's services on exit.
  stopServicesOnExit ? false,
}:

let
  # Add future application shells here. Use the same nixpkgs for all of them.
  applications = {
    vim = import ./vim/default.nix { inherit pkgs; };
    fcitx5 = import ./fcitx5/default.nix { inherit pkgs stopServicesOnExit; };
  };
  applicationShells = builtins.attrValues applications;
  # inputsFrom merges dependencies and shellHooks, but not environment variables.
  applicationVariables = pkgs.lib.foldl' (variables: application:
    variables // (application.sessionVariables or {})
  ) {} applicationShells;
  # Explicit user-wide settings take precedence over application defaults.
  sessionVariables = applicationVariables // import ./environment.nix;
in
pkgs.mkShell (sessionVariables // {
  name = "happy-grass-shell";
  inputsFrom = applicationShells;

  passthru = { inherit applications sessionVariables stopServicesOnExit; };

  shellHook = ''
    echo "success get Nix environment"
  '';
})

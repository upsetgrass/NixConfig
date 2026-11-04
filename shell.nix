{
  # npins fixes the nixpkgs revision without requiring Flakes.
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs { config.allowUnfree = true; },
  # Proxy settings are configurable from the nix-shell command line.
  enableProxy ? true,
  proxyUrl ? "http://127.0.0.1:7897",
  noProxy ? "localhost,127.0.0.1,192.168.0.0/16",
  # false: retain background services; true: stop this shell's services on exit.
  stopServicesOnExit ? false,
}:

let
  environment = import ./environment.nix {
    inherit pkgs enableProxy proxyUrl noProxy;
  };
  # Add future application shells here. Use the same nixpkgs for all of them.
  applications = {
    application = import ./application.nix { inherit pkgs; };
    vim = import ./vim/default.nix { inherit pkgs; };
    fcitx5 = import ./fcitx5/default.nix {
      inherit pkgs stopServicesOnExit;
      oriSource = sources.ori-fcitx5;
    };
    pi = import ./pi/default.nix { inherit pkgs; };
    # edge = import ./edge/default.nix { inherit pkgs; };
  };
  applicationShells = builtins.attrValues applications;
  # inputsFrom merges dependencies and shellHooks, but not environment variables.
  applicationVariables = pkgs.lib.foldl' (variables: application:
    variables // (application.sessionVariables or {})
  ) {} applicationShells;
  # Explicit user-wide settings take precedence over application defaults.
  sessionVariables = applicationVariables // environment.sessionVariables;
in
pkgs.mkShell (sessionVariables // {
  name = "happy-grass-shell";
  inputsFrom = applicationShells;

  passthru = {
    inherit sources applications sessionVariables enableProxy proxyUrl noProxy stopServicesOnExit;
  };

  shellHook = ''
    ${environment.shellHook}
    echo "success get Nix environment"
  '';
})

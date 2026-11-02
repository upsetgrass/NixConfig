{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    nodejs_24
    pi-coding-agent
  ];

  # Prefer this user's newer npm-installed Pi when present. Node 24 from this
  # shell also runs that installation, which cannot start with system Node 20.
  shellHook = ''
    if [ -x "$HOME/.npm-global/bin/pi" ]; then
      export PATH="$HOME/.npm-global/bin:$PATH"
    fi
  '';
}

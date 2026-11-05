{ pkgs, sources, ... }:

let
  fcitx5Shell = import ./default.nix {
    inherit pkgs;
    oriSource = sources.ori-fcitx5;
  };
in
{
  home.sessionVariables = fcitx5Shell.sessionVariables;

  # Home Manager 让 Fcitx5 随图形用户会话启动，不再依赖 nix-shell hook。
  systemd.user.services.fcitx5-nix = {
    Unit = {
      Description = "Fcitx5 managed by Home Manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${fcitx5Shell.launcher}/bin/fcitx5-nix";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

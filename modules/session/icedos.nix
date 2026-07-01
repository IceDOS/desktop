{ ... }:
{
  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          inherit (config.icedos.system.toolset) desktopEntries;

          inherit (lib) optional;

          lockBin = pkgs.writeShellScriptBin "icedos-lock" ''
            exec ${pkgs.systemd}/bin/loginctl lock-session
          '';

          disableMonitorsBin = pkgs.writeShellScriptBin "icedos-disable-monitors" ''
            ${pkgs.coreutils}/bin/sleep 0.5
            exec ${pkgs.wlopm}/bin/wlopm --off '*'
          '';
        in
        {
          icedos.system.toolset.sessionCommands = [
            {
              command = "lock";
              script = "${pkgs.systemd}/bin/loginctl lock-session";
              help = "lock current session via systemd-logind";
            }
            {
              command = "disable-monitors";
              script = "${pkgs.coreutils}/bin/sleep 0.5 && ${pkgs.wlopm}/bin/wlopm --off '*'";
              help = "power off all Wayland outputs via wlopm";
            }
          ];

          home-manager.sharedModules = optional desktopEntries {
            xdg.desktopEntries.icedos-lock = {
              name = "Lock";
              genericName = "Lock the session";
              comment = "Lock the current session via loginctl";
              icon = "system-lock-screen";
              exec = "${lockBin}/bin/icedos-lock";
              terminal = false;
              type = "Application";

              categories = [
                "System"
                "Settings"
              ];

              settings.Keywords = "lock;screen;session;";
            };

            xdg.desktopEntries.icedos-disable-monitors = {
              name = "Disable Monitors";
              genericName = "Power off all displays";
              comment = "Turn off all Wayland outputs via wlopm";
              icon = "video-display";
              exec = "${disableMonitorsBin}/bin/icedos-disable-monitors";
              terminal = false;
              type = "Application";

              categories = [
                "System"
                "Settings"
              ];

              settings.Keywords = "monitor;display;dpms;off;";
            };
          };
        }
      )
    ];

  meta.name = "session";
}

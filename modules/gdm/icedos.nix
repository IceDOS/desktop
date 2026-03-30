{ icedosLib, lib, ... }:

{
  options.icedos.desktop.gdm.autoSuspend =
    let
      inherit (lib) readFile;
      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop.gdm) autoSuspend;
    in
    icedosLib.mkBoolOption { default = autoSuspend; };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          ...
        }:

        let
          inherit (config.icedos.desktop.gdm) autoSuspend;
        in
        {
          services = {
            displayManager.gdm = {
              inherit autoSuspend;
              enable = true;
            };

            xserver = {
              enable = true;
              xkb.layout = "us,gr";
            };
          };

          # Workaround for autologin
          systemd.services = {
            "getty@tty1".enable = false;
            "autovt@tty1".enable = false;
          };
        }
      )
    ];

  meta.name = "gdm";
}

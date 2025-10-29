{ icedosLib, lib, ... }:

{
  options.icedos.desktop.gdm.autoSuspend =
    let
      defaultConfig =
        let
          inherit (lib) readFile;
        in
        (fromTOML (readFile ./config.toml)).icedos.desktop.gdm;
    in
    icedosLib.mkBoolOption { default = defaultConfig.autoSuspend; };

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
              enable = true;
              autoSuspend = autoSuspend;
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

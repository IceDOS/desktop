{ icedosLib, ... }:

{
  options.icedos.desktop.gdm.autoSuspend = icedosLib.mkBoolOption { default = true; };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          ...
        }:

        let
          cfg = config.icedos;
        in
        {
          services = {
            displayManager.gdm = {
              enable = true;
              autoSuspend = cfg.desktop.gdm.autoSuspend;
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

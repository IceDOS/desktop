{ icedosLib, lib, ... }:

{
  options.icedos.desktop.gdm.autoSuspend =
    let
      inherit (lib) importTOML;
      inherit ((importTOML ./config.toml).icedos.desktop.gdm) autoSuspend;
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
          inherit (config.icedos.desktop) keyboardLayouts;
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
              xkb.layout = lib.mkIf (keyboardLayouts != [ ]) (lib.concatStringsSep "," keyboardLayouts);
            };
          };

          # Workaround for autologin
          systemd.services = {
            "getty@tty1".enable = false;
            "autovt@tty1".enable = false;
          };

          icedos.system.tips.list =
            lib.optionals autoSuspend [
              "The login screen suspends the machine when nobody signs in; turn autoSuspend off under [icedos.desktop.gdm]."
            ]
            ++ lib.optionals (keyboardLayouts != [ ]) [
              "Your keyboard layouts work on the login screen too, not only after you sign in."
            ];
        }
      )
    ];

  meta.name = "gdm";
}

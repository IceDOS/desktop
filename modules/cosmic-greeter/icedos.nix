{ icedosLib, ... }:

{
  options.icedos.desktop.cosmic-greeter = icedosLib.mkBoolOption { default = true; };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          icedosLib,
          ...
        }:

        let
          inherit (icedosLib) abortIf;
          inherit (config.services.displayManager) gdm;
        in
        {
          services.displayManager.cosmic-greeter.enable = abortIf (gdm.enable) ''GDM is enabled – this configuration is incompatible with the cosmic greeter. Please remove "gdm" from the modules list of the desktop repository!'';
        }
      )
    ];

  meta.name = "cosmic-greeter";
}

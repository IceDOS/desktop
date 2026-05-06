{ ... }:

{
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
          inherit (icedosLib) validate;
          inherit (config.services.displayManager) gdm sddm;
        in
        {
          services.displayManager.cosmic-greeter.enable = validate.abort {
            when = gdm.enable || sddm.enable;
            path = "icedos.desktop.cosmic-greeter";
            msg = "More than one display managers are setup, please use only one!";
          };
        }
      )
    ];

  meta.name = "cosmic-greeter";
}

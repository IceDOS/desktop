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
          inherit (config.services.displayManager) cosmic-greeter gdm;
        in
        {
          services.displayManager.sddm = {
            enable = validate.abort {
              when = cosmic-greeter.enable || gdm.enable;
              path = "icedos.desktop.sddm";
              msg = "More than one display managers are setup, please use only one!";
            };

            wayland.enable = true;
          };
        }
      )
    ];

  meta.name = "sddm";
}

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
          services.displayManager.plasma-login-manager = {
            enable = validate.abort {
              when = cosmic-greeter.enable || gdm.enable;
              path = "icedos.desktop.plm";
              msg = "More than one display managers are setup, please use only one!";
            };
          };
        }
      )
    ];

  meta.name = "plm";
}

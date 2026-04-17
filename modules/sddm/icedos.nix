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
          inherit (icedosLib) abortIf;
          inherit (config.services.displayManager) cosmic-greeter gdm;
        in
        {
          services.displayManager.sddm = {
            enable = abortIf (
              cosmic-greeter.enable || gdm.enable
            ) "More than one display managers are setup, please use only one!";

            wayland.enable = true;
          };
        }
      )
    ];

  meta.name = "sddm";
}

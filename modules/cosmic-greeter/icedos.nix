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
          inherit (config.services.displayManager) gdm sddm;
        in
        {
          services.displayManager.cosmic-greeter.enable = abortIf (
            gdm.enable || sddm.enable
          ) "More than one display managers are setup, please use only one!";
        }
      )
    ];

  meta.name = "cosmic-greeter";
}

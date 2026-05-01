{ lib, ... }:

{
  options.icedos.desktop.entries =
    let
      inherit (lib) mkOption readFile;
      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop) entries;
    in
    mkOption { default = entries; };

  outputs.nixosModules =
    { ... }:
    [
      (
        { config, lib, ... }:
        let
          inherit (lib) listToAttrs;
          inherit (config.icedos.desktop) entries;
        in
        {
          home-manager.sharedModules = [
            {
              xdg.desktopEntries = listToAttrs (
                map (entry: {
                  name = entry.id;
                  value = removeAttrs entry [ "id" ];
                }) entries
              );
            }
          ];
        }
      )
    ];

  meta.name = "entries";
}

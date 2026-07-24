{ icedosLib, lib, ... }:

{
  options.icedos.desktop.entries =
    let
      inherit (lib) importTOML types;
      inherit (icedosLib) mkListOption;
      inherit ((importTOML ./config.toml).icedos.desktop) entries;
    in
    mkListOption { default = entries; } types.attrs;

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

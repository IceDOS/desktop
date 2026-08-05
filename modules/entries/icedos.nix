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

          validEntry = e: e ? id && builtins.isString e.id && e.id != "";
        in
        {
          home-manager.sharedModules = [
            {
              xdg.desktopEntries = listToAttrs (
                map (
                  entry:
                  if validEntry entry then
                    {
                      name = entry.id;
                      value = removeAttrs entry [ "id" ];
                    }
                  else
                    throw "icedos.desktop.entries: every entry must declare a non-empty string 'id' (got: ${builtins.toJSON (builtins.attrNames entry)})"
                ) entries
              );
            }
          ];
        }
      )
    ];

  meta.name = "entries";
}

{ icedosLib, lib, ... }:

{
  options.icedos.desktop.users =
    let
      inherit (icedosLib) mkStrOption mkSubmoduleAttrsOption;
      inherit (lib) importTOML;
      inherit ((importTOML ./config.toml).icedos.desktop.users.username) startupScript;
    in
    mkSubmoduleAttrsOption { } {
      startupScript = mkStrOption { default = startupScript; };
    };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          pkgs,
          ...
        }:

        let
          inherit (pkgs) makeDesktopItem writeShellScriptBin;
          inherit (config.icedos) desktop;
        in
        {
          home-manager.sharedModules = [
            (
              { config, lib, ... }:
              let
                inherit (lib) mkIf;
                inherit (desktop.users.${config.home.username}) startupScript;
                script = "icedos-startup";

                startupBin = writeShellScriptBin script ''
                  ${icedosLib.bash.exportSystemPath}

                  ${startupScript}
                '';

                startupItem = makeDesktopItem {
                  name = script;
                  desktopName = "StartupScript";
                  exec = "${startupBin}/bin/${script}";
                  terminal = false;
                };
              in
              {
                xdg.configFile."autostart/${script}.desktop" = mkIf (startupScript != "") {
                  source = "${startupItem}/share/applications/${script}.desktop";
                };
              }
            )
          ];
        }
      )
    ];

  meta.name = "startup";
}

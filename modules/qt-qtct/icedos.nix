{ icedosLib, lib, ... }:

{
  options.icedos.desktop =
    let
      inherit (icedosLib) mkBoolOption;
      inherit (lib) importTOML;
      inherit ((importTOML ./config.toml).icedos.desktop) qtQtct;
    in
    {
      qtQtct = mkBoolOption { default = qtQtct; };
    };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          icedosLib,
          lib,
          ...
        }:

        let
          inherit (config.icedos) desktop;
          inherit (desktop) qtQtct;
          inherit (icedosLib) generateAccent;

          inherit (lib)
            assertMsg
            mkForce
            mkIf
            ;

          resolved = generateAccent config;

          # accent is expected as "#rrggbb"; assert so a non-hex accent fails
          # eval loudly instead of producing a malformed palette / patch.
          accentColor =
            assert assertMsg (
              builtins.match "#[0-9a-fA-F]{6}" resolved.hex != null
            ) "icedos.desktop accentColor resolved to '${resolved.hex}', expected #rrggbb";
            resolved.hex;

          # Qt palette (20/21 fields). Positions 12/14/15 are Highlight/Link/LinkVisited
          # — those are the accent slots.
          mkStyleColors =
            { qt6ct, accent }:
            let
              inherit (builtins) match stringLength substring;

              # accent is expected as "#rrggbb"; assert so a non-hex accent
              # fails eval loudly instead of producing a malformed palette.
              a =
                assert (match "#[0-9a-fA-F]{6}" accent != null);
                substring 1 (stringLength accent - 1) accent;
            in
            ''
              [ColorScheme]
              active_colors=#ffeeeeec,#ff373737,#ff515151,#ff444444,#ff1e1e1e,#ff2a2a2a,#ffeeeeec,#ffffffff,#ffeeeeec,#ff2d2d2d,#ff353535,#19000000,#ff${a},#ffffffff,#ff${a},#ff${a},#ff2d2d2d,#ff000000,#b2262626,#ffffffff,#ffeeeeec${
                if qt6ct then ",#ff308cc6" else ""
              }

              disabled_colors=#ffbebebe,#ffefefef,#ffffffff,#ffcacaca,#ffbebebe,#ffb8b8b8,#ffbebebe,#ffffffff,#ffbebebe,#ffefefef,#ffefefef,#ffb1b1b1,#ff919191,#ffffffff,#ff0000ff,#ffff00ff,#fff7f7f7,#ff000000,#ffffffdc,#ff000000,#80000000${
                if qt6ct then ",#ff919191" else ""
              }

              inactive_colors=#ffeeeeec,#ff373737,#ff515151,#ff444444,#ff1e1e1e,#ff2a2a2a,#ffeeeeec,#ffffffff,#ffeeeeec,#ff2d2d2d,#ff353535,#19000000,#ff${a},#ffffffff,#ff${a},#ff${a},#ff2d2d2d,#ff000000,#b2262626,#ffffffff,#ffeeeeec${
                if qt6ct then ",#ff308cc6" else ""
              }
            '';

        in
        (mkIf (qtQtct && !config.services.desktopManager.plasma6.enable) {
          home-manager.sharedModules = [
            (
              { config, ... }:
              {
                xdg.configFile = {
                  "qt5ct/colors/stylix.conf".text = mkStyleColors {
                    qt6ct = false;
                    accent = accentColor;
                  };
                  "qt6ct/colors/stylix.conf".text = mkStyleColors {
                    qt6ct = true;
                    accent = accentColor;
                  };
                };

                qt.qt5ctSettings.Appearance.color_scheme_path = "${config.xdg.configHome}/qt5ct/colors/stylix.conf";
                qt.qt6ctSettings.Appearance.color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/stylix.conf";

                # HM's qt module exports QT_STYLE_OVERRIDE=kvantum in both
                # session planes; override to "" so qtct owns the style choice.
                home.sessionVariables.QT_STYLE_OVERRIDE = mkForce "";
                systemd.user.sessionVariables.QT_STYLE_OVERRIDE = mkForce "";
              }
            )
          ];
        })
      )
    ];

  meta.name = "qt-qtct";
}

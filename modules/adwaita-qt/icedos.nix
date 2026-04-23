{ icedosLib, lib, ... }:

{
  options.icedos.desktop =
    let
      inherit (icedosLib) mkBoolOption;
      inherit (lib) readFile;
      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop) themeQt;
    in
    {
      themeQt = mkBoolOption { default = themeQt; };
    };

  outputs.nixosModules =
    { inputs, ... }:
    [
      (
        {
          config,
          icedosLib,
          lib,
          pkgs,
          ...
        }:

        let
          inherit (config.icedos) desktop users;
          inherit (desktop) themeQt;
          inherit (icedosLib) generateAccentColor;
          inherit (lib) hasAttr mapAttrs mkIf mkMerge;

          accentColor =
            let
              inherit (desktop) accentColor gnome;
            in
            generateAccentColor {
              inherit accentColor;
              gnomeAccentColor = gnome.accentColor;
              hasGnome = hasAttr "gnome" desktop;
            };

          stylixEnabled = config.stylix.enable or false;
          stylixColors = config.lib.stylix.colors or { };
          stylixAccentSlot = config.icedos.desktop.stylix.accentBase16Slot or "base0D";
          stylixAccent = "#${stylixColors.${stylixAccentSlot} or "89b4fa"}";

          # Qt palette (20/21 fields). Positions 12/14/15 are Highlight/Link/LinkVisited
          # — those are the accent slots. Parameterized so it can be called for both
          # the stylix-on (catppuccin accent) and stylix-off (GNOME accent) paths.
          mkStyleColors =
            { qt6ct, accent }:
            let
              inherit (builtins) substring stringLength;
              a = substring 1 (stringLength accent - 1) accent;
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

          accentColorPatch = ''
            diff --git a/src/lib/stylesheet/processed/Adwaita-dark.css b/src/lib/stylesheet/processed/Adwaita-dark.css
            index 619bb32..27d5745 100644
            --- a/src/lib/stylesheet/processed/Adwaita-dark.css
            +++ b/src/lib/stylesheet/processed/Adwaita-dark.css
            @@ -3,13 +3,13 @@
             @define-color bg_color #353535;
             @define-color fg_color #eeeeec;
             @define-color selected_fg_color #ffffff;
            -@define-color selected_bg_color #15539e;
            +@define-color selected_bg_color ${accentColor};
             @define-color selected_borders_color #030c17;
             @define-color borders_color #1b1b1b;
             @define-color alt_borders_color #070707;
             @define-color borders_edge rgba(238, 238, 236, 0.07);
            -@define-color link_color #3584e4;
            -@define-color link_visited_color #1b6acb;
            +@define-color link_color ${accentColor};
            +@define-color link_visited_color ${accentColor};
             @define-color top_hilight rgba(238, 238, 236, 0.07);
             @define-color dark_fill #282828;
             @define-color headerbar_bg_color #2d2d2d;
            @@ -18,7 +18,7 @@
             @define-color scrollbar_bg_color #313131;
             @define-color scrollbar_slider_color #a4a4a3;
             @define-color scrollbar_slider_hover_color #c9c9c7;
            -@define-color scrollbar_slider_active_color #1b6acb;
            +@define-color scrollbar_slider_active_color ${accentColor};
             @define-color warning_color #f57900;
             @define-color error_color #cc0000;
             @define-color success_color #26ab62;
            @@ -44,16 +44,16 @@
             @define-color backdrop_selected_fg_color #d6d6d6;
             @define-color backdrop_borders_color #202020;
             @define-color backdrop_dark_fill #2e2e2e;
            -@define-color suggested_bg_color #15539e;
            +@define-color suggested_bg_color ${accentColor};
             @define-color suggested_border_color #030c17;
            -@define-color progress_bg_color #15539e;
            +@define-color progress_bg_color ${accentColor};
             @define-color progress_border_color #030c17;
            -@define-color checkradio_bg_color #15539e;
            +@define-color checkradio_bg_color ${accentColor};
             @define-color checkradio_fg_color #ffffff;
            -@define-color checkradio_borders_color #092444;
            -@define-color switch_bg_color #15539e;
            +@define-color checkradio_borders_color ${accentColor};
            +@define-color switch_bg_color ${accentColor};
             @define-color switch_borders_color #030c17;
            -@define-color focus_border_color rgba(21, 83, 158, 0.7);
            +@define-color focus_border_color ${accentColor};
             @define-color alt_focus_border_color rgba(255, 255, 255, 0.3);
             @define-color dim_label_opacity 0.55;
             button { color: #eeeeec; outline-color: rgba(21, 83, 158, 0.7); border-color: #1b1b1b; background-image: linear-gradient(to top, #373737 2px, #3a3a3a); box-shadow: 0 1px 2px rgba(0, 0, 0, 0.07); }
            @@ -86,10 +86,10 @@ checkradio:active { box-shadow: inset 0 1px black; background-image: image(#2828

             checkradio:disabled { box-shadow: none; color: rgba(255, 255, 255, 0.7); }

            -checkradio:checked { background-clip: border-box; background-image: linear-gradient(to bottom, #185fb4 20%, #15539e 90%); border-color: #092444; box-shadow: 0 1px rgba(0, 0, 0, 0.05); color: #ffffff; }
            +checkradio:checked { background-clip: border-box; background-image: ${accentColor}; border-color: #092444; box-shadow: 0 1px rgba(0, 0, 0, 0.05); color: #ffffff; }

            -checkradio:checked:hover { background-image: linear-gradient(to bottom, #1b68c6 10%, #185cb0 90%); }
            +checkradio:checked:hover { background-image: ${accentColor}; }

            -checkradio:checked:active { box-shadow: inset 0 1px black; background-image: image(#124787); }
            +checkradio:checked:active { box-shadow: inset 0 1px black; background-image: image(${accentColor}); }

             checkradio:checked:disabled { box-shadow: none; color: rgba(255, 255, 255, 0.7); }
          '';

          adwaitaQtBuilder = (
            let
              inherit accentColorPatch;
            in
            p:
            p.overrideAttrs (
              _: old: {
                patches = (old.patches or [ ]) ++ [
                  (
                    let
                      inherit (builtins) toFile;
                    in
                    toFile "adwaita-qt-accent.patch" accentColorPatch
                  )
                ];
              }
            )
          );
        in
        mkMerge [

        (mkIf (themeQt && !config.services.desktopManager.plasma6.enable && !stylixEnabled) {
          environment.systemPackages = with pkgs; [
            (adwaitaQtBuilder adwaita-qt)
            (adwaitaQtBuilder adwaita-qt6)
            kdePackages.qt6ct
            libsForQt5.qt5ct
          ];

          home-manager.users = mapAttrs (user: _: {
            home.file =
              let
                force = true;

                styleColors = qt6ct: mkStyleColors { inherit qt6ct; accent = accentColor; };

                qtConf =
                  qt6ct:
                  let
                    colorSchemePath =
                      if qt6ct then
                        "color_scheme_path=/home/${user}/.config/qt6ct/style-colors.conf"
                      else
                        "color_scheme_path=/home/${user}/.config/qt5ct/style-colors.conf";

                    fonts =
                      if qt6ct then
                        ''
                          fixed="Noto Sans Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"
                          general="Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"
                        ''
                      else
                        ''
                          fixed="Noto Sans Mono,12,-1,5,50,0,0,0,0,0,Regular"
                          general="Noto Sans,12,-1,5,50,0,0,0,0,0,Regular"
                        '';
                  in
                  ''
                    [Appearance]
                    ${colorSchemePath}
                    custom_palette=true
                    icon_theme=Tela-black-dark
                    standard_dialogs=default
                    style=Adwaita-Dark

                    [Fonts]
                    ${fonts}

                    [Interface]
                    activate_item_on_single_click=1
                    buttonbox_layout=0
                    cursor_flash_time=1000
                    dialog_buttons_have_icons=1
                    double_click_interval=400
                    gui_effects=@Invalid()
                    keyboard_scheme=2
                    menus_have_icons=true
                    show_shortcuts_in_context_menus=true
                    stylesheets=@Invalid()
                    toolbutton_style=4
                    underline_shortcut=1
                    wheel_scroll_lines=3

                    [SettingsWindow]
                    geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\xff\xff\xff\xfd\xff\xff\xff\xe2\0\0\x5\\\0\0\x4\x41\0\0\0\0\0\0\0\0\0\0\x5Y\0\0\x4>\0\0\0\0\0\0\0\0\n\xc0\0\0\0\0\0\0\0\0\0\0\x5Y\0\0\x4>)

                    [Troubleshooting]
                    force_raster_widgets=1
                    ignored_applications=@Invalid()
                  '';
              in
              {
                ".config/qt5ct/qt5ct.conf" = {
                  inherit force;
                  text = qtConf false;
                };

                ".config/qt5ct/style-colors.conf" = {
                  inherit force;
                  text = styleColors false;
                };

                ".config/qt6ct/qt6ct.conf" = {
                  inherit force;
                  text = qtConf true;
                };

                ".config/qt6ct/style-colors.conf" = {
                  inherit force;
                  text = styleColors true;
                };
              };
          }) users;
        })

        # When stylix is on:
        #   - Stylix writes `custom_palette=true` in qt{5,6}ct.conf without a
        #     `color_scheme_path`, so Qt falls back to its blue default QPalette.
        #     Fix: write a palette file + point qt{5,6}ctSettings at it.
        #   - Stylix's generated Kvantum SVG hardcodes #${base0D-hex} (blue in
        #     catppuccin) for ~28 accent widget fills. Kvantum renders widgets
        #     from the SVG, not the `highlight.color` key. So setting accent =
        #     base0E alone still paints tabs/buttons/progress blue. Fix: post-
        #     process the SVG to replace base0D-hex with the user's chosen
        #     accent-slot hex, then override xdg.configFile."Kvantum/Base16Kvantum"
        #     to point to the patched directory.
        (mkIf (themeQt && !config.services.desktopManager.plasma6.enable && stylixEnabled) {
          home-manager.users = mapAttrs (user: _: {
            xdg.configFile = {
              "qt5ct/colors/stylix.conf".text =
                mkStyleColors { qt6ct = false; accent = stylixAccent; };
              "qt6ct/colors/stylix.conf".text =
                mkStyleColors { qt6ct = true; accent = stylixAccent; };

              "Kvantum/Base16Kvantum".source =
                let
                  # Re-run stylix's kvantum templates ourselves. Avoids infinite
                  # recursion from reading config.xdg.configFile from within a
                  # definition for the same option. Stylix's `config.lib.stylix.colors`
                  # expects a nix path for `template`, so we write the upstream
                  # mustache content to a store path first.
                  mustachePath = p: pkgs.writeText (baseNameOf p) (builtins.readFile p);
                  svgMustache = mustachePath "${inputs.stylix}/modules/qt/kvantum.svg.mustache";
                  kvconfigMustache = mustachePath "${inputs.stylix}/modules/qt/kvconfig.mustache";
                  svgGen = config.lib.stylix.colors {
                    template = svgMustache;
                    extension = ".svg";
                  };
                  kvconfigGen = config.lib.stylix.colors {
                    template = kvconfigMustache;
                    extension = ".kvconfig";
                  };
                  base0DHex = stylixColors.base0D or "89b4fa";
                  accentHexNoHash = stylixColors.${stylixAccentSlot} or "cba6f7";
                  patched = pkgs.runCommandLocal "base16-kvantum-accent" { } ''
                    mkdir -p $out
                    cp ${kvconfigGen} $out/Base16Kvantum.kvconfig
                    cp ${svgGen} $out/Base16Kvantum.svg
                    chmod -R u+w $out
                    ${pkgs.gnused}/bin/sed -i \
                      -e 's/#${base0DHex}/#${accentHexNoHash}/g' \
                      -e 's/#${lib.toUpper base0DHex}/#${lib.toUpper accentHexNoHash}/g' \
                      $out/Base16Kvantum.svg
                  '';
                in
                lib.mkForce "${patched}";
            };

            qt.qt5ctSettings.Appearance.color_scheme_path =
              "/home/${user}/.config/qt5ct/colors/stylix.conf";
            qt.qt6ctSettings.Appearance.color_scheme_path =
              "/home/${user}/.config/qt6ct/colors/stylix.conf";

            # HM's qt module sets QT_STYLE_OVERRIDE=kvantum in both
            # home.sessionVariables AND systemd.user.sessionVariables.
            # qt{5,6}ct warn when that env var coexists with their own
            # `style=kvantum` config. Override both to empty so qtct owns
            # the style choice. (Keeping qt.style.name = "kvantum" avoids
            # stylix's "Changing config.qt.style is unsupported" warning.)
            home.sessionVariables.QT_STYLE_OVERRIDE = lib.mkForce "";
            systemd.user.sessionVariables.QT_STYLE_OVERRIDE = lib.mkForce "";
          }) users;
        })

        ]
      )
    ];

  meta.name = "adwaita-qt";
}

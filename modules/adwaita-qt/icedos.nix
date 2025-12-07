{ icedosLib, lib, ... }:

{
  options.icedos.desktop =
    let
      inherit (icedosLib) mkBoolOption;
      desktop = (fromTOML (lib.fileContents ./config.toml)).icedos.desktop;
    in
    {
      themeQt = mkBoolOption { default = desktop.themeQt; };
    };

  outputs.nixosModules =
    { ... }:
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
          inherit (lib) hasAttr mapAttrs mkIf;

          accentColor =
            let
              inherit (desktop) accentColor gnome;
            in
            generateAccentColor {
              accentColor = accentColor;
              gnomeAccentColor = gnome.accentColor;
              hasGnome = hasAttr "gnome" desktop;
            };

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
        mkIf themeQt {
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

                styleColors =
                  qt6ct:
                  let
                    inherit (builtins) substring stringLength;
                    accent = substring 1 (stringLength accentColor - 1) accentColor;
                  in
                  ''
                    [ColorScheme]
                    active_colors=#ffeeeeec,#ff373737,#ff515151,#ff444444,#ff1e1e1e,#ff2a2a2a,#ffeeeeec,#ffffffff,#ffeeeeec,#ff2d2d2d,#ff353535,#19000000,#ff${accent},#ffffffff,#ff${accent},#ff${accent},#ff2d2d2d,#ff000000,#b2262626,#ffffffff,#ffeeeeec${
                      if qt6ct then ",#ff308cc6" else ""
                    }

                    disabled_colors=#ffbebebe,#ffefefef,#ffffffff,#ffcacaca,#ffbebebe,#ffb8b8b8,#ffbebebe,#ffffffff,#ffbebebe,#ffefefef,#ffefefef,#ffb1b1b1,#ff919191,#ffffffff,#ff0000ff,#ffff00ff,#fff7f7f7,#ff000000,#ffffffdc,#ff000000,#80000000${
                      if qt6ct then ",#ff919191" else ""
                    }

                    inactive_colors=#ffeeeeec,#ff373737,#ff515151,#ff444444,#ff1e1e1e,#ff2a2a2a,#ffeeeeec,#ffffffff,#ffeeeeec,#ff2d2d2d,#ff353535,#19000000,#ff${accent},#ffffffff,#ff${accent},#ff${accent},#ff2d2d2d,#ff000000,#b2262626,#ffffffff,#ffeeeeec${
                      if qt6ct then ",#ff308cc6" else ""
                    }
                  '';

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
        }
      )
    ];

  meta.name = "adwaita-qt";
}

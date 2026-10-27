{
  icedosLib,
  lib,
  ...
}:

{
  # icedosLib contribution: the DE-dependent helpers from repo-root lib.nix,
  # merged into the module-facing icedosLib (this module is always loaded).
  lib = import ../../lib.nix { inherit icedosLib lib; };

  options.icedos.desktop =
    let
      inherit (icedosLib)
        mkBoolOption
        mkEnumOption
        mkIntBetweenOption
        mkStrListOption
        mkStrOption
        mkUsersOption
        ;

      inherit (lib) importTOML;

      inherit ((importTOML ./config.toml).icedos.desktop)
        accentColor
        autologinUser
        clock
        keyboardLayouts
        timezone
        users
        wallpaper
        windows
        xdg-desktop-portal
        ;

      inherit (users.username) idle;
    in
    {
      accentColor = mkStrOption { default = accentColor; };

      autologinUser = mkStrOption { default = autologinUser; };
      keyboardLayouts = mkStrListOption { default = keyboardLayouts; };
      timezone = mkStrOption { default = timezone; };
      wallpaper = mkStrOption { default = wallpaper; };

      clock = {
        date = mkBoolOption { default = clock.date; };

        firstDayOfTheWeek =
          mkEnumOption
            {
              path = "icedos.desktop.clock.firstDayOfTheWeek";
              source = ./config.toml;
              default = clock.firstDayOfTheWeek;
            }
            [
              "monday"
              "tuesday"
              "wednesday"
              "thursday"
              "friday"
              "saturday"
              "sunday"
            ];

        hourFormat24 = mkBoolOption { default = clock.hourFormat24; };
        seconds = mkBoolOption { default = clock.seconds; };
        weekday = mkBoolOption { default = clock.weekday; };
      };

      windows = {
        activeHint = mkBoolOption { default = windows.activeHint; };

        activeHintSize = mkIntBetweenOption {
          path = "icedos.desktop.windows.activeHintSize";
          source = ./config.toml;
          default = windows.activeHintSize;
        } 0 10;

        maximizeButton = mkBoolOption { default = windows.maximizeButton; };
        minimizeButton = mkBoolOption { default = windows.minimizeButton; };

        focus = {
          followsMouse = mkBoolOption { default = windows.focus.followsMouse; };

          delay = mkIntBetweenOption {
            path = "icedos.desktop.windows.focus.delay";
            source = ./config.toml;
            default = windows.focus.delay;
          } 0 3000;
        };
      };

      users = mkUsersOption {
        idle = {
          disable-monitors = {
            enable = mkBoolOption { default = idle.disable-monitors.enable; };

            seconds = mkIntBetweenOption {
              path = "icedos.desktop.users.<u>.idle.disable-monitors.seconds";
              source = ./config.toml;
              default = idle.disable-monitors.seconds;
            } 0 86400;
          };

          lock = {
            enable = mkBoolOption { default = idle.lock.enable; };

            seconds = mkIntBetweenOption {
              path = "icedos.desktop.users.<u>.idle.lock.seconds";
              source = ./config.toml;
              default = idle.lock.seconds;
            } 0 86400;
          };

          suspend = {
            enable = mkBoolOption { default = idle.suspend.enable; };

            seconds = mkIntBetweenOption {
              path = "icedos.desktop.users.<u>.idle.suspend.seconds";
              source = ./config.toml;
              default = idle.suspend.seconds;
            } 0 86400;
          };
        };
      };

      xdg-desktop-portal.forceGtkFilePicker = mkBoolOption {
        default = xdg-desktop-portal.forceGtkFilePicker;
      };
    };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          inherit (icedosLib) generateAccent;
          inherit (icedosLib.users) genDefaults;

          inherit (lib)
            any
            attrValues
            length
            mapAttrs
            mkDefault
            mkForce
            mkIf
            optional
            optionalAttrs
            optionals
            ;

          inherit (config.icedos) desktop users;

          inherit (desktop)
            autologinUser
            timezone
            xdg-desktop-portal
            ;

          resolved = generateAccent config;

          anyUserIdle = f: any (u: f u.idle) (attrValues desktop.users);
        in
        {
          icedos.desktop.users = genDefaults {
            inherit users;
          };

          warnings = optional (resolved.warning != null) resolved.warning;

          icedos.system.tips.list = [
            "Pick the color of buttons, switches and highlights with accentColor under [icedos.desktop]."
            "The clock can show the date, the weekday and seconds; turn each on under [icedos.desktop.clock]."
            "Hide the minimize or maximize button on window titlebars under [icedos.desktop.windows]."
            "Set wallpaper under [icedos.desktop] to a picture path, or to color:RRGGBB for a plain color."
          ]
          ++ optionals (autologinUser != "") [
            "Autologin is on, so this machine signs ${autologinUser} in without asking for a password."
          ]
          ++ optionals (length desktop.keyboardLayouts > 1) [
            "You set up more than one keyboard layout, so you can switch layouts while typing."
          ]
          ++ optionals desktop.windows.focus.followsMouse [
            "Windows take focus when your mouse moves over them, no click needed."
          ]
          ++ optionals xdg-desktop-portal.forceGtkFilePicker [
            "Every app opens the same file picker, so Open and Save dialogs always look alike."
          ]
          ++ optionals (anyUserIdle (i: i.lock.enable)) [
            "Your screen locks itself when you step away; change the wait under [icedos.desktop.users.<name>.idle.lock]."
          ]
          ++ optionals (anyUserIdle (i: i.disable-monitors.enable)) [
            "Your screens switch off on their own when idle; the wait is under [icedos.desktop.users.<name>.idle]."
          ]
          ++ optionals (anyUserIdle (i: i.suspend.enable)) [
            "This machine suspends after a long idle; turn that off under [icedos.desktop.users.<name>.idle.suspend]."
          ];

          environment = {
            systemPackages = (
              with pkgs;
              [
                adwaita-icon-theme # Gtk theme
                dconf-editor # Edit gnome's dconf
                libnotify # Send desktop notifications

                # Qt Wayland decoration plugins reading the GNOME button-layout
                # dconf key, so Qt apps honor `icedos.desktop.titlebar.*`.
                qadwaitadecorations
                qadwaitadecorations-qt6
              ]
            );

            sessionVariables = {
              NIXOS_OZONE_WL = 1;
              QT_QPA_PLATFORM = "wayland;xcb";

              # Force Qt Wayland CSD to the adwaita plugin (reads the dconf
              # key); without it Qt5 uses bradient, Qt6 libdecor's default.
              QT_WAYLAND_DECORATION = "adwaita";
            };
          };

          fonts.packages = with pkgs.nerd-fonts; [ jetbrains-mono ];
          time.timeZone = timezone;

          i18n = {
            defaultLocale = "en_US.UTF-8";
            extraLocaleSettings.LC_MEASUREMENT = "es_ES.UTF-8";
          };

          services.displayManager.autoLogin.user = mkIf (autologinUser != "") autologinUser;

          # Reload (not restart) polkitd: a restart drops agent registrations,
          # breaking pkexec. SIGHUP re-reads rules without dropping clients.
          systemd.services.polkit = {
            restartIfChanged = false;
            reloadIfChanged = true;
            reloadTriggers = mkForce [ ];
          };

          xdg = {
            portal.config.common = {
              default = "*";
            }
            // optionalAttrs xdg-desktop-portal.forceGtkFilePicker {
              "org.freedesktop.impl.portal.FileChooser" = "gtk";
            };
          };

          home-manager.users = mapAttrs (user: _: {
            home.pointerCursor.enable = true;

            # Adopt the 26.05+ default to silence the legacy warning.
            gtk.gtk4.theme = mkDefault null;

            dconf.settings = {
              "org/gnome/desktop/interface".color-scheme = mkDefault "prefer-dark";

              "org/gnome/desktop/wm/preferences".button-layout =
                icedosLib.desktop.mkButtonLayoutString desktop.windows;

              "org/gtk/settings/file-chooser" = {
                sort-directories-first = true;
                date-format = "with-time";
                show-type-column = false;
                show-hidden = true;
              };
            };

            xdg.userDirs = {
              enable = true;
              createDirectories = true;
              setSessionVariables = true;
            };
          }) users;
        }
      )
    ];

  meta = {
    name = "default";

    dependencies = [
      {
        modules = [
          "applications"
          "bookmarks"
          "qt-qtct"
          "entries"
          "session"
          "startup"
          "stylix"
        ];
      }
    ];

    optionalDependencies = [
      {
        modules = [
          "clear-xdg-portals"
          "displays"
        ];
      }
    ];
  };
}

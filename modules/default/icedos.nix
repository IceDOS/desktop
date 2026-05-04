{
  icedosLib,
  lib,
  ...
}:

{
  options.icedos.desktop =
    let
      inherit (icedosLib)
        mkBoolOption
        mkNumberOption
        mkStrOption
        mkUsersOption
        ;

      inherit (lib) readFile;

      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop)
        accentColor
        autologinUser
        timezone
        users
        windows
        ;

      inherit (users.username) idle;
    in
    {
      accentColor = mkStrOption { default = accentColor; };
      autologinUser = mkStrOption { default = autologinUser; };
      timezone = mkStrOption { default = timezone; };

      windows = {
        activeHint = mkBoolOption { default = windows.activeHint; };
        activeHintSize = mkNumberOption { default = windows.activeHintSize; };
        maximizeButton = mkBoolOption { default = windows.maximizeButton; };
        minimizeButton = mkBoolOption { default = windows.minimizeButton; };
      };

      users = mkUsersOption {
        idle = {
          disableMonitors = {
            enable = mkBoolOption { default = idle.disableMonitors.enable; };
            seconds = mkNumberOption { default = idle.disableMonitors.seconds; };
          };

          lock = {
            enable = mkBoolOption { default = idle.lock.enable; };
            seconds = mkNumberOption { default = idle.lock.seconds; };
          };

          suspend = {
            enable = mkBoolOption { default = idle.suspend.enable; };
            seconds = mkNumberOption { default = idle.suspend.seconds; };
          };
        };
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
          inherit (icedosLib) generateAccentColor;
          inherit (icedosLib.users) genDefaults;

          inherit (lib)
            hasAttr
            mapAttrs
            mkIf
            mkDefault
            mkMerge
            ;

          inherit (config.icedos) applications desktop users;
          inherit (applications) defaultBrowser defaultEditor;
          inherit (desktop) autologinUser timezone;

          stylixEnabled = config.stylix.enable or false;

          stylixAccentSlot = config.icedos.desktop.stylix.accentBase16Slot or "base0D";
          stylixColors = config.lib.stylix.colors or { };

          accentHex =
            if stylixEnabled then
              "#${stylixColors.${stylixAccentSlot}}"
            else
              generateAccentColor {
                inherit (desktop) accentColor;
                gnomeAccentColor = desktop.gnome.accentColor or "blue";
                hasGnome = hasAttr "gnome" desktop;
              };

          audioPlayer = "io.bassi.Amberol.desktop";
          browser = defaultBrowser;
          editor = defaultEditor;

          gtkCss = ''
            @define-color accent_bg_color ${accentHex};
            @define-color accent_color @accent_bg_color;

            :root {
              --accent-bg-color: @accent_bg_color;
            }
          '';

          imageViewer = "org.gnome.Loupe.desktop";
          videoPlayer = "io.github.celluloid_player.Celluloid.desktop";
        in
        {
          icedos.desktop.users = genDefaults {
            users = config.icedos.users;
          };

          environment = {
            systemPackages = with pkgs; [
              adwaita-icon-theme # Gtk theme
              amberol # Music player
              dconf-editor # Edit gnome's dconf
              libnotify # Send desktop notifications
              loupe # Image viewer
              onlyoffice-desktopeditors # Office tools

              # Qt5 + Qt6 Wayland decoration plugins that read
              # `org/gnome/desktop/wm/preferences/button-layout` from dconf,
              # so qt5ct/qt6ct/Telegram/etc. honor `icedos.desktop.titlebar.*`.
              qadwaitadecorations
              qadwaitadecorations-qt6
            ];

            sessionVariables = {
              NIXOS_OZONE_WL = 1;
              QT_QPA_PLATFORM = "wayland;xcb";
              QT_QPA_PLATFORMTHEME = mkIf (
                !stylixEnabled && !config.services.desktopManager.plasma6.enable
              ) "qt5ct";

              # Forces Qt's Wayland CSD to the adwaita plugin (provided by the
              # qadwaitadecorations packages above), which reads the GNOME
              # button-layout dconf key. Without this Qt5 falls back to the
              # bradient plugin (3 buttons hardcoded) and Qt6 falls back to
              # libdecor's default plugin.
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

          # Reload (don't restart) polkitd on switch. A restart drops every
          # authentication agent's registration (cosmic-osd, sysauth, polkit-kde,
          # gnome-shell), breaking pkexec until the session restarts. polkit 127
          # is Type=notify-reload, so SIGHUP re-reads rules without dropping clients.
          # reloadTriggers is cleared because reloadIfChanged makes the upstream
          # split between reload-/restart-triggers redundant (both end up reloading).
          systemd.services.polkit = {
            restartIfChanged = false;
            reloadIfChanged = true;
            reloadTriggers = lib.mkForce [ ];
          };

          xdg = {
            portal.config.common.default = "*";

            mime = {
              enable = true;

              defaultApplications = {
                "application/json" = editor;
                "application/pdf" = browser;
                "application/x-bittorrent" = "de.haeckerfelix.Fragments.desktop";
                "application/x-ms-dos-executable" = "wine.desktop";
                "application/x-shellscript" = editor;
                "application/x-wine-extension-ini" = editor;
                "application/x-zerosize" = editor;
                "application/xhtml_xml" = browser;
                "application/xhtml+xml" = browser;
                "application/zip" = "org.gnome.FileRoller.desktop";
                "audio/aac" = audioPlayer;
                "audio/flac" = audioPlayer;
                "audio/m4a" = audioPlayer;
                "audio/mp3" = audioPlayer;
                "audio/wav" = audioPlayer;
                "image/avif" = imageViewer;
                "image/jpeg" = imageViewer;
                "image/png" = imageViewer;
                "image/svg+xml" = imageViewer;
                "text/html" = browser;
                "text/plain" = editor;
                "video/mp4" = videoPlayer;
                "video/quicktime" = videoPlayer;
                "video/x-matroska" = videoPlayer;
                "video/x-ms-wmv" = videoPlayer;
                "x-scheme-handler/about" = browser;
                "x-scheme-handler/http" = browser;
                "x-scheme-handler/https" = browser;
                "x-scheme-handler/unknown" = browser;
                "x-www-browser" = browser;
              };
            };
          };

          home-manager.users =
            let
              inherit (pkgs) adw-gtk3 bibata-cursors tela-icon-theme;
              hasCosmicGtkTheming = desktop.cosmic.appearance.gtkTheming or false;
            in
            mapAttrs (
              user: _:
              { config, ... }:
              mkMerge [
                {
                  # Adopt the 26.05+ default to silence the legacy warning
                  # regardless of stylix state; specific blocks below can override.
                  gtk.gtk4.theme = mkDefault null;

                  dconf.settings = {
                    "org/gnome/desktop/interface".color-scheme = mkDefault "prefer-dark";

                    # GTK/libadwaita apps (Nautilus, GNOME Files, Settings, etc.)
                    # read this on every session, not only under GNOME. Set it
                    # here so non-GNOME sessions (COSMIC, Hyprland) also honor
                    # the global titlebar visibility flags.
                    "org/gnome/desktop/wm/preferences".button-layout =
                      icedosLib.desktop.mkButtonLayoutString desktop.windows;

                    "org/gtk/settings/file-chooser" = {
                      sort-directories-first = true;
                      date-format = "with-time";
                      show-type-column = false;
                      show-hidden = true;
                    };
                  };

                  xdg = {
                    configFile."user-dirs.dirs".force = true;

                    userDirs = {
                      enable = true;
                      createDirectories = true;
                      setSessionVariables = true;
                    };
                  };

                  # Propagate XDG user dir vars to the systemd user environment so
                  # D-Bus-activated apps (e.g. Nautilus) show them in their sidebar
                  # on non-GNOME sessions. gnome-session does this via
                  # dbus-update-activation-environment; no equivalent runs on COSMIC/Hyprland etc.
                  systemd.user.sessionVariables = {
                    XDG_DESKTOP_DIR = config.xdg.userDirs.desktop;
                    XDG_DOCUMENTS_DIR = config.xdg.userDirs.documents;
                    XDG_DOWNLOAD_DIR = config.xdg.userDirs.download;
                    XDG_MUSIC_DIR = config.xdg.userDirs.music;
                    XDG_PICTURES_DIR = config.xdg.userDirs.pictures;
                    XDG_PUBLICSHARE_DIR = config.xdg.userDirs.publicShare;
                    XDG_TEMPLATES_DIR = config.xdg.userDirs.templates;
                    XDG_VIDEOS_DIR = config.xdg.userDirs.videos;
                  };
                }

                # gnome-session populates GTK bookmarks at first login on
                # GNOME, so the XDG dirs always show up in the nautilus / GTK
                # file-picker sidebar. No equivalent runs on COSMIC/Hyprland,
                # so seed the same defaults declaratively here.
                (mkIf (!hasAttr "gnome" desktop) {
                  xdg.configFile."gtk-3.0/bookmarks" = {
                    force = true;
                    text =
                      let
                        u = config.xdg.userDirs;
                      in
                      lib.concatMapStringsSep "\n" (p: "file://${p}") [
                        u.documents
                        u.download
                        u.music
                        u.pictures
                        u.videos
                        u.publicShare
                        u.templates
                      ]
                      + "\n";
                  };
                })

                (mkIf (!stylixEnabled) {
                  gtk = {
                    enable = true;

                    theme = {
                      name = "adw-gtk3-dark";
                      package = adw-gtk3;
                    };

                    cursorTheme = {
                      name = "Bibata-Modern-Classic";
                      package = bibata-cursors;
                    };

                    iconTheme = {
                      name = "Tela-black-dark";
                      package = tela-icon-theme;
                    };

                    gtk3.extraCss = gtkCss;
                    gtk4.theme = null; # Fallback for system versions lower than 26.05
                  };

                  xdg.configFile = {
                    "gtk-3.0/gtk.css".force = true;
                    "gtk-3.0/settings.ini".force = true;
                    "gtk-4.0/settings.ini".force = true;
                  };

                  home = {
                    pointerCursor = {
                      gtk.enable = true;
                      x11.enable = true;
                      package = bibata-cursors;
                      name = "Bibata-Modern-Classic";
                      size = 24;
                    };

                    file.".config/gtk-4.0/gtk.css" = mkIf (!hasCosmicGtkTheming) {
                      force = true;
                      text = gtkCss;
                    };
                  };
                })

              ]
            ) users;
        }
      )
    ];

  meta = {
    name = "default";

    dependencies = [
      {
        modules = [
          "adwaita-qt"
          "entries"
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

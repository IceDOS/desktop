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
        mkSubmoduleAttrsOption
        ;

      inherit (desktop.users.username) idle;
      desktop = (fromTOML (lib.fileContents ./config.toml)).icedos.desktop;
    in
    {
      accentColor = mkStrOption { default = desktop.accentColor; };
      autologinUser = mkStrOption { default = ""; };
      timezone = mkStrOption { default = desktop.timezone; };

      users = mkSubmoduleAttrsOption { default = { }; } {
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
          inherit (lib) mapAttrs mkIf;
          cfg = config.icedos;

          accentColor = icedosLib.generateAccentColor {
            accentColor = cfg.desktop.accentColor;
            gnomeAccentColor = cfg.desktop.gnome.accentColor;
            hasGnome = lib.hasAttr "gnome" cfg.desktop;
          };

          audioPlayer = "io.bassi.Amberol.desktop";

          browser = cfg.applications.defaultBrowser;
          editor = cfg.applications.defaultEditor;

          gtkCss = ''
            @define-color accent_bg_color ${accentColor};
            @define-color accent_color @accent_bg_color;

            :root {
              --accent-bg-color: @accent_bg_color;
            }
          '';

          imageViewer = "org.gnome.Loupe.desktop";
          videoPlayer = "io.github.celluloid_player.Celluloid.desktop";
        in
        {
          environment = {
            systemPackages = with pkgs; [
              adwaita-icon-theme # Gtk theme
              amberol # Music player
              dconf-editor # Edit gnome's dconf
              libnotify # Send desktop notifications
              libreoffice-fresh # Office tools
              loupe # Image viewer
            ];

            sessionVariables = {
              NIXOS_OZONE_WL = 1;
              QT_QPA_PLATFORM = "wayland;xcb";
              QT_QPA_PLATFORMTHEME = "qt5ct";
            };
          };

          fonts.packages = with pkgs; [
            cantarell-fonts
            meslo-lgs-nf
            nerd-fonts.jetbrains-mono
          ];

          time.timeZone = cfg.desktop.timezone;

          i18n = {
            defaultLocale = "en_US.UTF-8";
            extraLocaleSettings.LC_MEASUREMENT = "es_ES.UTF-8";
          };

          services.displayManager.autoLogin.user = mkIf (
            cfg.desktop.autologinUser != ""
          ) cfg.desktop.autologinUser;

          xdg.portal.config.common.default = "*";

          home-manager.users = mapAttrs (user: _: {
            gtk = {
              enable = true;

              theme = {
                name = "adw-gtk3-dark";
                package = pkgs.adw-gtk3;
              };

              cursorTheme = {
                name = "Bibata-Modern-Classic";
                package = pkgs.bibata-cursors;
              };

              iconTheme = {
                name = "Tela-black-dark";
                package = pkgs.tela-icon-theme;
              };

              gtk3.extraCss = gtkCss;
            };

            dconf.settings = {
              # Enable dark mode
              "org/gnome/desktop/interface".color-scheme = "prefer-dark";

              # GTK file picker
              "org/gtk/settings/file-chooser" = {
                sort-directories-first = true;
                date-format = "with-time";
                show-type-column = false;
                show-hidden = true;
              };
            };

            xdg = {
              configFile = {
                "gtk-4.0/gtk.css".enable = false;
                "mimeapps.list".force = true;
              };

              # Default apps
              mimeApps = {
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

              userDirs = {
                enable = true;
                createDirectories = true;
              };
            };

            home = {
              pointerCursor = {
                gtk.enable = true;
                x11.enable = true;
                package = pkgs.bibata-cursors;
                name = "Bibata-Modern-Classic";
                size = 24;
              };

              file.".config/gtk-4.0/gtk.css".text = gtkCss;
            };
          }) cfg.users;
        }
      )
    ];

  meta.name = "default";
}

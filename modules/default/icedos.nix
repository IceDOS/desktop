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
        mkListOption
        mkNumberOption
        mkStrListOption
        mkStrOption
        mkUsersOption
        ;

      inherit (lib) readFile;

      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop)
        accentColor
        autologinUser
        bookmarks
        defaultBrowser
        defaultEditor
        keyboardLayouts
        timezone
        users
        wallpaper
        windows
        ;

      inherit (users.username) idle;
    in
    {
      accentColor = mkStrOption { default = accentColor; };
      autologinUser = mkStrOption { default = autologinUser; };
      defaultBrowser = mkStrOption { default = defaultBrowser; };
      defaultEditor = mkStrOption { default = defaultEditor; };
      keyboardLayouts = mkStrListOption { default = keyboardLayouts; };
      timezone = mkStrOption { default = timezone; };
      wallpaper = mkStrOption { default = wallpaper; };

      bookmarks = {
        documents = mkBoolOption { default = bookmarks.documents; };
        downloads = mkBoolOption { default = bookmarks.downloads; };
        music = mkBoolOption { default = bookmarks.music; };
        pictures = mkBoolOption { default = bookmarks.pictures; };
        videos = mkBoolOption { default = bookmarks.videos; };
        public = mkBoolOption { default = bookmarks.public; };
        templates = mkBoolOption { default = bookmarks.templates; };
        extras = mkListOption { default = bookmarks.extras; } (
          with lib.types;
          either str (subookmarksodule {
            options = {
              path = mkStrOption { };
              name = mkStrOption { default = ""; };
            };
          })
        );
      };

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
          inherit (icedosLib) generateAccent;
          inherit (icedosLib.users) genDefaults;

          inherit (lib)
            hasAttr
            mapAttrs
            mkDefault
            mkForce
            mkIf
            mkMerge
            optional
            ;

          inherit (config.icedos) desktop users;
          inherit (desktop) defaultBrowser defaultEditor;
          inherit (desktop) autologinUser timezone;

          resolved = generateAccent config;

          inherit (resolved) hex stylixOn;

          stylixEnabled = stylixOn;
          accentHex = hex;

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
            inherit users;
          };

          warnings = optional (resolved.warning != null) resolved.warning;

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
            reloadTriggers = mkForce [ ];
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
              { config, lib, ... }:
              mkMerge [
                {
                  # Adopt the 26.05+ default to silence the legacy warning
                  # regardless of stylix state; specific blocks below can override.
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
                }

                # gnome-session populates GTK bookmarks at first login on
                # GNOME, so the XDG dirs always show up in the nautilus / GTK
                # file-picker sidebar. No equivalent runs on COSMIC/Hyprland,
                # so reconcile a declared set here while leaving any other
                # bookmarks (e.g. drag-to-sidebar in Nautilus) untouched.
                (mkIf (!hasAttr "gnome" desktop) (
                  let
                    inherit (config.xdg) userDirs;
                    inherit (desktop) bookmarks;

                    inherit (lib)
                      concatMapStringsSep
                      concatStringsSep
                      elem
                      filter
                      hasInfix
                      hm
                      optional
                      optionalString
                      unique
                      ;

                    defaultEntries =
                      optional bookmarks.documents {
                        uri = "file://${userDirs.documents}";
                        label = "Documents";
                      }
                      ++ optional bookmarks.downloads {
                        uri = "file://${userDirs.download}";
                        label = "Downloads";
                      }
                      ++ optional bookmarks.music {
                        uri = "file://${userDirs.music}";
                        label = "Music";
                      }
                      ++ optional bookmarks.pictures {
                        uri = "file://${userDirs.pictures}";
                        label = "Pictures";
                      }
                      ++ optional bookmarks.videos {
                        uri = "file://${userDirs.videos}";
                        label = "Videos";
                      }
                      ++ optional bookmarks.public {
                        uri = "file://${userDirs.publicShare}";
                        label = "Public";
                      }
                      ++ optional bookmarks.templates {
                        uri = "file://${userDirs.templates}";
                        label = "Templates";
                      };

                    # Each extra is either a bare path string or a
                    # { path; name ? ""; } attrset. URI is the path verbatim if it
                    # already contains a scheme, otherwise prefixed with file://.
                    # Label falls back to the path's last segment when name is empty
                    # or the entry was a bare string.
                    normalizeExtra =
                      e:
                      if builtins.isString e then
                        {
                          path = e;
                          name = "";
                        }
                      else
                        e;

                    extrasEntries = map (
                      e:
                      let
                        n = normalizeExtra e;
                        uri = if hasInfix "://" n.path then n.path else "file://${n.path}";
                        label = if n.name != "" then n.name else baseNameOf n.path;
                      in
                      {
                        inherit uri label;
                      }
                    ) bookmarks.extras;

                    # Extras override defaults at the same URI: drop the default
                    # entry whose URI is also declared as an extra so the extra's
                    # label wins. Two extras at the same URI is treated as a config bug.
                    extrasUris = map (e: e.uri) extrasEntries;
                    duplicateUris = unique (
                      filter (uri: builtins.length (filter (x: x == uri) extrasUris) > 1) extrasUris
                    );

                    declaredEntries = filter (e: !(elem e.uri extrasUris)) defaultEntries ++ extrasEntries;

                    declaredLines = map (e: "${e.uri} ${e.label}") declaredEntries;

                    declaredFile = pkgs.writeText "icedos-gtk-bookmarks-declared" (
                      concatStringsSep "\n" declaredLines + optionalString (declaredLines != [ ]) "\n"
                    );

                    # Nautilus / GTK file pickers auto-seed all XDG dirs on first
                    # sidebar interaction. Treat them as always-removable so toggling
                    # one off in icedos config drops it from the bookmarks file even
                    # when the line was added by another app and never tracked in
                    # our state file.
                    xdgUriFile = pkgs.writeText "icedos-gtk-bookmarks-xdg-uris" (
                      concatMapStringsSep "\n" (p: "file://${p}") [
                        userDirs.documents
                        userDirs.download
                        userDirs.music
                        userDirs.pictures
                        userDirs.videos
                        userDirs.publicShare
                        userDirs.templates
                      ]
                      + "\n"
                    );
                  in
                  {
                    assertions = [
                      {
                        assertion = duplicateUris == [ ];
                        message = ''
                          icedos.desktop.bookmarks.extras: duplicate URIs: ${concatStringsSep ", " duplicateUris}. Each path can only appear once in extras (extras override matching defaults automatically).
                        '';
                      }
                    ];

                    home.activation.seedGtkBookmarks = hm.dag.entryAfter [ "writeBoundary" ] ''
                      target="$HOME/.config/gtk-3.0/bookmarks"
                      state_dir="$HOME/.local/state/icedos"
                      state="$state_dir/gtk-bookmarks.declared"

                      $DRY_RUN_CMD mkdir -p "$state_dir" "$(dirname "$target")"
                      $DRY_RUN_CMD ${pkgs.coreutils}/bin/touch "$target"

                      # URI = first whitespace-separated token of a bookmark line.
                      uris() { ${pkgs.gawk}/bin/awk '{print $1}' "$1" | ${pkgs.coreutils}/bin/sort -u; }

                      # URIs we may overwrite or strip = standard XDG dirs ∪
                      # previously-declared. Toggling off (or removing an extra) drops
                      # the URI even if Nautilus seeded it before we managed it.
                      removable=$(${pkgs.coreutils}/bin/mktemp)
                      {
                        uris ${xdgUriFile}
                        if [ -f "$state" ]; then uris "$state"; fi
                      } | ${pkgs.coreutils}/bin/sort -u > "$removable"
                      stale_uris=$(${pkgs.coreutils}/bin/comm -23 "$removable" <(uris ${declaredFile}))
                      ${pkgs.coreutils}/bin/rm -f "$removable"

                      # Single-pass filter on $target:
                      #  - URI matches a declared line: keep iff full line equals
                      #    declared's version (label/path-form changes get replaced
                      #    by the to_add step below).
                      #  - URI in stale set: drop.
                      #  - Otherwise: untouched (user drag-add).
                      tmp=$(${pkgs.coreutils}/bin/mktemp)
                      ${pkgs.gawk}/bin/awk -v stale="$stale_uris" '
                        BEGIN {
                          n = split(stale, a, "\n")
                          for (i = 1; i <= n; i++) if (a[i] != "") rm[a[i]] = 1
                        }
                        NR == FNR { decl[$1] = $0; next }
                        {
                          if ($1 in decl) {
                            if ($0 == decl[$1]) print
                          } else if (!($1 in rm)) {
                            print
                          }
                        }
                      ' ${declaredFile} "$target" > "$tmp" || true
                      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$tmp" "$target"

                      # Append declared lines whose URI isn't present in target.
                      to_add_uris=$(${pkgs.coreutils}/bin/comm -23 <(uris ${declaredFile}) <(uris "$target"))
                      if [ -n "$to_add_uris" ]; then
                        printf '%s\n' "$to_add_uris" \
                          | ${pkgs.gawk}/bin/awk 'NR==FNR { want[$0]=1; next } ($1 in want) && !seen[$1]++' - ${declaredFile} \
                          | $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee -a "$target" > /dev/null
                      fi

                      $DRY_RUN_CMD install -m 0644 ${declaredFile} "$state"
                    '';
                  }
                ))

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

                  home = {
                    pointerCursor = {
                      gtk.enable = true;
                      x11.enable = true;
                      package = bibata-cursors;
                      name = "Bibata-Modern-Classic";
                      size = 24;
                    };

                    file.".config/gtk-4.0/gtk.css" = mkIf (!hasCosmicGtkTheming) {
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

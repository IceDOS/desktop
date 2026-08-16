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
        mkListOption
        mkStrListOption
        mkStrOption
        mkUsersOption
        ;

      inherit (lib) importTOML;

      inherit ((importTOML ./config.toml).icedos.desktop)
        accentColor
        autologinUser
        bookmarks
        clock
        defaultBrowser
        defaultEditor
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
      defaultBrowser = mkStrOption { default = defaultBrowser; };
      defaultEditor = mkStrOption { default = defaultEditor; };
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
          either str (submodule {
            options = {
              path = mkStrOption { };
              name = mkStrOption { default = ""; };
            };
          })
        );
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
            mapAttrs
            mkDefault
            mkForce
            mkIf
            mkMerge
            optional
            optionalAttrs
            ;

          inherit (config.icedos) desktop users;

          hasGnome = icedosLib.hasModule {
            inherit config;
            url = "github:icedos/gnome";
            modules = [ "default" ];
          };

          inherit (desktop)
            autologinUser
            defaultBrowser
            defaultEditor
            timezone
            xdg-desktop-portal
            ;

          resolved = generateAccent config;

          audioPlayer = "io.bassi.Amberol.desktop";
          browser = mkIf (defaultBrowser != "") defaultBrowser;
          editor = mkIf (defaultEditor != "") defaultEditor;

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

              # Qt Wayland decoration plugins reading the GNOME button-layout
              # dconf key, so Qt apps honor `icedos.desktop.titlebar.*`.
              qadwaitadecorations
              qadwaitadecorations-qt6
            ];

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

          home-manager.users = mapAttrs (
            user: _:
            { config, lib, ... }:
            mkMerge [
              {
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
              }

              # GNOME seeds GTK bookmarks itself; COSMIC/Hyprland don't, so
              # reconcile a declared set while leaving user bookmarks alone.
              (mkIf (!hasGnome) (
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

                  # Each extra: bare path or { path; name ? ""; }. URI keeps an
                  # existing scheme, else gets file://; label = path's last segment.
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

                  # Extras override defaults at the same URI (label wins); two
                  # extras with one URI is a config bug.
                  extrasUris = map (e: e.uri) extrasEntries;
                  duplicateUris = unique (
                    filter (uri: builtins.length (filter (x: x == uri) extrasUris) > 1) extrasUris
                  );

                  declaredEntries = filter (e: !(elem e.uri extrasUris)) defaultEntries ++ extrasEntries;

                  declaredLines = map (e: "${e.uri} ${e.label}") declaredEntries;

                  declaredFile = pkgs.writeText "icedos-gtk-bookmarks-declared" (
                    concatStringsSep "\n" declaredLines + optionalString (declaredLines != [ ]) "\n"
                  );

                  # File pickers auto-seed XDG dirs; treat them as removable so
                  # toggling off drops them even if never tracked in our state.
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

                    # Overwritable/strippable URIs = XDG dirs ∪ declared; toggling
                    # off drops them even when Nautilus seeded them first.
                    removable=$(${pkgs.coreutils}/bin/mktemp)
                    {
                      uris ${xdgUriFile}
                      if [ -f "$state" ]; then uris "$state"; fi
                    } | ${pkgs.coreutils}/bin/sort -u > "$removable"
                    stale_uris=$(${pkgs.coreutils}/bin/comm -23 "$removable" <(uris ${declaredFile}))
                    ${pkgs.coreutils}/bin/rm -f "$removable"

                    # Single pass: keep declared lines iff unchanged, drop stale
                    # URIs, leave everything else (user drag-adds) untouched.
                    tmp=$(${pkgs.coreutils}/bin/mktemp)

                    # Abort (without the mv below) if the rewrite fails, so a
                    # partial/empty temp never clobbers the real bookmarks.
                    if ! ${pkgs.gawk}/bin/awk -v stale="$stale_uris" '
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
                    ' ${declaredFile} "$target" > "$tmp"; then
                      ${pkgs.coreutils}/bin/rm -f "$tmp"
                      echo "icedos: failed to rewrite GTK bookmarks; existing file left intact" >&2
                      exit 1
                    fi
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

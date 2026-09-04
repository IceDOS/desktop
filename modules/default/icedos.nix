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
        applications
        autologinUser
        bookmarks
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

      applications = {
        audio-player = {
          package = mkStrOption { default = applications.audio-player.package; };
          name = mkStrOption { default = applications.audio-player.name; };
        };

        browser = {
          package = mkStrOption { default = applications.browser.package; };
          name = mkStrOption { default = applications.browser.name; };
        };

        editor = {
          package = mkStrOption { default = applications.editor.package; };
          name = mkStrOption { default = applications.editor.name; };
        };

        archive-manager = {
          package = mkStrOption { default = applications.archive-manager.package; };
          name = mkStrOption { default = applications.archive-manager.name; };
        };

        image-viewer = {
          package = mkStrOption { default = applications.image-viewer.package; };
          name = mkStrOption { default = applications.image-viewer.name; };
        };

        office-suite = {
          package = mkStrOption { default = applications.office-suite.package; };
          name = mkStrOption { default = applications.office-suite.name; };
        };

        torrent = {
          package = mkStrOption { default = applications.torrent.package; };
          name = mkStrOption { default = applications.torrent.name; };
        };

        video-player = {
          package = mkStrOption { default = applications.video-player.package; };
          name = mkStrOption { default = applications.video-player.name; };
        };

        wine = {
          package = mkStrOption { default = applications.wine.package; };
          name = mkStrOption { default = applications.wine.name; };
        };
      };

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
            applications
            autologinUser
            timezone
            xdg-desktop-portal
            ;

          resolved = generateAccent config;

          # Mime-wire on desktop-id alone; the package may be installed by the app's own module.
          nameOf = app: mkIf (app.name != "") app.name;
        in
        {
          icedos.desktop.users = genDefaults {
            inherit users;
          };

          warnings = optional (resolved.warning != null) resolved.warning;

          environment = {
            # Install every mime-default app; any new option under
            # `icedos.desktop.applications.*` is auto-hooked (packages resolved via icedosLib).
            systemPackages =
              icedosLib.pkgs.mapper pkgs (
                map (app: app.package) (builtins.filter (app: app.package != "") (builtins.attrValues applications))
              )
              ++ (with pkgs; [
                adwaita-icon-theme # Gtk theme
                dconf-editor # Edit gnome's dconf
                libnotify # Send desktop notifications

                # Qt Wayland decoration plugins reading the GNOME button-layout
                # dconf key, so Qt apps honor `icedos.desktop.titlebar.*`.
                qadwaitadecorations
                qadwaitadecorations-qt6
              ]);

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
                "application/json" = nameOf applications.editor;
                "application/msword" = nameOf applications.office-suite;
                "application/oxps" = nameOf applications.office-suite;
                "application/pdf" = nameOf applications.browser;
                "application/rtf" = nameOf applications.office-suite;
                "application/vnd.ms-excel" = nameOf applications.office-suite;
                "application/vnd.ms-powerpoint" = nameOf applications.office-suite;
                "application/vnd.ms-xpsdocument" = nameOf applications.office-suite;
                "application/vnd.oasis.opendocument.presentation" = nameOf applications.office-suite;
                "application/vnd.oasis.opendocument.presentation-template" = nameOf applications.office-suite;
                "application/vnd.oasis.opendocument.spreadsheet" = nameOf applications.office-suite;
                "application/vnd.oasis.opendocument.spreadsheet-template" = nameOf applications.office-suite;
                "application/vnd.oasis.opendocument.text" = nameOf applications.office-suite;
                "application/vnd.oasis.opendocument.text-template" = nameOf applications.office-suite;

                "application/vnd.openxmlformats-officedocument.presentationml.presentation" =
                  nameOf applications.office-suite;

                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" =
                  nameOf applications.office-suite;

                "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
                  nameOf applications.office-suite;

                "application/x-bittorrent" = nameOf applications.torrent;
                "application/x-ms-dos-executable" = nameOf applications.wine;
                "application/x-shellscript" = nameOf applications.editor;
                "application/x-wine-extension-ini" = nameOf applications.editor;
                "application/x-zerosize" = nameOf applications.editor;
                "application/xhtml_xml" = nameOf applications.browser;
                "application/xhtml+xml" = nameOf applications.browser;
                "application/zip" = nameOf applications.archive-manager;
                "audio/aac" = nameOf applications.audio-player;
                "audio/flac" = nameOf applications.audio-player;
                "audio/m4a" = nameOf applications.audio-player;
                "audio/mp3" = nameOf applications.audio-player;
                "audio/wav" = nameOf applications.audio-player;
                "image/avif" = nameOf applications.image-viewer;
                "image/jpeg" = nameOf applications.image-viewer;
                "image/png" = nameOf applications.image-viewer;
                "image/svg+xml" = nameOf applications.image-viewer;
                "text/csv" = nameOf applications.office-suite;
                "text/html" = nameOf applications.browser;
                "text/plain" = nameOf applications.editor;
                "text/tab-separated-values" = nameOf applications.office-suite;
                "video/mp4" = nameOf applications.video-player;
                "video/quicktime" = nameOf applications.video-player;
                "video/x-matroska" = nameOf applications.video-player;
                "video/x-ms-wmv" = nameOf applications.video-player;
                "x-scheme-handler/about" = nameOf applications.browser;
                "x-scheme-handler/http" = nameOf applications.browser;
                "x-scheme-handler/https" = nameOf applications.browser;
                "x-scheme-handler/unknown" = nameOf applications.browser;
                "x-www-browser" = nameOf applications.browser;
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

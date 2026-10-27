{ icedosLib, lib, ... }:

{
  options.icedos.desktop.bookmarks =
    let
      inherit (icedosLib) mkBoolOption mkListOption mkStrOption;
      inherit ((lib.importTOML ./config.toml).icedos.desktop) bookmarks;
    in
    {
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
          inherit (config.icedos) desktop users;

          hasGnome = icedosLib.hasModule {
            inherit config;
            url = "github:icedos/gnome";
            modules = [ "default" ];
          };
        in
        {
          icedos.system.tips.list = [
            "The folder shortcuts in your file manager come from [icedos.desktop.bookmarks]; add more with extras."
          ];

          # GNOME seeds GTK bookmarks itself; COSMIC/Hyprland don't, so
          # reconcile a declared set while leaving user bookmarks alone.
          home-manager.users = mkIf (!hasGnome) (
            mapAttrs (
              user: _:
              { config, lib, ... }:
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
            ) users
          );
        }
      )
    ];

  meta.name = "bookmarks";
}

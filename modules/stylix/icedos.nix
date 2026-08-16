{ icedosLib, lib, ... }:

{
  inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  options.icedos.desktop.stylix =
    let
      inherit (icedosLib)
        mkAttrsOption
        mkBoolOption
        mkEnumOption
        mkStrListOption
        mkStrOption
        ;

      inherit (lib) importTOML;

      inherit ((importTOML ./config.toml).icedos.desktop.stylix)
        autoEnable
        base16Scheme
        cursorTheme
        disabledTargets
        fonts
        iconTheme
        image
        polarity
        ;
    in
    {
      autoEnable = mkBoolOption { default = autoEnable; };
      base16Scheme = mkStrOption { default = base16Scheme; };
      image = mkStrOption { default = image; };

      polarity =
        mkEnumOption
          {
            path = "icedos.desktop.stylix.polarity";
            source = ./config.toml;
            default = polarity;
          }
          [
            "dark"
            "either"
            "light"
          ];

      themes = mkAttrsOption {
        default = { };

        description = ''
          Per-theme handler registry merged on top of the built-in defaults from
          ./lib.nix. Each entry has shape:
            { match              :: string -> bool;
              accentNameFromSlot :: { base0X = "name"; ... };
              iconsPackage       :: string -> string -> derivation;
              iconsDark          :: string -> string -> string; (optional; GTK
                                                                icon-theme name
                                                                for dark polarity)
              iconsLight         :: string -> string -> string; (optional; light
                                                                polarity)
              cursorPackage      :: string -> string -> derivation;
              cursorName         :: string -> string -> string;
              schemePath         :: string -> path; (optional; supplies a local
                                                    YAML when base16-schemes
                                                    lacks the named scheme) }
          First matching handler wins; unmatched schemes use a Papirus + Bibata
          fallback.
        '';
      };

      cursorTheme = mkAttrsOption { default = cursorTheme; };
      iconTheme = mkAttrsOption { default = iconTheme; };
      fonts = mkAttrsOption { default = fonts; };

      targets = mkAttrsOption {
        default = { };

        description = ''
          Per-stylix-target enable overrides, e.g. `targets.zed.enable = false`
          or `targets.feh.enable = false`. Each key is auto-routed to the
          system or home-manager plane depending on where stylix declares it;
          targets that exist on both planes (gtk, nvf) get the value on both.
        '';
      };

      disabledTargets = mkStrListOption {
        default = disabledTargets;
        description = ''
          Sugar for `targets.<name>.enable = false`. Each name is expanded to a
          full target override and routed through the same system/HM resolver
          as `targets`. Explicit `targets.<name>` entries win on conflict, so
          per-target overrides keep their full expressivity.
        '';
      };
    };

  outputs.nixosModules =
    { inputs, ... }:
    [
      { imports = [ inputs.stylix.nixosModules.stylix ]; }

      (
        {
          config,
          lib,
          options,
          pkgs,
          ...
        }:

        let
          inherit (icedosLib) generateAttrPath;

          inherit (lib)
            attrNames
            filterAttrs
            hasInfix
            hasSuffix
            listToAttrs
            mapAttrs
            mkIf
            mkMerge
            importTOML
            recursiveUpdate
            removeSuffix
            ;

          stylixLib = import ./lib.nix { inherit lib pkgs; };

          # Untyped attrs options replace defaults wholesale; re-merge TOML
          # defaults so a partial user override keeps `cfg.iconTheme.enable` resolvable.
          tomlDefaults = (importTOML ./config.toml).icedos.desktop.stylix;
          rawCfg = config.icedos.desktop.stylix;

          cfg = rawCfg // {
            cursorTheme = tomlDefaults.cursorTheme // rawCfg.cursorTheme;
            iconTheme = tomlDefaults.iconTheme // rawCfg.iconTheme;
            fonts = mapAttrs (n: d: d // (rawCfg.fonts.${n} or { })) tomlDefaults.fonts;
          };

          resolvePkg = name: generateAttrPath pkgs name;

          isPathLike = s: hasInfix "/" s || hasSuffix ".yaml" s;

          # Empty base16Scheme = Adwaita; pick the variant from polarity.
          # `polarity = "either"` collapses to dark.
          adwaitaVariant = if cfg.polarity == "light" then "light" else "dark";

          schemeName =
            if cfg.base16Scheme == "" then
              "adwaita-${adwaitaVariant}"
            else if isPathLike cfg.base16Scheme then
              removeSuffix ".yaml" (baseNameOf cfg.base16Scheme)
            else
              cfg.base16Scheme;

          mergedThemes = stylixLib.defaultThemes // cfg.themes;
          theme = stylixLib.resolveTheme mergedThemes schemeName;

          resolvedBase16Scheme =
            if isPathLike cfg.base16Scheme then
              cfg.base16Scheme
            else if theme ? schemePath then
              theme.schemePath schemeName
            else
              "${pkgs.base16-schemes}/share/themes/${schemeName}.yaml";

          resolved = icedosLib.generateAccent config;

          # Stylix hardcodes base0D for every accent surface; rewrite that line to
          # the resolved accent. Stringify: bare derivations are attrsets.
          accentPatchedBase16Scheme =
            assert (builtins.match "[0-9a-fA-F]{6}" resolved.hexNoHash != null);
            "${pkgs.runCommandLocal "icedos-base16-accent.yaml" { } ''
              cp ${resolvedBase16Scheme} $out
              chmod u+w $out
              ${pkgs.gnused}/bin/sed -i -E \
                's/(^[[:space:]]*base0D:[[:space:]]*"?#?)[0-9a-fA-F]{6}("?)/\1${resolved.hexNoHash}\2/' \
                $out
            ''}";

          # Slot inputs map to the theme's accent name (e.g. catppuccin
          # `mauve`); name/hex inputs already resolve via `resolved.name`.
          accentName =
            if resolved.slot != null then
              theme.accentNameFromSlot.${resolved.slot} or stylixLib.defaultAccentNames.${resolved.slot}
            else
              resolved.name;

          autoIconsPackage =
            if theme ? iconsPackage then
              theme.iconsPackage schemeName accentName
            else
              stylixLib.fallbackTheme.iconsPackage schemeName accentName;

          autoCursorPackage =
            if theme ? cursorPackage then
              theme.cursorPackage schemeName accentName
            else
              stylixLib.fallbackTheme.cursorPackage schemeName accentName;

          autoCursorName =
            if theme ? cursorName then
              theme.cursorName schemeName accentName
            else
              stylixLib.fallbackTheme.cursorName schemeName accentName;

          iconsPackage =
            if cfg.iconTheme.package == "" then autoIconsPackage else resolvePkg cfg.iconTheme.package;

          autoIconsDark =
            if cfg.iconTheme.dark != "" then
              cfg.iconTheme.dark
            else if theme ? iconsDark then
              theme.iconsDark schemeName accentName
            else
              "Papirus-Dark";

          autoIconsLight =
            if cfg.iconTheme.light != "" then
              cfg.iconTheme.light
            else if theme ? iconsLight then
              theme.iconsLight schemeName accentName
            else
              "Papirus-Light";

          # Tela's symbolic icons break GTK4's strict SVG renderer; build a -gtk
          # variant with svgo-repaired symbols, only for the HM gtk.iconTheme plane.
          gtkIconsPackage =
            let
              svgoFlatten = pkgs.writeText "svgo.config.cjs" ''
                module.exports = {
                  plugins: [
                    {
                      name: "preset-default",
                      params: {
                        overrides: {
                          removeViewBox: false,
                          convertShapeToPath: { convertArcs: true },
                          convertPathData: { applyTransforms: true, applyTransformsStroked: true },
                          mergePaths: false,
                        },
                      },
                    },
                  ],
                };
              '';
            in
            pkgs.runCommandLocal "${iconsPackage.name}-gtk-symbolic" { } ''
              export HOME="$TMPDIR"
              for variant in ${autoIconsDark} ${autoIconsLight}; do
                src="${iconsPackage}/share/icons/$variant"
                [ -e "$src" ] || continue
                dst="$out/share/icons/$variant-gtk"
                mkdir -p "$dst"
                # Symlink unchanged colour icons; symbolic is rebuilt below.
                for f in "$src"/*; do
                  case "$(basename "$f")" in
                    symbolic | icon-theme.cache) ;;
                    *) ln -s "$f" "$dst/" ;;
                  esac
                done
                # Deref-copy symbolic so it's writable, strip GTK4-invalid
                # attrs, then flatten transforms with one svgo folder pass.
                cp -rL "$src/symbolic" "$dst/symbolic"
                chmod -R u+w "$dst/symbolic"
                find "$dst/symbolic" -name '*.svg' -exec \
                  sed -i -E 's/ (style|class|stop-color|paint-order|stroke[a-z-]*|fill-rule)="[^"]*"//g' {} +
                ${pkgs.svgo}/bin/svgo --config ${svgoFlatten} -rf "$dst/symbolic" -o "$dst/symbolic" >/dev/null 2>&1 || true
              done
            '';

          mkFont = font: {
            inherit (font) name;
            package = resolvePkg font.package;
          };

          fontSet = font: font.name != "" && font.package != "";

          # Route each target to the plane(s) that declare it (system, HM, or
          # both like gtk/nvf) via the live option registry.
          systemTargetNames = attrNames (options.stylix.targets or { });

          bothTargetNames = [
            "gtk"
            "nvf"
          ];

          # Sugar for target disables; explicit `cfg.targets.<name>` wins on conflict.
          disabledTargetsAttrs = listToAttrs (
            map (name: {
              inherit name;
              value.enable = false;
            }) cfg.disabledTargets
          );

          mergedTargets = recursiveUpdate disabledTargetsAttrs cfg.targets;

          systemTargets = filterAttrs (n: _: builtins.elem n systemTargetNames) mergedTargets;

          hmTargets = filterAttrs (
            n: _: !(builtins.elem n systemTargetNames) || builtins.elem n bothTargetNames
          ) mergedTargets;
        in
        {
          stylix = mkMerge [
            {
              inherit (cfg) autoEnable polarity;

              enable = true;
              targets = systemTargets;
              base16Scheme = accentPatchedBase16Scheme;
            }

            # Stylix auto-picks "gnome" for qt.platform, unsupported on its own
            # qt target; pin qtct (skipped under Plasma, where qt is disabled).
            (mkIf (!config.services.desktopManager.plasma6.enable) {
              targets.qt.platform = lib.mkForce "qtct";
            })

            # Mirror the qt-target kill on the system plane: otherwise Plasma Qt
            # apps route through qt5ct (QT_QPA_PLATFORMTHEME) and half-theme.
            (mkIf config.services.desktopManager.plasma6.enable {
              targets.qt.enable = lib.mkForce false;
            })

            # The gnome target tints shell popups with base01-03 instead of
            # Adwaita greys; keep upstream gnome-shell, reattach via dconf below.
            { targets.gnome.enable = lib.mkForce false; }

            # Its overlay patches gtksourceview derivations (breaks cache);
            # ship the same xml via environment.systemPackages below instead.
            { targets.gtksourceview.enable = lib.mkForce false; }

            # The nixos-icons overlay repoints gdm's logo, rebuilding gdm +
            # gnome-shell (cache miss); keep the cached upstream logo instead.
            { targets.nixos-icons.enable = lib.mkForce false; }

            {
              cursor.name = if cfg.cursorTheme.name != "" then cfg.cursorTheme.name else autoCursorName;

              cursor.package =
                if cfg.cursorTheme.package != "" then resolvePkg cfg.cursorTheme.package else autoCursorPackage;

              cursor.size = if cfg.cursorTheme.size > 0 then cfg.cursorTheme.size else 24;
            }

            (mkIf (!cfg.iconTheme.enable) { icons.enable = false; })
            (mkIf cfg.iconTheme.enable {
              icons.enable = true;
              icons.package = iconsPackage;
              icons.dark = autoIconsDark;
              icons.light = autoIconsLight;
            })

            (mkIf (fontSet cfg.fonts.monospace) { fonts.monospace = mkFont cfg.fonts.monospace; })
            (mkIf (fontSet cfg.fonts.sansSerif) { fonts.sansSerif = mkFont cfg.fonts.sansSerif; })
            (mkIf (fontSet cfg.fonts.serif) { fonts.serif = mkFont cfg.fonts.serif; })
            (mkIf (fontSet cfg.fonts.emoji) { fonts.emoji = mkFont cfg.fonts.emoji; })

            (mkIf ((cfg.fonts.sizes.applications or 0) > 0) {
              fonts.sizes.applications = cfg.fonts.sizes.applications;
            })
          ];

          home-manager.sharedModules =
            let
              inherit (config.lib.stylix) colors;

              accentHex = resolved.hex;

              accentFgHex = "#${if config.stylix.polarity == "light" then colors.base00 else colors.base07}";

              isLight = config.stylix.polarity == "light";

              systemPlasma6 = config.services.desktopManager.plasma6.enable;

              # Stylix hardcodes [Colors:Selection] foregrounds to base00 (black
              # on accent); patch them to the real accent fg (base07/base00) below.
              kdeSelectionFgSlot = if isLight then "base00" else "base07";

              kdeSelectionFgRgb = lib.concatMapStringsSep "," (c: colors."${kdeSelectionFgSlot}-rgb-${c}") [
                "r"
                "g"
                "b"
              ];

              # Mirrors stylix's own colorschemeSlug derivation (modules/kde/hm.nix).
              kdeColorschemeSlug = lib.concatStrings (
                lib.filter lib.isString (builtins.split "[^a-zA-Z]" colors.scheme)
              );

              # Stylix's gtk target only writes theme_*_color, collapsing
              # libadwaita's named colors; map each to its base16 slot.
              libadwaitaCss = ''
                @define-color window_bg_color #${colors.base01};
                @define-color window_fg_color #${colors.base05};

                @define-color view_bg_color #${colors.base00};
                @define-color view_fg_color #${colors.base05};

                @define-color headerbar_bg_color #${colors.base02};
                @define-color headerbar_fg_color #${colors.base05};
                @define-color headerbar_border_color ${
                  if isLight then "rgba(0, 0, 0, 0.07)" else "rgba(0, 0, 0, 0.36)"
                };
                @define-color headerbar_backdrop_color #${colors.base01};
                @define-color headerbar_shade_color rgba(0, 0, 0, 0.36);

                @define-color sidebar_bg_color #${colors.base02};
                @define-color sidebar_fg_color #${colors.base05};
                @define-color sidebar_backdrop_color #${colors.base01};
                @define-color sidebar_border_color ${
                  if isLight then "rgba(0, 0, 0, 0.07)" else "rgba(0, 0, 0, 0.36)"
                };
                @define-color sidebar_shade_color rgba(0, 0, 0, 0.25);

                @define-color secondary_sidebar_bg_color #${colors.base02};
                @define-color secondary_sidebar_fg_color #${colors.base05};
                @define-color secondary_sidebar_backdrop_color #${colors.base01};
                @define-color secondary_sidebar_border_color ${
                  if isLight then "rgba(0, 0, 0, 0.07)" else "rgba(0, 0, 0, 0.36)"
                };
                @define-color secondary_sidebar_shade_color rgba(0, 0, 0, 0.25);

                @define-color popover_bg_color #${colors.base03};
                @define-color popover_fg_color #${colors.base05};
                @define-color popover_shade_color rgba(0, 0, 0, 0.25);

                @define-color dialog_bg_color #${colors.base03};
                @define-color dialog_fg_color #${colors.base05};

                @define-color card_bg_color ${if isLight then "#${colors.base00}" else "rgba(255, 255, 255, 0.08)"};
                @define-color card_fg_color #${colors.base05};
                @define-color card_shade_color rgba(0, 0, 0, 0.36);

                @define-color thumbnail_bg_color #${colors.base02};
                @define-color thumbnail_fg_color #${colors.base05};

                @define-color shade_color rgba(0, 0, 0, 0.32);
                @define-color scrollbar_outline_color rgba(0, 0, 0, 0.5);

                @define-color destructive_bg_color #${colors.base08};
                @define-color destructive_fg_color #${colors.base07};
                @define-color destructive_color @destructive_bg_color;

                @define-color success_bg_color #${colors.base0B};
                @define-color success_fg_color #${colors.base07};
                @define-color success_color @success_bg_color;

                @define-color warning_bg_color #${colors.base0A};
                @define-color warning_fg_color #${colors.base07};
                @define-color warning_color @warning_bg_color;

                @define-color error_bg_color #${colors.base08};
                @define-color error_fg_color #${colors.base07};
                @define-color error_color @error_bg_color;
              '';

              gtkCss = ''
                ${libadwaitaCss}

                @define-color accent_fg_color ${accentFgHex};

                /* Chromium reads accent fg from these treeview selectors
                   (ui/gtk/gtk_color_mixers.cc); give it a contrasting label. */
                treeview.view treeview.view.cell:selected:focus,
                treeview.view treeview.view.cell:selected:focus label {
                  background-color: ${accentHex};
                  color: ${accentFgHex};
                }

                :root {
                  --accent-bg-color: @accent_bg_color;
                  --accent-fg-color: @accent_fg_color;
                }
              '';

            in
            [
              {
                stylix.targets = mkMerge [
                  hmTargets
                  { gtk.extraCss = gtkCss; }
                ];
              }

              # Point the GTK icon-theme plane at the repaired -gtk variant (dconf
              # follows the name); keep the full theme for Plasma/COSMIC resolution.
              (
                { config, lib, ... }:
                lib.mkIf cfg.iconTheme.enable {
                  gtk.iconTheme.package = lib.mkForce gtkIconsPackage;
                  gtk.iconTheme.name = lib.mkForce "${
                    if config.stylix.polarity == "light" then autoIconsLight else autoIconsDark
                  }-gtk";
                  home.packages = [ iconsPackage ];
                }
              )

              # HM-plane mirror: the system mkForce doesn't reach the user-plane
              # target writing gnome-shell.css / the user-theme dconf key.
              { stylix.targets.gnome.enable = lib.mkForce false; }

              # HM-plane mirror: its HM target writes stylix.xml via xdg.dataFile;
              # the system copy (environment.systemPackages) makes it redundant.
              { stylix.targets.gtksourceview.enable = lib.mkForce false; }

              # Ship the selection-fixed scheme at XDG_DATA_HOME so it beats
              # stylix's profile copy; only [Colors:Selection] fg is rewritten.
              (
                { config, ... }:
                lib.mkIf systemPlasma6 {
                  home.file.".local/share/color-schemes/${kdeColorschemeSlug}.colors".source =
                    let
                      stylixKdeTheme = lib.findFirst (p: lib.getName p == "stylix-kde-theme") null config.home.packages;

                      patched = pkgs.runCommandLocal "stylix-kde-selection-fix" { } ''
                        mkdir --parents "$out/share/color-schemes"
                        ${pkgs.gawk}/bin/awk -v fg='${kdeSelectionFgRgb}' '
                          /^\[/ { sel = ($0 == "[Colors:Selection]") }
                          sel && /^Foreground(Normal|Active|Inactive|Link|Visited)=/ { sub(/=.*/, "=" fg) }
                          { print }
                        ' "${stylixKdeTheme}/share/color-schemes/${kdeColorschemeSlug}.colors" \
                          > "$out/share/color-schemes/${kdeColorschemeSlug}.colors"
                      '';
                    in
                    "${patched}/share/color-schemes/${kdeColorschemeSlug}.colors";
                }
              )

              # Under Plasma the HM qt target exports QT_STYLE_OVERRIDE=kvantum,
              # which QQC2 can't import (no QQC2 module); Plasma owns Qt theming.
              (mkIf config.services.desktopManager.plasma6.enable {
                stylix.targets.qt.enable = lib.mkForce false;
              })

              # Reattach dconf bits the gnome target used to set (color-scheme,
              # wallpaper); accent-color stays owned by the gnome module.
              {
                dconf.settings = {
                  "org/gnome/desktop/interface" = {
                    color-scheme = if cfg.polarity == "light" then "default" else "prefer-dark";
                  };
                }
                // (
                  if cfg.image != "" then
                    {
                      "org/gnome/desktop/background" = {
                        picture-uri = "file://${cfg.image}";
                        picture-uri-dark = "file://${cfg.image}";
                      };
                    }
                  else
                    { }
                );
              }
            ];
        }
      )
    ];

  meta.name = "stylix";
}

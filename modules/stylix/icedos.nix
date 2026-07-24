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
        enable
        fonts
        iconTheme
        image
        polarity
        ;
    in
    {
      enable = mkBoolOption { default = enable; };
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

          # Untyped attrs options replace defaults wholesale on user override,
          # so re-merge module TOML defaults with the user's partial value to
          # keep `cfg.iconTheme.enable` etc. resolvable when the user only sets
          # a subset of keys.
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

          # Stylix targets hardcode `base0D` (the base16 "function name" slot)
          # for every accent surface — vscode button bg, zed link colors,
          # kvantum highlight, gtk treeview selection, etc. When the user
          # picks an accent that doesn't happen to live on base0D (slot
          # mismatch, named accent, raw hex) the palette's blue still wins on
          # those surfaces and the override is invisible. Patch the resolved
          # YAML once at the source: rewrite the `base0D` line to the
          # resolved accent hex. All stylix targets re-derive their values
          # from `config.lib.stylix.colors.base0D` so this propagates
          # everywhere without per-target post-processing.
          #
          # Stringify the derivation: `stylix.base16Scheme` accepts either an
          # attrset (parsed scheme) or a path. A bare derivation is an
          # attrset in Nix, so passing the derivation directly trips
          # base16.nix's `isAttrs` branch and parsing fails. Interpolating
          # forces path-string treatment.
          accentPatchedBase16Scheme = "${pkgs.runCommandLocal "icedos-base16-accent.yaml" { } ''
            cp ${resolvedBase16Scheme} $out
            chmod u+w $out
            ${pkgs.gnused}/bin/sed -i -E \
              's/(^[[:space:]]*base0D:[[:space:]]*"?#?)[0-9a-fA-F]{6}("?)/\1${resolved.hexNoHash}\2/' \
              $out
          ''}";

          # Slot-input under stylix gets the theme-specific accent name (e.g.
          # catppuccin's `mauve`/`flamingo`). Name and hex inputs already
          # produce a libadwaita name in `resolved.name` and don't need
          # theme-aware remapping — the theme handlers' icon / cursor
          # packages still take that name and the package's name-resolver
          # decides whether to honour or fallback.
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

          # GTK4's strict symbolic-SVG renderer ignores <g> and rejects invalid
          # attrs, so ~325 of Tela's symbolic icons (path wrapped in
          # <g transform> -> drawn off the 16x16 viewBox; or stray stop-color /
          # stroke attrs -> conversion fails) render blank in libadwaita apps
          # (LACT etc.) under stylix, which forces Tela as the GTK icon theme.
          # (KDE/Qt have a tolerant icon engine, so Tela works there; without
          # stylix the GTK theme is breeze/Adwaita, already GTK-clean.)
          #
          # Build a GTK-only variant ("<name>-gtk") that keeps Tela's colour
          # icons, and repairs the symbolic ones in place with one svgo folder
          # pass: strip the bad attrs, flatten transforms into path coords ->
          # keeps the Tela glyph, renders in GTK4. ~1378/1534 repair cleanly
          # (incl. every window/dialog/+- control + sidebar glyph); the ~156
          # svgo can't flatten (rect/matrix combos) stay blank, but they're
          # obscure status/app icons absent from GTK app chrome. Point ONLY the
          # HM gtk.iconTheme plane at it (below); Plasma (kdeglobals) and COSMIC
          # (toolkit RON) keep full Tela, and the distinct -gtk name stops the
          # variant shadowing Tela for Qt. No nixpkgs derivation is patched, so
          # cache hits are preserved (same rationale as the gtksourceview /
          # nixos-icons disables above).
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
                # Colour icons + index.theme: symlink (unchanged Tela). Drop the
                # symbolic/ symlink + stale cache; symbolic is rebuilt below.
                for f in "$src"/*; do
                  case "$(basename "$f")" in
                    symbolic | icon-theme.cache) ;;
                    *) ln -s "$f" "$dst/" ;;
                  esac
                done
                # Symbolic: real (deref) copy so it's writable, strip the
                # GTK4-invalid attrs, then flatten transforms into path coords
                # with one svgo folder pass.
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

          # Stylix splits targets between system-level (`feh`, `sddm`, ...) and
          # the per-user home-manager plane (`zed`, `vscode`, ...). A small set
          # lives on both (`gtk`, `nvf`). Use the live system option registry
          # to route each user-supplied `cfg.targets.<x>` to whichever plane(s)
          # actually declare that target, so users don't have to know which is
          # which.
          systemTargetNames = attrNames (options.stylix.targets or { });

          bothTargetNames = [
            "gtk"
            "nvf"
          ];

          # `disabledTargets` is sugar; recursiveUpdate lets explicit `cfg.targets.<name>` win on conflict.
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
        mkIf cfg.enable {
          stylix = mkMerge [
            {
              inherit (cfg) autoEnable polarity;

              enable = true;
              targets = systemTargets;
              base16Scheme = accentPatchedBase16Scheme;
            }

            # Stylix auto-detects gnome and sets `qt.platform = "gnome"`,
            # which (a) is unsupported on stylix's own qt HM target (only
            # `qtct` works) and (b) maps to the deprecated nixpkgs value
            # `qt.platformTheme.name = "gnome"`. Pin to qtct to silence
            # both warnings and route Qt apps through the supported path.
            # (Skipped under Plasma — the qt target is disabled there, below.)
            (mkIf (!config.services.desktopManager.plasma6.enable) {
              targets.qt.platform = lib.mkForce "qtct";
            })

            # NixOS-plane mirror of the HM-plane qt-target kill further down.
            # Stylix ships a SECOND qt target on the system plane
            # (`modules/qt/nixos.nix`); the HM `mkForce false` doesn't reach it,
            # so under Plasma it stayed enabled and — because the `qtct` pin
            # above overrode its plasma6 auto-pick of "kde" — set
            # `qt.platformTheme = "qt5ct"`, exporting `QT_QPA_PLATFORMTHEME=qt5ct`
            # into the session. That routed every Qt app through qt5ct instead
            # of Plasma's KDE platform theme, so QtQuick/Kirigami apps (System
            # Settings, Discover) fell back to the light QQC2 style while QWidget
            # apps (Dolphin) read the dark palette — half-themed. Plasma owns Qt
            # theming via the `kde` target + plasma-integration, so disable this
            # plane too; with no `QT_QPA_PLATFORMTHEME` override the KDE platform
            # theme loads automatically and QQC2 uses `org.kde.desktop`.
            (mkIf config.services.desktopManager.plasma6.enable {
              targets.qt.enable = lib.mkForce false;
            })

            # Stylix's `gnome` target rewrites the entire gnome-shell theme
            # via a base16-mustache SCSS render, plus patches gnome-shell to
            # drop the Dark Style toggle. That tints every panel popup
            # (calendar, notifications, app-grid, language menu, ...) with
            # base01/base02/base03 instead of upstream Adwaita greys, which
            # ends up looking off across most of the shell. Disable the
            # target on both NixOS and home-manager planes so gnome-shell
            # renders with its bundled upstream Adwaita theme. Stylix's
            # accent / dark-mode / wallpaper integration is reattached via
            # dconf below. The `gtk` target stays on for libadwaita apps.
            { targets.gnome.enable = lib.mkForce false; }

            # Stylix's `gtksourceview` target ships an overlay that patches
            # all four gtksourceview variants (`gnome2.gtksourceview`,
            # `gtksourceview`, `gtksourceview4`, `gtksourceview5`) to drop
            # a generated `stylix.xml` color scheme into
            # `share/gtksourceview-<v>/styles/`. Patching the derivations
            # breaks cache hits and forces every dependent (gnome-calculator,
            # gnome-text-editor, gnome-builder, gedit, meld, ...) to rebuild
            # on every config change. Disable the target on both planes; the
            # same xml is installed via `environment.systemPackages` below
            # using the upstream mustache template + base16 renderer so the
            # feature stays without mutating any nixpkgs derivation.
            { targets.gtksourceview.enable = lib.mkForce false; }

            # Stylix's `nixos-icons` overlay recolours the NixOS snowflake to
            # the active scheme and embeds it as the GDM greeter logo via gdm's
            # `org.gnome.login-screen.gschema.override`. That repoints the
            # override at the overlaid nixos-icons store path, changing the
            # `gdm` derivation. gnome-shell build-depends on gdm (libgdm), so
            # gnome-shell rebuilds, and gnome-session / gnome-initial-setup /
            # gnome-tweaks / gnome-browser-connector cascade — none cached,
            # forcing a full local GNOME-stack compile on every nixpkgs bump.
            # Disable the target so the greeter keeps the cached upstream logo
            # and the GNOME closure substitutes from cache. (Same cache
            # rationale as the gnome / gtksourceview disables above.)
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

              # Stylix's KDE target hardcodes the Plasma color scheme's
              # [Colors:Selection] foregrounds to base00 (dark), so selected
              # list items / highlighted text paint black on the accent fill
              # instead of the accent-foreground used everywhere else (the GTK
              # path gets accentFgHex below). Recompute that accent foreground
              # as an "R,G,B" triple — base07 on dark, base00 on light, the
              # same slot accentFgHex uses — and patch only that section of
              # stylix's generated `.colors`, shipped at XDG_DATA_HOME priority
              # below so it overrides the read-only profile copy.
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

              # libadwaita's named-color set drives every modern GTK4 app's
              # surfaces (Files, Console, Settings, Calendar, Calculator, ...).
              # Stylix's stock gtk target only writes the older `theme_*_color`
              # family, so without these explicit overrides every libadwaita
              # surface collapses to a single fallback and the
              # sidebar/headerbar/view hierarchy disappears. Map each named
              # color to the corresponding base16 slot so the hierarchy follows
              # the active palette regardless of which scheme is selected.
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

                /* Chromium reads accent foreground from these GTK treeview
                   selectors (see chromium/src ui/gtk/gtk_color_mixers.cc).
                   Override so chromium browsers get a
                   contrasting label on accent buttons. */
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

              # GTK-plane-only symbolic icon fix: repoint gtk.iconTheme (set by
              # stylix/hm/icons.nix) at the Adwaita-symbolic variant so
              # libadwaita apps get GTK4-clean symbolic SVGs. dconf icon-theme
              # and gtk-{3,4}.0/settings.ini follow the name automatically.
              # Re-add the FULL theme to home.packages: repointing
              # gtk.iconTheme.package was the only thing installing it under
              # stylix, and Plasma (kdeglobals) + COSMIC (toolkit RON) still
              # resolve "Tela-black-dark" by name, so it must stay on the path.
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

              # HM-plane mirror of the system disable above. Stylix declares
              # `targets.gnome.enable` separately on the user plane, so the
              # mkForce on system doesn't reach the HM activation that writes
              # `themes/Stylix/gnome-shell/gnome-shell.css` and the
              # user-theme dconf key. Disable here too.
              { stylix.targets.gnome.enable = lib.mkForce false; }

              # HM-plane mirror of the system gtksourceview disable. Stylix's
              # `gtksourceview` HM target writes the rendered `stylix.xml`
              # into `~/.local/share/gtksourceview-<v>/styles/` via
              # `xdg.dataFile`; the mkForce on system doesn't reach that
              # activation, so disable on HM too. The replacement xml is
              # shipped system-wide via `environment.systemPackages` above
              # so HM-plane delivery is redundant anyway.
              { stylix.targets.gtksourceview.enable = lib.mkForce false; }

              # Ship the selection-fixed Plasma color scheme at XDG_DATA_HOME
              # priority so plasma-apply-lookandfeel resolves it ahead of the
              # stylix profile copy (same slug). Reuses stylix's own generated
              # `.colors` and rewrites only the [Colors:Selection] foregrounds,
              # so any other stylix color stays authoritative. Plasma 6 only.
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

              # HM-plane qt target kill under Plasma 6. Stylix's HM qt target
              # hardcodes `qt.style.name = "kvantum"` → exports
              # QT_STYLE_OVERRIDE=kvantum into ~/.config/environment.d. Plasma 6's
              # QQC2 then `import kvantum` in every plasmashell/kwin/spectacle QML,
              # fails ("module kvantum is not installed" — nixpkgs ships only the
              # kvantum Qt Widgets style, no QQC2 module) and plasmashell never
              # paints. Plasma owns Qt theming via the `kde` target + plasma-apply-*,
              # so the qt target is redundant under Plasma anyway.
              (mkIf config.services.desktopManager.plasma6.enable {
                stylix.targets.qt.enable = lib.mkForce false;
              })

              # Reattach the dconf bits stylix's gnome target used to set:
              # - color-scheme: follow stylix polarity.
              # - wallpaper: when stylix.image is set.
              # `accent-color` is owned by the gnome module (single writer
              # to avoid double-definition when both modules are active);
              # it reads `icedosLib.generateAccent` for the resolved name.
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

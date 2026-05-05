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

      inherit (lib) readFile;

      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop.stylix)
        accentBase16Slot
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

      polarity = mkEnumOption { default = polarity; } [
        "dark"
        "either"
        "light"
      ];

      accentBase16Slot =
        mkEnumOption
          {
            default = accentBase16Slot;
            description = ''
              The base16 slot treated as the highlight/accent color. Shared source of
              truth for themed components that understand accents.
            '';
          }
          [
            "base08"
            "base09"
            "base0A"
            "base0B"
            "base0C"
            "base0D"
            "base0E"
            "base0F"
          ];

      themes = mkAttrsOption {
        default = { };

        description = ''
          Per-theme handler registry merged on top of the built-in defaults from
          ./lib.nix. Each entry has shape:
            { match              :: string -> bool;
              accentNameFromSlot :: { base0X = "name"; ... };
              iconsPackage       :: string -> string -> derivation;
              cursorPackage      :: string -> string -> derivation;
              cursorName         :: string -> string -> string; }
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
            readFile
            recursiveUpdate
            removeSuffix
            ;

          stylixLib = import ./lib.nix { inherit lib pkgs; };

          # Untyped attrs options replace defaults wholesale on user override,
          # so re-merge module TOML defaults with the user's partial value to
          # keep `cfg.iconTheme.enable` etc. resolvable when the user only sets
          # a subset of keys.
          tomlDefaults = (fromTOML (readFile ./config.toml)).icedos.desktop.stylix;
          rawCfg = config.icedos.desktop.stylix;

          cfg = rawCfg // {
            cursorTheme = tomlDefaults.cursorTheme // rawCfg.cursorTheme;
            iconTheme = tomlDefaults.iconTheme // rawCfg.iconTheme;
            fonts = mapAttrs (n: d: d // (rawCfg.fonts.${n} or { })) tomlDefaults.fonts;
          };

          resolvePkg = name: generateAttrPath pkgs name;

          isPathLike = s: hasInfix "/" s || hasSuffix ".yaml" s;

          schemeName =
            if cfg.base16Scheme == "" then
              "edge-dark"
            else if isPathLike cfg.base16Scheme then
              removeSuffix ".yaml" (baseNameOf cfg.base16Scheme)
            else
              cfg.base16Scheme;

          resolvedBase16Scheme =
            if cfg.base16Scheme == "" then
              "${pkgs.base16-schemes}/share/themes/edge-dark.yaml"
            else if isPathLike cfg.base16Scheme then
              cfg.base16Scheme
            else
              "${pkgs.base16-schemes}/share/themes/${cfg.base16Scheme}.yaml";

          mergedThemes = stylixLib.defaultThemes // cfg.themes;
          theme = stylixLib.resolveTheme mergedThemes schemeName;

          accentName =
            theme.accentNameFromSlot.${cfg.accentBase16Slot}
              or stylixLib.defaultAccentNames.${cfg.accentBase16Slot};

          autoIconsPackage = theme.iconsPackage schemeName accentName;
          autoCursorPackage = theme.cursorPackage schemeName accentName;
          autoCursorName = theme.cursorName schemeName accentName;

          iconsPackage =
            if cfg.iconTheme.package == "" then autoIconsPackage else resolvePkg cfg.iconTheme.package;

          autoIconsDark = if cfg.iconTheme.dark != "" then cfg.iconTheme.dark else "Papirus-Dark";
          autoIconsLight = if cfg.iconTheme.light != "" then cfg.iconTheme.light else "Papirus-Light";

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
              enable = true;
              inherit (cfg) autoEnable polarity;
              targets = systemTargets;

              base16Scheme = resolvedBase16Scheme;

              image = if cfg.image != "" then cfg.image else config.lib.stylix.pixel "base0A";
            }

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
          ];

          home-manager.sharedModules =
            let
              accentHex = "#${config.lib.stylix.colors.${cfg.accentBase16Slot}}";

              accentFgHex = "#${
                if config.stylix.polarity == "light" then
                  config.lib.stylix.colors.base00
                else
                  config.lib.stylix.colors.base07
              }";

              gtkCss = ''
                @define-color accent_bg_color ${accentHex};
                @define-color accent_color @accent_bg_color;
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
                # User-supplied home-manager-side and dual-plane targets, plus
                # our gtk extraCss override. mkMerge is needed (not `//`) so a
                # user-set `targets.gtk.enable = false` doesn't get clobbered by
                # the gtk.extraCss assignment — `//` is a shallow attrset merge
                # and would replace the whole `gtk` subtree. Stylix ignores
                # gtk.gtk{3,4}.extraCss; using its own extraCss hook keeps
                # libadwaita widgets on the stylix accent slot instead of
                # libadwaita's blue.
                stylix.targets = mkMerge [
                  hmTargets
                  { gtk.extraCss = gtkCss; }
                ];
              }
            ];
        }
      )
    ];

  meta.name = "stylix";
}

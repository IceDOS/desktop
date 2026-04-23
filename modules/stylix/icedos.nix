{ icedosLib, lib, ... }:

{
  inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  options.icedos.desktop.stylix =
    let
      inherit (icedosLib) mkBoolOption mkStrOption;
      inherit (lib) mkOption readFile types;

      inherit ((fromTOML (readFile ./config.toml)).icedos.desktop.stylix)
        accentBase16Slot
        autoEnable
        base16Scheme
        cursorTheme
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

      polarity = mkOption {
        type = types.enum [
          "dark"
          "either"
          "light"
        ];
        default = polarity;
      };

      accentBase16Slot = mkOption {
        type = types.enum [
          "base08"
          "base09"
          "base0A"
          "base0B"
          "base0C"
          "base0D"
          "base0E"
          "base0F"
        ];
        default = accentBase16Slot;
        description = ''
          The base16 slot treated as the highlight/accent color. Shared source of
          truth for themed components that understand accents.
        '';
      };

      themes = mkOption {
        type = types.attrs;
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

      cursorTheme = mkOption {
        type = types.attrs;
        default = cursorTheme;
      };

      iconTheme = mkOption {
        type = types.attrs;
        default = iconTheme;
      };

      fonts = mkOption {
        type = types.attrs;
        default = fonts;
      };

      targets = mkOption {
        type = types.attrs;
        default = { };
        description = "Overrides for stylix.targets.<name>.enable (escape hatch).";
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
          pkgs,
          ...
        }:

        let
          inherit (icedosLib) generateAttrPath;
          inherit (lib)
            hasInfix
            hasSuffix
            mapAttrs
            mkIf
            mkMerge
            readFile
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
        in
        mkIf cfg.enable {
          stylix = mkMerge [
            {
              enable = true;
              inherit (cfg) autoEnable polarity targets;

              base16Scheme = resolvedBase16Scheme;

              image = if cfg.image != "" then cfg.image else config.lib.stylix.pixel "base0A";
            }

            {
              cursor.name = if cfg.cursorTheme.name != "" then cfg.cursorTheme.name else autoCursorName;
              cursor.package =
                if cfg.cursorTheme.package != "" then
                  resolvePkg cfg.cursorTheme.package
                else
                  autoCursorPackage;
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

          home-manager.users =
            let
              accentHex = "#${config.lib.stylix.colors.${cfg.accentBase16Slot}}";
              gtkCss = ''
                @define-color accent_bg_color ${accentHex};
                @define-color accent_color @accent_bg_color;

                :root {
                  --accent-bg-color: @accent_bg_color;
                }
              '';
            in
            mapAttrs (_: _: {
              # Stylix ignores gtk.gtk{3,4}.extraCss; use its own extraCss hook so
              # our @accent_bg_color override is appended to the stylix-generated
              # gtk.css. Keeps libadwaita widgets (sliders, toggles, focus rings)
              # matching the stylix accent slot instead of libadwaita's blue.
              stylix.targets.gtk.extraCss = gtkCss;
            }) config.icedos.users;
        }
      )
    ];

  meta.name = "stylix";
}

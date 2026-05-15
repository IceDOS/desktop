{ inputs, ... }:

{
  home-manager.sharedModules = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:

      let
        cfg = config.stylix.targets.vscodium;
      in
      {
        options.stylix.targets.vscodium = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.stylix.autoEnable or true;
            description = "Whether to style VSCodium.";
          };

          profileNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "default" ];
            description = "The VSCodium profile names to apply styling on.";
          };
        };

        config = lib.mkIf ((config.stylix.enable or false) && cfg.enable) (
          let
            colors = config.lib.stylix.colors;
            fonts = config.stylix.fonts;

            themeExtension =
              pkgs.runCommandLocal "stylix-vscodium"
                {
                  vscodeExtUniqueId = "stylix.stylix";
                  vscodeExtPublisher = "stylix";
                  version = "0.0.0";
                  theme = builtins.toJSON (import "${inputs.stylix}/modules/vscode/templates/theme.nix" colors);
                  passAsFile = [ "theme" ];
                }
                ''
                  mkdir -p "$out/share/vscode/extensions/$vscodeExtUniqueId/themes"
                  ln -s ${inputs.stylix}/modules/vscode/package.json \
                    "$out/share/vscode/extensions/$vscodeExtUniqueId/package.json"
                  cp "$themePath" \
                    "$out/share/vscode/extensions/$vscodeExtUniqueId/themes/stylix.json"
                '';

            # Stylix's vscode theme sets `button.foreground = base00` (dark bg
            # colour). On the accent-coloured button background that's poor
            # contrast in dark polarity. Force white text on buttons.
            buttonContrastCustomizations = {
              "button.foreground" = "#ffffff";
              "button.secondaryForeground" = "#ffffff";
            };

            stylixUserSettings = import "${inputs.stylix}/modules/vscode/templates/settings.nix" fonts;
          in
          {
            warnings = lib.optional (config.programs.vscodium.enable && cfg.profileNames == [ ]) ''
              stylix: vscodium: `config.stylix.targets.vscodium.profileNames` is empty.
              No theming will be applied. Add a profile or disable this warning by setting
              `stylix.targets.vscodium.enable = false`.
            '';

            programs.vscodium.profiles = lib.genAttrs cfg.profileNames (_: {
              extensions = [ themeExtension ];
              userSettings = stylixUserSettings // {
                "workbench.colorCustomizations" = buttonContrastCustomizations;
              };
            });
          }
        );
      }
    )
  ];
}

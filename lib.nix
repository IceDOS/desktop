# Desktop/DE-dependent helpers (accent resolution, button-layout, session
# targets), contributed into the module-facing icedosLib by the default module.
{
  icedosLib,
  lib,
  ...
}:
let
  inherit (builtins)
    attrNames
    match
    substring
    ;

  inherit (lib)
    concatStringsSep
    elem
    optional
    removePrefix
    toLower
    toUpper
    ;

  inherit (icedosLib) hasModule;
in
rec {
  # libadwaita named-accent → hex map (mirrors GNOME 47+ accent-color enum);
  # bare hex (no `#`) so callers can pick the form.
  libadwaitaAccentHex = {
    blue = "3584e4";
    green = "3a944a";
    orange = "ed5b00";
    pink = "d56199";
    purple = "9141ac";
    red = "e62d42";
    slate = "6f8396";
    teal = "2190a4";
    yellow = "c88800";
  };

  # Single source of truth for `icedos.desktop.accentColor`: libadwaita name,
  # base16 slot, or hex; empty → "purple". Returns { hex; hexNoHash; name; slot; warning; gnomeOn; }.
  generateAccent =
    config:
    let
      desktopCfg = config.icedos.desktop;
      raw = desktopCfg.accentColor;

      gnomeOn = hasModule {
        inherit config;
        url = "github:icedos/gnome";
        modules = [ "default" ];
      };

      namedAccents = attrNames libadwaitaAccentHex;

      # Slot → libadwaita name (for the GNOME dconf write); mirrors the
      # `adwaita` handler in desktop/modules/stylix/lib.nix.
      defaultSlotToName = {
        base08 = "red";
        base09 = "orange";
        base0A = "yellow";
        base0B = "green";
        base0C = "teal";
        base0D = "blue";
        base0E = "purple";
        base0F = "slate";
      };

      isHex = s: match "#?[0-9a-fA-F]{6}" s != null;
      isName = s: elem (toLower s) namedAccents;
      isSlot = s: match "base0[89A-Fa-f]" s != null;

      input = if raw == "" then "purple" else raw;

      # Normalise slots to uppercase (`base0A`): stylix colors and the
      # accentNameFromSlot maps are keyed with the uppercase form.
      slotInput = if isSlot input then "base0${toUpper (substring 5 1 input)}" else null;

      name =
        if isName input then
          toLower input
        else if isSlot input then
          defaultSlotToName.${slotInput} or "blue"
        else
          "blue";

      hexNoHash =
        if isHex input then
          removePrefix "#" input
        else if isSlot input then
          config.lib.stylix.colors.${slotInput}
        else
          libadwaitaAccentHex.${name};

      hex = "#${hexNoHash}";

      slot = slotInput;

      warning =
        if gnomeOn && !(isName input) then
          "icedos.desktop.accentColor: GNOME is enabled but `${input}` is not a libadwaita named accent. The GNOME shell will use `${name}`; libadwaita apps and other consumers will use `${hex}`. Set accentColor to one of ${concatStringsSep ", " namedAccents} to keep them in sync."
        else
          null;
    in
    {
      inherit
        hex
        hexNoHash
        name
        slot
        warning
        gnomeOn
        ;
    };

  desktop = {
    # GNOME button-layout string from per-button flags (also parsed by Zed's
    # title_bar.button_layout); close is always present.
    mkButtonLayoutString =
      {
        minimizeButton,
        maximizeButton,
        ...
      }:
      let
        # Close is always present (no opt-out): semantically required, and
        # several compositors (COSMIC) ignore hide-close anyway.
        buttons = concatStringsSep "," (
          optional minimizeButton "minimize" ++ optional maximizeButton "maximize" ++ [ "close" ]
        );
      in
      "appmenu:${buttons}";

    # Active accent as 6-char hex (no `#`) for per-WM modules (focused-window
    # borders / active-hint indicators); wraps `generateAccent`.
    accentHex = config: (generateAccent config).hexNoHash;
  };

  systemd = {
    # *-session.target names for present DE repos (via `hasModule`), for
    # systemd.user.services' Unit.After / Install.WantedBy.
    desktopSessionTargets =
      config:
      let
        present =
          name:
          hasModule {
            inherit config;
            url = "github:icedos/${name}";
            modules = [ "default" ];
          };
      in
      optional (present "cosmic") "cosmic-session.target"
      ++ optional (present "gnome") "gnome-session.target"
      ++ optional (present "hyprland") "hyprland-session.target"
      ++ optional (present "kde") "plasma-workspace-wayland.target";
  };
}

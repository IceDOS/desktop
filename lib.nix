# Repo-root `lib.nix`: the desktop/DE-dependent helpers that used to live in
# core (libadwaita accent resolution, the GNOME button-layout string, per-DE
# session targets). The always-on `default` module imports this via its
# top-level `lib` field (`modules/default/icedos.nix`:
# `lib = import ../../lib.nix { inherit icedosLib lib; };`), and core merges
# that field into the module-facing `icedosLib` over the resolved closure — so
# this repo contributes even when pulled in as a dependency (every DE repo
# declares desktop as a **required** dependency for exactly this reason).
#
# A contribution sees only the BASE `icedosLib` (core helpers like
# `hasModule`), never the merged lib: the merge's construction depends on
# importing this very file, so handing it the merged value would be an
# infinite recursion. Cross-repo composition happens at the module layer.
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
  # Authoritative libadwaita named-accent → hex map. Mirrors GNOME 47+
  # `org/gnome/desktop/interface.accent-color` enum and libadwaita's
  # `_palette.scss`. Bare hex (no `#`) so callers can pick the form.
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

  # Single source of truth for `icedos.desktop.accentColor` resolution.
  # Accepts a libadwaita name, a base16 slot (`base08`..`base0F`, only
  # meaningful when stylix is on), or a hex (`RRGGBB` / `#RRGGBB`).
  # Empty → "purple". Returns:
  #   { hex; hexNoHash; name; slot; warning; gnomeOn; stylixOn; }
  # `warning` is non-null when GNOME is on but the input is not a libadwaita
  # named accent — `org/gnome/desktop/interface.accent-color` is a string
  # enum, so a slot/hex input causes the GNOME shell to render a fallback
  # name while libadwaita apps render the user's hex.
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

      stylixOn = config.stylix.enable or false;

      namedAccents = attrNames libadwaitaAccentHex;

      # base16 slot inverse — only used when input is a slot and we still
      # need a libadwaita name (e.g. for the GNOME dconf write under stylix).
      # Mirrors the bundled `adwaita` handler in
      # desktop/modules/stylix/lib.nix.
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

      # Normalise a base16 slot to the canonical uppercase nibble (`base0A`,
      # not `base0a`): `config.lib.stylix.colors`, `defaultSlotToName` and the
      # stylix `accentNameFromSlot` maps are all keyed with the uppercase form.
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
        else if isSlot input && stylixOn then
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
        stylixOn
        ;
    };

  desktop = {
    # Build a GNOME `org.gnome.desktop.wm.preferences/button-layout` string
    # from per-button visibility flags. Fed to GNOME directly and to Zed's
    # `title_bar.button_layout` (which parses the same format via
    # `WindowButtonLayout::parse` in `crates/gpui/src/platform.rs`).
    # Close is always present (no opt-out); minimize/maximize follow their
    # flags.
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

    # Returns the active accent color as a 6-char hex string (no `#`),
    # used by per-WM modules to colour focused-window borders /
    # active-hint indicators. Wraps `generateAccent` so all consumers
    # share the same name/slot/hex resolution rules.
    accentHex = config: (generateAccent config).hexNoHash;
  };

  systemd = {
    # Returns the *-session.target names for whichever DE repos are present on
    # this host, via `hasModule` on the full NixOS `config`. Use for
    # systemd.user.services' `Unit.After` (after prepending
    # `graphical-session.target`) and `Install.WantedBy`. Adding a new DE
    # means appending one line here, not editing every consumer.
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

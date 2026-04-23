{ lib, pkgs }:

let
  inherit (lib)
    attrValues
    elemAt
    filter
    head
    splitString
    substring
    toUpper
    ;

  capitalizeFirst = s: toUpper (substring 0 1 s) + substring 1 (-1) s;

  defaultAccentNames = {
    base08 = "red";
    base09 = "orange";
    base0A = "yellow";
    base0B = "green";
    base0C = "cyan";
    base0D = "blue";
    base0E = "purple";
    base0F = "brown";
  };

  defaultThemes = {
    catppuccin = rec {
      match = name: head (splitString "-" name) == "catppuccin";

      flavor = name: elemAt (splitString "-" name) 1;

      accentNameFromSlot = {
        base08 = "red";
        base09 = "peach";
        base0A = "yellow";
        base0B = "green";
        base0C = "teal";
        base0D = "blue";
        base0E = "mauve";
        base0F = "flamingo";
      };

      iconsPackage =
        name: accent:
        pkgs.catppuccin-papirus-folders.override {
          flavor = flavor name;
          inherit accent;
        };

      cursorPackage =
        name: accent:
        let
          attr = (flavor name) + capitalizeFirst accent;
        in
        pkgs.catppuccin-cursors.${attr} or pkgs.bibata-cursors;

      cursorName = name: accent: "catppuccin-${flavor name}-${accent}-cursors";
    };
  };

  fallbackTheme = {
    match = _: true;
    accentNameFromSlot = defaultAccentNames;
    iconsPackage = _: _: pkgs.papirus-icon-theme;
    cursorPackage = _: _: pkgs.bibata-cursors;
    cursorName = _: _: "Bibata-Modern-Classic";
  };

  resolveTheme =
    themes: name:
    let
      hits = filter (h: (h.match or (_: false)) name) (attrValues themes);
    in
    if hits == [ ] then fallbackTheme else head hits;
in
{
  inherit
    capitalizeFirst
    defaultAccentNames
    defaultThemes
    fallbackTheme
    resolveTheme
    ;
}

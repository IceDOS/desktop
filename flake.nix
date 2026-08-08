{
  outputs =
    { self, ... }:
    {
      icedosModules =
        { icedosLib, ... }:
        icedosLib.scanModules {
          # Scan the repo's own source tree (not `./modules`): a bare
          # `./modules` literal is coerced to a fresh per-subdir store copy
          # (`<hash>-modules`), which has no `lib.nix` at its parent — the
          # `default` module's `lib = import ../../lib.nix` contribution would
          # climb out of the store. `self` keeps `_sourceFile` inside the full
          # repo tree so repo-root-relative imports resolve.
          path = "${self}/modules";
          filename = "icedos.nix";
        };
    };
}

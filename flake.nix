{
  outputs =
    { self, ... }:
    {
      icedosModules =
        { icedosLib, ... }:
        icedosLib.scanModules {
          # Scan `self` (not `./modules`): a bare dir literal is a store copy
          # without the repo root, breaking the default module's ../../lib.nix.
          path = "${self}/modules";
          filename = "icedos.nix";
        };
    };
}

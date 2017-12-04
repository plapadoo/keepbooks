let
  pkgs = import <nixpkgs> { };
  thisPackage = pkgs.haskellPackages.callCabal2nix "keepbooks" ./. {};
in
  pkgs.dockerTools.buildImage {
    name = "keepbooks";
    tag = "latest";
    contents = pkgs.haskell.lib.justStaticExecutables thisPackage;
  }

let
  pkgs = import <nixpkgs> { };
  thisPackage = pkgs.haskellPackages.callPackage ./default.nix {};
in
  pkgs.dockerTools.buildImage {
    name = "keepbooks";
    tag = "latest";
    contents = thisPackage;
  }

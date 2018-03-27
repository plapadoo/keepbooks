let
  bootstrap = import <nixpkgs> { };

  nixpkgs = builtins.fromJSON (builtins.readFile ./nixpkgs.json);

  src = bootstrap.fetchFromGitHub {
    owner = "NixOS";
    repo  = "nixpkgs-channels";
    inherit (nixpkgs) rev sha256;
  };

  pkgs = import src { };
  thisPackage = pkgs.haskellPackages.callCabal2nix "keepbooks" ./. {};
in
  pkgs.dockerTools.buildImage {
    name = "keepbooks";
    tag = "latest";
    contents = pkgs.haskell.lib.justStaticExecutables thisPackage;
  }

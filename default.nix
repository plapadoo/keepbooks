{ mkDerivation, base, directory, filepath, optparse-applicative
, stdenv, time, unix
}:
mkDerivation {
  pname = "keepbooks";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base directory filepath optparse-applicative time unix
  ];
  doHaddock = false;
  homepage = "https://github.com/plapadoo/keepbooks#readme";
  description = "Keep your books like a pro!";
  license = stdenv.lib.licenses.bsd3;
}

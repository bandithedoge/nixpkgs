{
  callPackage,
  stdenv,
  lib,
}:

callPackage ./generic.nix {
  version = "4.8.1.0";
  sha256 = "1vyvp2g28ihcgxgxr8nhzyzdmzicsh5djzk8dk1hj5p5f2k3ijqq";
  enableParallelBuilding = false; # #32386, https://hydra.nixos.org/build/65600645
  extraPatches = lib.optionals stdenv.hostPlatform.isLinux [ ./mono4-glibc.patch ];
  env.NIX_CFLAGS_COMPILE = toString [
    "-Wno-error=implicit-function-declaration"
    "-Wno-error=implicit-int"
    "-Wno-error=incompatible-pointer-types"
    "-Wno-error=int-conversion"
    "-Wno-error=return-mismatch"
  ];
}

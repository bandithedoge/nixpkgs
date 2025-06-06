{
  cmake,
  fetchFromGitHub,
  glib,
  gtk3,
  lib,
  pkg-config,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "ayatana-ido";
  version = "0.10.4";

  src = fetchFromGitHub {
    owner = "AyatanaIndicators";
    repo = "ayatana-ido";
    rev = version;
    sha256 = "sha256-KeErrT2umMaIVfLDr4CcQCmFrMb8/h6pNYbunuC/JtI=";
  };

  nativeBuildInputs = [
    cmake
    glib # for glib-mkenums
    pkg-config
  ];

  buildInputs = [ gtk3 ];

  strictDeps = true;

  meta = {
    description = "Ayatana Display Indicator Objects";
    homepage = "https://github.com/AyatanaIndicators/ayatana-ido";
    changelog = "https://github.com/AyatanaIndicators/ayatana-ido/blob/${version}/ChangeLog";
    license = [
      lib.licenses.lgpl3Plus
      lib.licenses.lgpl21Plus
    ];
    maintainers = [ lib.maintainers.nickhu ];
    platforms = lib.platforms.linux;
  };
}

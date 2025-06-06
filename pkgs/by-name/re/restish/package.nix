{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  restish,
  testers,
  xorg,
}:

buildGoModule rec {
  pname = "restish";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "danielgtaylor";
    repo = "restish";
    tag = "v${version}";
    hash = "sha256-a0ObgFgWEsLYjGmCCi/py2PADAWJ0By+AZ4wh+Yeam4=";
  };

  vendorHash = "sha256-qeArar0WnMACUnKBlC+PcFeJPzofwbK440A4M/rQ04U=";

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXinerama
    xorg.libXrandr
  ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${version}"
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  passthru.tests.version = testers.testVersion {
    package = restish;
  };

  meta = {
    description = "CLI tool for interacting with REST-ish HTTP APIs";
    homepage = "https://rest.sh/";
    changelog = "https://github.com/danielgtaylor/restish/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ fab ];
    mainProgram = "restish";
  };
}

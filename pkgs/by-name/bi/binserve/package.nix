{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "binserve";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "mufeedvh";
    repo = "binserve";
    rev = "v${version}";
    hash = "sha256-Chm2xPB0BrLXSZslg9wnbDyHSJRQAvOtpH0Rw6w1q1s=";
  };

  cargoLock.lockFile = ./Cargo.lock;
  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  doCheck = false;

  meta = with lib; {
    description = "Fast production-ready static web server";
    homepage = "https://github.com/mufeedvh/binserve";
    longDescription = ''
      A fast production-ready static web server with TLS
      (HTTPS), routing, hot reloading, caching, templating, and security in a
      single-binary you can set up with zero code
    '';
    license = licenses.mit;
    maintainers = with maintainers; [ snapdgn ];
    platforms = platforms.unix;
    mainProgram = "binserve";
  };
}

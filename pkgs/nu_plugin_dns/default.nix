{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "nu_plugin_dns";
  version = "4.0.5";

  src = fetchFromGitHub {
    owner = "dead10ck";
    repo = "nu_plugin_dns";
    rev = "v${version}";
    hash = "sha256-Zf66C8YFS3pC5g24jh5mXhdSNoFDjGJSSWG1VSEZ4PM=";
  };

  cargoHash = "sha256-7qS1cXNuztVs6preUut0l/XZtsO7eAzdljst+mGBQnA=";

  nativeBuildInputs = [pkg-config];

  buildInputs = [openssl];

  # Tests require network access and a working directory
  doCheck = false;

  meta = with lib; {
    description = "A DNS utility for nushell";
    homepage = "https://github.com/dead10ck/nu_plugin_dns";
    license = licenses.mpl20;
    mainProgram = "nu_plugin_dns";
  };
}

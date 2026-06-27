{
  lib,
  stdenv,
  fetchurl,
  unzip,
}: let
  version = "0.0.9--context-conduit-topaz";
  platform =
    {
      "aarch64-linux" = "linux-arm64";
      "x86_64-linux" = "linux-amd64";
      "aarch64-darwin" = "darwin-arm64";
      "x86_64-darwin" = "darwin-amd64";
    }
    .${
      stdenv.hostPlatform.system
    }
      or (throw "openai-tunnel-client: unsupported system ${stdenv.hostPlatform.system}");
  hashes = {
    "linux-arm64" = "sha256-1Wkvj/hFOMb0R63ZQrK8eVPkfwDZuRSF+ULIM/9S4vQ=";
    "linux-amd64" = "sha256-6rlIJdvViek4pqe6XNdL8L7Ko77w5lX0Q4oPdf3fvI8=";
    "darwin-arm64" = "sha256-QxbDQUG5R0Wy4FJyULxnI9+1vtESBKIslD1CXb1uIZo=";
    "darwin-amd64" = "sha256-GbMiIJYDV+z2h9pzhBaoHp1HwkhIliXvYdaqeLNNSys=";
  };
in
  stdenv.mkDerivation {
    pname = "openai-tunnel-client";
    inherit version;

    src = fetchurl {
      url = "https://github.com/openai/tunnel-client/releases/download/v${version}/tunnel-client-v${version}-${platform}.zip";
      hash = hashes.${platform};
    };

    nativeBuildInputs = [unzip];
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      unzip $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 tunnel-client $out/bin/tunnel-client
      runHook postInstall
    '';

    meta = {
      description = "OpenAI Secure MCP Tunnel client";
      homepage = "https://github.com/openai/tunnel-client";
      license = lib.licenses.asl20;
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      mainProgram = "tunnel-client";
    };
  }

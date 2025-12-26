{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "transmission-exporter";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "metalmatze";
    repo = "transmission-exporter";
    rev = version;
    hash = "sha256-Zfs39UqmqDkAWHfSX62zowpxvY3+d+Y/nr9KDycqrO4=";
  };

  vendorHash = "sha256-YhmfrM5iAK0zWcUM7LmbgFnH+k2M/tE+f/QQIQmQlZs=";

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  meta = with lib; {
    description = "Prometheus exporter for Transmission BitTorrent client";
    homepage = "https://github.com/metalmatze/transmission-exporter";
    license = licenses.mit;
    mainProgram = "transmission-exporter";
  };
}

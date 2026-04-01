{ config, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
in
{
  virtualisation.oci-containers.containers.planarally = {
    image = "kruptein/planarally:latest";

    ports = [
      "127.0.0.1:${toString ports.apps.planarally}:8000/tcp"
    ];

    volumes = [
      "/var/lib/planarally/data:/planarally/data"
      "/var/lib/planarally/assets:/planarally/static/assets"
      "/var/lib/planarally/mods:/planarally/static/mods"
    ];

    autoStart = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/planarally 0755 root root -"
    "d /var/lib/planarally/data 0755 9000 9000 -"
    "d /var/lib/planarally/assets 0755 9000 9000 -"
    "d /var/lib/planarally/mods 0755 9000 9000 -"
  ];

  services.cyberspace.registeredServices.planarally = {
    name = "PlanarAlly";
    description = "Virtual tabletop for running tabletop RPG sessions";
    url = "https://planarally.${domain}";
    icon = "🗺️";
    enabled = true;
    port = ports.apps.planarally;
    tags = [ "gaming" "tools" ];
  };

  services.caddy.virtualHosts."planarally.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.planarally} {
        flush_interval -1

        transport http {
          read_timeout 0
          write_timeout 0
        }
      }
    '';
  };
}

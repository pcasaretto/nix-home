{ config, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
in
{
  # Enable Transmission BitTorrent daemon
  services.transmission = {
    enable = true;

    settings = {
      download-dir = "/mnt/external/downloads";
      incomplete-dir = "/mnt/external/downloads/.incomplete";
      incomplete-dir-enabled = true;

      rpc-bind-address = "127.0.0.1";
      rpc-port = ports.apps.transmission;
      rpc-authentication-required = false;
      rpc-host-whitelist-enabled = false;
      rpc-whitelist-enabled = false;

      download-queue-enabled = true;
      download-queue-size = 5;
      speed-limit-down-enabled = false;
      speed-limit-up-enabled = false;

      peer-port = ports.p2p.transmissionPeer;
      peer-port-random-on-start = false;
      port-forwarding-enabled = true;

      encryption = 2;
      dht-enabled = true;
      pex-enabled = true;
      lpd-enabled = true;

      umask = 2;
      ratio-limit-enabled = false;
      idle-seeding-limit-enabled = false;
    };

    user = "transmission";
    group = "external";
    home = "/var/lib/transmission";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/external/downloads 0775 transmission external -"
    "d /mnt/external/downloads/.incomplete 0775 transmission external -"
    "d /mnt/external/downloads/sonarr 0775 transmission external -"
    "d /mnt/external/downloads/radarr 0775 transmission external -"
    "d /mnt/external/downloads/lidarr 0775 transmission external -"
  ];

  systemd.services.transmission = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
  };

  users.users.pcasaretto.extraGroups = [ "external" ];
  users.users.transmission.extraGroups = [ "external" ];

  # Register in service registry
  services.cyberspace.registeredServices.transmission = {
    name = "Transmission";
    description = "BitTorrent client with web interface - downloads to external drive";
    url = "https://transmission.${domain}";
    icon = "📥";
    enabled = true;
    port = ports.apps.transmission;
    tags = [ "download" "torrent" "media" ];
  };

  # Configure Caddy reverse proxy
  # Transmission expects requests at /transmission/ internally
  services.caddy.virtualHosts."transmission.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.transmission} {
        transport http {
          read_timeout 300s
        }
      }
    '';
  };
}

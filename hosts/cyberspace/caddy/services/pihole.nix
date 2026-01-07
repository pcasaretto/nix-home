{ config, pkgs, lib, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
  piholeWebPort = ports.apps.piholeWeb;
  piholeDnsPort = ports.dns.pihole;
in
{
  # Enable OCI container runtime
  virtualisation.oci-containers = {
    backend = "podman";

    containers.pihole = {
      image = "pihole/pihole:latest";

      ports = [
        "${toString piholeDnsPort}:53/tcp"
        "${toString piholeDnsPort}:53/udp"
        "${toString piholeWebPort}:80/tcp"
      ];

      environment = {
        TZ = "America/Sao_Paulo";
        PIHOLE_DNS_ = "1.1.1.1;1.0.0.1;8.8.8.8;8.8.4.4";
        FTLCONF_webserver_api_password = "";
        VIRTUAL_HOST = "pihole.local";
        QUERY_LOGGING = "true";
        IPv6 = "false";
        FTLCONF_dns_listeningMode = "ALL";
      };

      volumes = [
        "/var/lib/pihole/pihole:/etc/pihole"
        "/var/lib/pihole/dnsmasq.d:/etc/dnsmasq.d"
      ];

      autoStart = true;

      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--dns=127.0.0.1"
        "--dns=1.1.1.1"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/pihole 0755 root root -"
    "d /var/lib/pihole/pihole 0755 root root -"
    "d /var/lib/pihole/dnsmasq.d 0755 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ piholeDnsPort ];
  networking.firewall.allowedUDPPorts = [ piholeDnsPort ];

  # Register in service registry
  services.cyberspace.registeredServices.pihole = {
    name = "Pi-hole";
    description = "Network-wide ad blocking via DNS - blocks ads and trackers";
    url = "https://pihole.${domain}";
    icon = "🛡️";
    enabled = true;
    port = piholeWebPort;
    tags = [ "dns" "security" "privacy" "network" ];
  };

  # Configure Caddy reverse proxy - much simpler with subdomain!
  # No more sub_filter hacks needed
  services.caddy.virtualHosts."pihole.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      # Redirect root to admin interface
      redir / /admin/ permanent

      reverse_proxy http://127.0.0.1:${toString piholeWebPort} {
        transport http {
          read_timeout 300s
        }
      }
    '';
  };
}

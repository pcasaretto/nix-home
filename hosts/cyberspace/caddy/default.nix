{ config, pkgs, lib, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;

  # Caddy with Cloudflare DNS plugin for Let's Encrypt DNS-01 challenge
  caddyWithCloudflare = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
    hash = "sha256-dnhEjopeA0UiI+XVYHYpsjcEI6Y1Hacbi28hVKYQURg=";
  };

  # Common TLS config for all services
  tlsConfig = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
      resolvers 1.1.1.1 8.8.8.8
    }
  '';
in
{
  imports = [
    ./services
  ];

  # Export TLS config for other modules to use
  options.services.cyberspace.tlsConfig = lib.mkOption {
    type = lib.types.str;
    default = tlsConfig;
    description = "Common TLS configuration for Caddy virtualHosts";
  };

  config = {
    # Disable nginx (replaced by Caddy)
    services.nginx.enable = lib.mkForce false;

    # Enable Caddy with Cloudflare plugin
    services.caddy = {
      enable = true;
      package = caddyWithCloudflare;

      # Global config with metrics
      globalConfig = ''
        servers {
          metrics
        }
      '';

      # Main domain redirects to dashboard
      virtualHosts."${domain}" = {
        extraConfig = ''
          ${tlsConfig}
          redir https://dashboard.${domain}{uri} permanent
        '';
      };

      # Metrics endpoint for Caddy
      virtualHosts."localhost:${toString ports.exporters.caddy}" = {
        extraConfig = ''
          metrics /metrics
        '';
      };
    };

    # Pass Cloudflare API token to Caddy
    systemd.services.caddy = {
      after = [ "tailscaled.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      requires = [ "tailscaled.service" ];
      serviceConfig = {
        EnvironmentFile = config.sops.secrets.cloudflare-api-token.path;
      };
    };

    # Provide MIME types database so Caddy/Go serves correct Content-Type headers
    environment.etc."mime.types".source = "${pkgs.mailcap}/etc/mime.types";

    # Firewall: allow HTTPS on Tailscale interface only
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [ 80 443 ];
    };
  };
}

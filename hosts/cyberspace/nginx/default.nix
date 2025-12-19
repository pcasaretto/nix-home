{ config, lib, pkgs, ... }:

{
  imports = [
    ./service-registry.nix
    ./tailscale-binding.nix
    ./services
  ];

  services.nginx = {
    enable = true;

    # Recommended settings for reverse proxy
    recommendedProxySettings = true;
    recommendedTlsSettings = false;  # HTTP only as per requirements
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Common configuration
    commonHttpConfig = ''
      # Real IP from Tailscale
      real_ip_header X-Real-IP;

      # Security headers (even for HTTP)
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;

      # Logging
      log_format detailed '$remote_addr - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent"';

      access_log /var/log/nginx/access.log detailed;
    '';
  };

  # Ensure nginx starts after Tailscale
  systemd.services.nginx = {
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "tailscaled.service" ];
  };
}

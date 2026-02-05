{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) domain;
in
{
  # Register the spellbook service
  services.cyberspace.registeredServices.spellbook = {
    name = "Spellbook";
    description = "D&D 5e spell reference SPA";
    url = "https://spellbook.${domain}";
    icon = "📖";
    enabled = true;
    tags = ["tools" "gaming"];
  };

  # Configure Caddy to serve the spellbook (internal, via Tailscale)
  services.caddy.virtualHosts."spellbook.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      root * ${pkgs.spellbook}

      # SPA routing: try files first, fallback to index.html for client-side routes
      try_files {path} /index.html

      file_server
    '';
  };

  # HTTP vhost for Tailscale Funnel (Funnel handles TLS, proxies HTTP here)
  services.caddy.virtualHosts."http://:8180" = {
    extraConfig = ''
      root * ${pkgs.spellbook}
      try_files {path} /index.html
      file_server
    '';
  };
}

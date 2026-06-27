{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) domain;
in
{
  services.cyberspace.registeredServices.fiveetools = {
    name = "5etools";
    description = "D&D 5e 2014 tools and reference";
    url = "https://5etools.${domain}";
    icon = "🐉";
    enabled = true;
    tags = ["tools" "gaming"];
  };

  services.caddy.virtualHosts."5etools.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      root * ${pkgs.fiveetools}
      try_files {path} /index.html
      file_server
    '';
  };

  # HTTP vhost for Tailscale Funnel (Funnel handles TLS, proxies HTTP here)
  services.caddy.virtualHosts."http://:8181" = {
    extraConfig = ''
      root * ${pkgs.fiveetools}
      try_files {path} /index.html
      file_server
    '';
  };
}

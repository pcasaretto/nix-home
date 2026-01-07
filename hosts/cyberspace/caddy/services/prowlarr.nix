{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable Prowlarr indexer manager - NO urlbase needed with subdomain
  services.prowlarr = {
    enable = true;
    openFirewall = false;
    # Removed: settings.server.urlbase = "/prowlarr"
  };

  # Disable DynamicUser and use static prowlarr user
  systemd.services.prowlarr.serviceConfig = {
    DynamicUser = pkgs.lib.mkForce false;
    User = pkgs.lib.mkForce "prowlarr";
    Group = pkgs.lib.mkForce "prowlarr";
  };

  # Set API key from sops and disable authentication
  systemd.services.prowlarr.preStart = ''
    CONFIG_FILE="/var/lib/prowlarr/config.xml"
    API_KEY=$(cat ${config.sops.secrets.prowlarr-api-key.path})

    if [ -f "$CONFIG_FILE" ]; then
      sed -i '/<AuthenticationMethod>/d' "$CONFIG_FILE"
      sed -i '/<ApiKey>/d' "$CONFIG_FILE"
      # Also remove any existing UrlBase
      sed -i '/<UrlBase>/d' "$CONFIG_FILE"
      sed -i 's|</Config>|  <AuthenticationMethod>External</AuthenticationMethod>\n</Config>|' "$CONFIG_FILE"
      sed -i "s|</Config>|  <ApiKey>$API_KEY</ApiKey>\n</Config>|" "$CONFIG_FILE"

      chmod 0640 "$CONFIG_FILE"
      chgrp media "$CONFIG_FILE" 2>/dev/null || true
    else
      cat > "$CONFIG_FILE" << EOF
<Config>
  <ApiKey>$API_KEY</ApiKey>
  <AuthenticationMethod>External</AuthenticationMethod>
</Config>
EOF
      chmod 0640 "$CONFIG_FILE"
      chgrp media "$CONFIG_FILE" 2>/dev/null || true
    fi
  '';

  systemd.tmpfiles.rules = [
    "z /var/lib/prowlarr 0750 prowlarr media -"
    "z /var/lib/prowlarr/config.xml 0640 prowlarr media - -"
  ];

  users.users.prowlarr = {
    isSystemUser = true;
    group = "prowlarr";
    extraGroups = [ "media" ];
  };

  users.groups.prowlarr = {};

  users.users.pcasaretto.extraGroups = [ "media" ];

  # Register in service registry
  services.cyberspace.registeredServices.prowlarr = {
    name = "Prowlarr";
    description = "Indexer manager for Sonarr, Radarr, and Lidarr";
    url = "https://prowlarr.${domain}";
    icon = "🔍";
    enabled = true;
    port = ports.media.prowlarr;
    tags = [ "media" "automation" "indexer" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."prowlarr.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.prowlarr}
    '';
  };
}

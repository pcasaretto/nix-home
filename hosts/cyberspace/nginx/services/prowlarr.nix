{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) ports;
in
{
  # Enable Prowlarr indexer manager
  services.prowlarr = {
    enable = true;
    openFirewall = false;  # Only accessible via Tailscale/nginx

    # Configure URL base for reverse proxy
    settings = {
      server = {
        urlbase = "/prowlarr";
      };
    };
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
      # Remove existing AuthenticationMethod and ApiKey if present
      sed -i '/<AuthenticationMethod>/d' "$CONFIG_FILE"
      sed -i '/<ApiKey>/d' "$CONFIG_FILE"
      # Add AuthenticationMethod set to External (disables auth)
      sed -i 's|</Config>|  <AuthenticationMethod>External</AuthenticationMethod>\n</Config>|' "$CONFIG_FILE"
      # Add API key from sops
      sed -i "s|</Config>|  <ApiKey>$API_KEY</ApiKey>\n</Config>|" "$CONFIG_FILE"

      # Make config readable by media group
      chmod 0640 "$CONFIG_FILE"
      chgrp media "$CONFIG_FILE" 2>/dev/null || true
    else
      # Create initial config with API key from sops
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

  # Make Prowlarr config readable by media group so other services can register
  systemd.tmpfiles.rules = [
    "z /var/lib/prowlarr 0750 prowlarr media -"
    "z /var/lib/prowlarr/config.xml 0640 prowlarr media - -"
  ];

  # Configure prowlarr user and group
  users.users.prowlarr = {
    isSystemUser = true;
    group = "prowlarr";
    extraGroups = [ "media" ];
  };

  users.groups.prowlarr = {};

  # Ensure user is in media group
  users.users.pcasaretto.extraGroups = [ "media" ];

  # Register in service registry
  services.cyberspace.registeredServices.prowlarr = {
    name = "Prowlarr";
    description = "Indexer manager for Sonarr, Radarr, and Lidarr";
    path = "/prowlarr";
    icon = "🔍";
    enabled = true;
    port = ports.media.prowlarr;
    tags = [ "media" "automation" "indexer" ];
  };

  # Configure nginx reverse proxy (official Servarr Wiki pattern)
  services.nginx.virtualHosts."cyberspace" = {
    locations."^~ /prowlarr" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.prowlarr}";
      extraConfig = ''
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Allow large uploads
        client_max_body_size 50M;
      '';
    };

    # Allow API External Access
    locations."^~ /prowlarr/api" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.prowlarr}";
      extraConfig = ''
        auth_basic off;
      '';
    };
  };
}

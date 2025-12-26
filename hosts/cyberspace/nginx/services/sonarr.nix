{ config, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
in
{
  # Enable Sonarr TV show management
  services.sonarr = {
    enable = true;
    openFirewall = false;  # Only accessible via Tailscale/nginx
    user = "sonarr";
    group = "media";
    dataDir = "/var/lib/sonarr";

    # Configure URL base for reverse proxy
    settings = {
      server = {
        urlbase = "/sonarr";
      };
    };
  };

  # Set API key from sops and disable authentication
  systemd.services.sonarr.preStart = ''
    CONFIG_FILE="/var/lib/sonarr/config.xml"
    API_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})

    if [ -f "$CONFIG_FILE" ]; then
      # Remove existing AuthenticationMethod and ApiKey if present
      sed -i '/<AuthenticationMethod>/d' "$CONFIG_FILE"
      sed -i '/<ApiKey>/d' "$CONFIG_FILE"
      # Add AuthenticationMethod set to External (disables auth)
      sed -i 's|</Config>|  <AuthenticationMethod>External</AuthenticationMethod>\n</Config>|' "$CONFIG_FILE"
      # Add API key from sops
      sed -i "s|</Config>|  <ApiKey>$API_KEY</ApiKey>\n</Config>|" "$CONFIG_FILE"
    else
      # Create initial config with API key from sops
      cat > "$CONFIG_FILE" << EOF
<Config>
  <ApiKey>$API_KEY</ApiKey>
  <AuthenticationMethod>External</AuthenticationMethod>
</Config>
EOF
    fi
  '';

  # Configure Transmission as download client via API
  systemd.services.sonarr-setup = {
    description = "Configure Sonarr download client";
    after = [ "sonarr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "sonarr";
    };
    script = ''
      # Wait for Sonarr to be ready
      until [ -f /var/lib/sonarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      # Read API key from sops
      API_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})

      if [ -z "$API_KEY" ]; then
        echo "Failed to get API key from sops"
        exit 1
      fi

      # Wait for API to be responsive
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.sonarr}/sonarr/api/v3/system/status -H "X-Api-Key: $API_KEY" > /dev/null; do
        sleep 2
      done

      # Check if Transmission download client already exists
      if ! ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.sonarr}/sonarr/api/v3/downloadclient -H "X-Api-Key: $API_KEY" | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "Transmission")' > /dev/null 2>&1; then
        # Add Transmission as download client
        ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:${toString ports.media.sonarr}/sonarr/api/v3/downloadclient \
          -H "Content-Type: application/json" \
          -H "X-Api-Key: $API_KEY" \
          -d '{
            "enable": true,
            "protocol": "torrent",
            "priority": 1,
            "name": "Transmission",
            "fields": [
              {"name": "host", "value": "127.0.0.1"},
              {"name": "port", "value": ${toString ports.apps.transmission}},
              {"name": "urlBase", "value": "/transmission/"},
              {"name": "username", "value": ""},
              {"name": "password", "value": ""},
              {"name": "category", "value": "sonarr"},
              {"name": "addPaused", "value": false}
            ],
            "implementationName": "Transmission",
            "implementation": "Transmission",
            "configContract": "TransmissionSettings",
            "tags": []
          }' && echo "Transmission configured successfully" || echo "Failed to configure Transmission"
      else
        echo "Transmission already configured"
      fi
    '';
  };

  # Register Sonarr with Prowlarr for automatic indexer syncing
  systemd.services.sonarr-prowlarr-sync = {
    description = "Register Sonarr with Prowlarr";
    after = [ "sonarr.service" "prowlarr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "sonarr";
    };
    script = ''
      # Wait for both services to be ready
      until [ -f /var/lib/sonarr/config.xml ] && [ -f /var/lib/prowlarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      # Read API keys from sops
      SONARR_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})
      PROWLARR_KEY=$(cat ${config.sops.secrets.prowlarr-api-key.path})

      if [ -z "$SONARR_KEY" ] || [ -z "$PROWLARR_KEY" ]; then
        echo "Failed to get API keys from sops"
        exit 1
      fi

      # Wait for Prowlarr API to be responsive
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/prowlarr/api/v1/system/status -H "X-Api-Key: $PROWLARR_KEY" > /dev/null; do
        sleep 2
      done

      # Check if Sonarr already registered
      if ! ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/prowlarr/api/v1/applications -H "X-Api-Key: $PROWLARR_KEY" | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "Sonarr")' > /dev/null 2>&1; then
        # Register with Prowlarr
        ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:${toString ports.media.prowlarr}/prowlarr/api/v1/applications \
          -H "Content-Type: application/json" \
          -H "X-Api-Key: $PROWLARR_KEY" \
          -d "{
            \"name\": \"Sonarr\",
            \"syncLevel\": \"fullSync\",
            \"implementation\": \"Sonarr\",
            \"configContract\": \"SonarrSettings\",
            \"fields\": [
              {\"name\": \"prowlarrUrl\", \"value\": \"http://127.0.0.1:${toString ports.media.prowlarr}/prowlarr\"},
              {\"name\": \"baseUrl\", \"value\": \"http://127.0.0.1:${toString ports.media.sonarr}/sonarr\"},
              {\"name\": \"apiKey\", \"value\": \"$SONARR_KEY\"},
              {\"name\": \"syncCategories\", \"value\": [5000,5010,5020,5030,5040,5045,5050,5060,5070,5080]}
            ],
            \"tags\": []
          }" && echo "Sonarr registered with Prowlarr" || echo "Failed to register Sonarr"
      else
        echo "Sonarr already registered with Prowlarr"
      fi
    '';
  };

  # Create media group shared by all *arr services
  users.groups.media = {
    gid = 1002;
  };

  # Create media directories
  systemd.tmpfiles.rules = [
    "d /mnt/external/media 0775 sonarr media -"
    "d /mnt/external/media/tv 0775 sonarr media -"
  ];

  # Ensure sonarr starts after external drive is mounted
  systemd.services.sonarr = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
    serviceConfig = {
      # Allow access to transmission downloads
      SupplementaryGroups = [ "external" ];
    };
  };

  # Add users to media group
  users.users.pcasaretto.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "external" ];

  # Register in service registry
  services.cyberspace.registeredServices.sonarr = {
    name = "Sonarr";
    description = "TV show collection manager with automatic episode downloads";
    path = "/sonarr";
    icon = "📺";
    enabled = true;
    port = ports.media.sonarr;
    tags = [ "media" "automation" "tv" ];
  };

  # Configure nginx reverse proxy (official Servarr Wiki pattern)
  services.nginx.virtualHosts."cyberspace" = {
    locations."^~ /sonarr" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.sonarr}";
      extraConfig = ''
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Allow large uploads for manual imports
        client_max_body_size 0;
      '';
    };

    # Allow API External Access
    locations."^~ /sonarr/api" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.sonarr}";
      extraConfig = ''
        auth_basic off;
      '';
    };
  };
}

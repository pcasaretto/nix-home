{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable Radarr movie management - NO urlbase needed with subdomain
  services.radarr = {
    enable = true;
    openFirewall = false;
    user = "radarr";
    group = "media";
    dataDir = "/var/lib/radarr";
    # Removed: settings.server.urlbase = "/radarr"
  };

  # Set API key from sops and disable authentication
  systemd.services.radarr.preStart = ''
    CONFIG_FILE="/var/lib/radarr/config.xml"
    API_KEY=$(cat ${config.sops.secrets.radarr-api-key.path})

    if [ -f "$CONFIG_FILE" ]; then
      sed -i '/<AuthenticationMethod>/d' "$CONFIG_FILE"
      sed -i '/<ApiKey>/d' "$CONFIG_FILE"
      # Also remove any existing UrlBase
      sed -i '/<UrlBase>/d' "$CONFIG_FILE"
      sed -i 's|</Config>|  <AuthenticationMethod>External</AuthenticationMethod>\n</Config>|' "$CONFIG_FILE"
      sed -i "s|</Config>|  <ApiKey>$API_KEY</ApiKey>\n</Config>|" "$CONFIG_FILE"
    else
      cat > "$CONFIG_FILE" << EOF
<Config>
  <ApiKey>$API_KEY</ApiKey>
  <AuthenticationMethod>External</AuthenticationMethod>
</Config>
EOF
    fi
  '';

  # Configure Transmission as download client via API
  systemd.services.radarr-setup = {
    description = "Configure Radarr download client";
    after = [ "radarr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "radarr";
    };
    script = ''
      until [ -f /var/lib/radarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      API_KEY=$(cat ${config.sops.secrets.radarr-api-key.path})

      if [ -z "$API_KEY" ]; then
        echo "Failed to get API key from sops"
        exit 1
      fi

      # Updated: API URL no longer has /radarr prefix
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.radarr}/api/v3/system/status -H "X-Api-Key: $API_KEY" > /dev/null; do
        sleep 2
      done

      if ! ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.radarr}/api/v3/downloadclient -H "X-Api-Key: $API_KEY" | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "Transmission")' > /dev/null 2>&1; then
        ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:${toString ports.media.radarr}/api/v3/downloadclient \
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
              {"name": "category", "value": "radarr"},
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

  # Register Radarr with Prowlarr for automatic indexer syncing
  systemd.services.radarr-prowlarr-sync = {
    description = "Register Radarr with Prowlarr";
    after = [ "radarr.service" "prowlarr.service" ];
    wantedBy = [ "multi-user.target" ];

    restartTriggers = [
      config.sops.secrets.radarr-api-key.path
      config.sops.secrets.prowlarr-api-key.path
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "radarr";
    };
    script = ''
      until [ -f /var/lib/radarr/config.xml ] && [ -f /var/lib/prowlarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      RADARR_KEY=$(cat ${config.sops.secrets.radarr-api-key.path})
      PROWLARR_KEY=$(cat ${config.sops.secrets.prowlarr-api-key.path})

      if [ -z "$RADARR_KEY" ] || [ -z "$PROWLARR_KEY" ]; then
        echo "Failed to get API keys from sops"
        exit 1
      fi

      # Updated: API URL no longer has /prowlarr prefix
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/system/status -H "X-Api-Key: $PROWLARR_KEY" > /dev/null; do
        sleep 2
      done

      echo "Checking for existing Radarr registrations..."
      ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/applications -H "X-Api-Key: $PROWLARR_KEY" | \
        ${pkgs.jq}/bin/jq -r '.[] | select(.name == "Radarr") | .id' | while read id; do
        echo "Deleting existing registration (ID: $id)..."
        ${pkgs.curl}/bin/curl -sf -X DELETE "http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/applications/$id" \
          -H "X-Api-Key: $PROWLARR_KEY"
        echo "Deleted registration $id"
      done

      echo "Creating fresh Radarr registration with Prowlarr..."
      # Updated: baseUrl and prowlarrUrl no longer have subpath prefixes
      RESPONSE=$(${pkgs.curl}/bin/curl -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/applications \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $PROWLARR_KEY" \
        -d "{
          \"name\": \"Radarr\",
          \"syncLevel\": \"fullSync\",
          \"implementation\": \"Radarr\",
          \"configContract\": \"RadarrSettings\",
          \"fields\": [
            {\"name\": \"prowlarrUrl\", \"value\": \"http://127.0.0.1:${toString ports.media.prowlarr}\"},
            {\"name\": \"baseUrl\", \"value\": \"http://127.0.0.1:${toString ports.media.radarr}\"},
            {\"name\": \"apiKey\", \"value\": \"$RADARR_KEY\"},
            {\"name\": \"syncCategories\", \"value\": [2000,2010,2020,2030,2040,2045,2050,2060,2070,2080]}
          ],
          \"tags\": []
        }" 2>&1)

      HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
      BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

      if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "Radarr registered with Prowlarr successfully (HTTP $HTTP_CODE)"
      else
        echo "Failed to register Radarr (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        exit 1
      fi
    '';
  };

  systemd.paths.radarr-config-watcher = {
    description = "Watch Radarr config for changes";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/var/lib/radarr/config.xml";
    };
  };

  systemd.services.radarr-config-watcher = {
    description = "Trigger Radarr-Prowlarr sync on config change";
    serviceConfig.Type = "oneshot";
    script = ''
      echo "Radarr config changed, triggering sync..."
      ${pkgs.systemd}/bin/systemctl restart radarr-prowlarr-sync.service
    '';
  };

  systemd.tmpfiles.rules = [
    "d /mnt/external/media 0775 radarr media -"
    "d /mnt/external/media/movies 0775 radarr media -"
  ];

  systemd.services.radarr = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
    serviceConfig = {
      SupplementaryGroups = [ "external" ];
    };
  };

  users.users.pcasaretto.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "external" ];

  # Register in service registry
  services.cyberspace.registeredServices.radarr = {
    name = "Radarr";
    description = "Movie collection manager with automatic downloads";
    url = "https://radarr.${domain}";
    icon = "🎬";
    enabled = true;
    port = ports.media.radarr;
    tags = [ "media" "automation" "movies" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."radarr.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.radarr}
    '';
  };
}

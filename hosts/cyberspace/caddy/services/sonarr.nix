{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable Sonarr TV show management - NO urlbase needed with subdomain
  services.sonarr = {
    enable = true;
    openFirewall = false;
    user = "sonarr";
    group = "media";
    dataDir = "/var/lib/sonarr";
    # Removed: settings.server.urlbase = "/sonarr"
  };

  # Set API key from sops and disable authentication
  systemd.services.sonarr.preStart = ''
    CONFIG_FILE="/var/lib/sonarr/config.xml"
    API_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})

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
      until [ -f /var/lib/sonarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      API_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})

      if [ -z "$API_KEY" ]; then
        echo "Failed to get API key from sops"
        exit 1
      fi

      # Updated: API URL no longer has /sonarr prefix
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.sonarr}/api/v3/system/status -H "X-Api-Key: $API_KEY" > /dev/null; do
        sleep 2
      done

      # Check if Transmission download client already exists
      if ! ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.sonarr}/api/v3/downloadclient -H "X-Api-Key: $API_KEY" | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "Transmission")' > /dev/null 2>&1; then
        ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:${toString ports.media.sonarr}/api/v3/downloadclient \
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

    restartTriggers = [
      config.sops.secrets.sonarr-api-key.path
      config.sops.secrets.prowlarr-api-key.path
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "sonarr";
    };
    script = ''
      until [ -f /var/lib/sonarr/config.xml ] && [ -f /var/lib/prowlarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      SONARR_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})
      PROWLARR_KEY=$(cat ${config.sops.secrets.prowlarr-api-key.path})

      if [ -z "$SONARR_KEY" ] || [ -z "$PROWLARR_KEY" ]; then
        echo "Failed to get API keys from sops"
        exit 1
      fi

      # Updated: API URLs no longer have subpath prefixes
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/system/status -H "X-Api-Key: $PROWLARR_KEY" > /dev/null; do
        sleep 2
      done

      echo "Checking for existing Sonarr registrations..."
      ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/applications -H "X-Api-Key: $PROWLARR_KEY" | \
        ${pkgs.jq}/bin/jq -r '.[] | select(.name == "Sonarr") | .id' | while read id; do
        echo "Deleting existing registration (ID: $id)..."
        ${pkgs.curl}/bin/curl -sf -X DELETE "http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/applications/$id" \
          -H "X-Api-Key: $PROWLARR_KEY"
        echo "Deleted registration $id"
      done

      echo "Creating fresh Sonarr registration with Prowlarr..."
      # Updated: baseUrl and prowlarrUrl no longer have subpath prefixes
      RESPONSE=$(${pkgs.curl}/bin/curl -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/applications \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $PROWLARR_KEY" \
        -d "{
          \"name\": \"Sonarr\",
          \"syncLevel\": \"fullSync\",
          \"implementation\": \"Sonarr\",
          \"configContract\": \"SonarrSettings\",
          \"fields\": [
            {\"name\": \"prowlarrUrl\", \"value\": \"http://127.0.0.1:${toString ports.media.prowlarr}\"},
            {\"name\": \"baseUrl\", \"value\": \"http://127.0.0.1:${toString ports.media.sonarr}\"},
            {\"name\": \"apiKey\", \"value\": \"$SONARR_KEY\"},
            {\"name\": \"syncCategories\", \"value\": [5000,5010,5020,5030,5040,5045,5050,5060,5070,5080]}
          ],
          \"tags\": []
        }" 2>&1)

      HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
      BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

      if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "Sonarr registered with Prowlarr successfully (HTTP $HTTP_CODE)"
      else
        echo "Failed to register Sonarr (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        exit 1
      fi
    '';
  };

  systemd.paths.sonarr-config-watcher = {
    description = "Watch Sonarr config for changes";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/var/lib/sonarr/config.xml";
    };
  };

  systemd.services.sonarr-config-watcher = {
    description = "Trigger Sonarr-Prowlarr sync on config change";
    serviceConfig.Type = "oneshot";
    script = ''
      echo "Sonarr config changed, triggering sync..."
      ${pkgs.systemd}/bin/systemctl restart sonarr-prowlarr-sync.service
    '';
  };

  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d /mnt/external/media 0775 sonarr media -"
    "d /mnt/external/media/tv 0775 sonarr media -"
  ];

  systemd.services.sonarr = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
    serviceConfig = {
      SupplementaryGroups = [ "external" ];
    };
  };

  users.users.pcasaretto.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "external" ];

  # Register in service registry
  services.cyberspace.registeredServices.sonarr = {
    name = "Sonarr";
    description = "TV show collection manager with automatic episode downloads";
    url = "https://sonarr.${domain}";
    icon = "📺";
    enabled = true;
    port = ports.media.sonarr;
    tags = [ "media" "automation" "tv" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."sonarr.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.sonarr}
    '';
  };
}

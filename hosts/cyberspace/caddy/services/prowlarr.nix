{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
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

  # Configure Telegram notifications via API
  systemd.services.prowlarr-telegram-setup = {
    description = "Configure Prowlarr Telegram notifications";
    after = [ "prowlarr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "prowlarr";
    };
    script = ''
      until [ -f /var/lib/prowlarr/config.xml ]; do
        sleep 1
      done
      sleep 3

      API_KEY=$(cat ${config.sops.secrets.prowlarr-api-key.path})
      BOT_TOKEN=$(cat ${config.sops.secrets.telegram-token.path})
      CHAT_ID=$(cat ${config.sops.secrets.clawdbot-telegram-chat-id.path})

      if [ -z "$API_KEY" ] || [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "Failed to get required secrets"
        exit 1
      fi

      # Wait for Prowlarr API to be ready (uses v1 API)
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/system/status -H "X-Api-Key: $API_KEY" > /dev/null; do
        sleep 2
      done

      # Check if Telegram notification already exists
      if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/notification -H "X-Api-Key: $API_KEY" | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "Telegram")' > /dev/null 2>&1; then
        echo "Telegram notification already configured"
        exit 0
      fi

      echo "Configuring Telegram notification for Prowlarr..."

      PAYLOAD=$(${pkgs.curl}/bin/curl -sf "http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/notification/schema" -H "X-Api-Key: $API_KEY" | \
        ${pkgs.jq}/bin/jq --arg token "$BOT_TOKEN" --arg chatid "$CHAT_ID" '
          .[] | select(.implementation == "Telegram") |
          .name = "Telegram" |
          .onHealthIssue = true |
          .onHealthRestored = true |
          .onApplicationUpdate = true |
          .includeHealthWarnings = true |
          (.fields[] | select(.name == "botToken").value) = $token |
          (.fields[] | select(.name == "chatId").value) = $chatid |
          (.fields[] | select(.name == "sendSilently").value) = false |
          (.fields[] | select(.name == "includeAppNameInTitle").value) = true
        ')

      ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/notification \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $API_KEY" \
        -d "$PAYLOAD" && echo "Telegram notification configured successfully" || echo "Failed to configure Telegram notification"
    '';
  };
}

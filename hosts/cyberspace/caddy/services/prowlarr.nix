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

  # Configure ntfy notifications via API
  systemd.services.prowlarr-ntfy-setup = {
    description = "Configure Prowlarr ntfy notifications";
    after = [ "prowlarr.service" "ntfy-sh.service" ];
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
      NTFY_USER=$(cat ${config.sops.secrets.ntfy-username.path})
      NTFY_PASS=$(cat ${config.sops.secrets.ntfy-password.path})

      if [ -z "$API_KEY" ] || [ -z "$NTFY_USER" ] || [ -z "$NTFY_PASS" ]; then
        echo "Failed to get required secrets"
        exit 1
      fi

      # Wait for Prowlarr API to be ready (uses v1 API)
      until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/system/status -H "X-Api-Key: $API_KEY" > /dev/null; do
        sleep 2
      done

      # Check if ntfy notification already exists
      if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/notification -H "X-Api-Key: $API_KEY" | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "ntfy")' > /dev/null 2>&1; then
        echo "ntfy notification already configured"
        exit 0
      fi

      echo "Configuring ntfy notification for Prowlarr..."

      # Build payload from schema template (more reliable than manual JSON)
      PAYLOAD=$(${pkgs.curl}/bin/curl -sf "http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/notification/schema" -H "X-Api-Key: $API_KEY" | \
        ${pkgs.jq}/bin/jq --arg user "$NTFY_USER" --arg pass "$NTFY_PASS" '
          .[] | select(.implementation == "Ntfy") |
          .name = "ntfy" |
          .onHealthIssue = true |
          .onHealthRestored = true |
          .onApplicationUpdate = true |
          .includeHealthWarnings = true |
          (.fields[] | select(.name == "serverUrl").value) = "http://127.0.0.1:${toString ports.apps.ntfy}" |
          (.fields[] | select(.name == "userName").value) = $user |
          (.fields[] | select(.name == "password").value) = $pass |
          (.fields[] | select(.name == "topics").value) = ["prowlarr"] |
          (.fields[] | select(.name == "clickUrl").value) = "https://prowlarr.${domain}"
        ')

      ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:${toString ports.media.prowlarr}/api/v1/notification \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $API_KEY" \
        -d "$PAYLOAD" && echo "ntfy notification configured successfully" || echo "Failed to configure ntfy notification"
    '';
  };
}

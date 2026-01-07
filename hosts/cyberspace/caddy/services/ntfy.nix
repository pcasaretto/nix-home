{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable ntfy notification service
  services.ntfy-sh = {
    enable = true;
    settings = {
      # Updated base-url for subdomain
      base-url = "https://ntfy.${domain}";
      listen-http = "127.0.0.1:${toString ports.apps.ntfy}";
      behind-proxy = true;

      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "12h";
      attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
      attachment-total-size-limit = "5G";
      attachment-file-size-limit = "15M";

      metrics-listen-http = "127.0.0.1:${toString ports.appExporters.ntfy}";

      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";

      visitor-subscription-limit = 30;
      visitor-request-limit-burst = 60;
      visitor-request-limit-replenish = "5s";
      visitor-message-daily-limit = 0;
    };
  };

  # Admin user provisioning service
  systemd.services.ntfy-admin-init = {
    description = "Initialize ntfy admin user from sops secrets";
    after = [ "ntfy-sh.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Run as root to create auth database, set proper permissions after
      User = "root";
    };

    script = ''
      echo "Waiting for ntfy to be ready..."
      for i in {1..30}; do
        if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.apps.ntfy}/v1/health > /dev/null 2>&1; then
          echo "ntfy is ready"
          break
        fi
        if [ $i -eq 30 ]; then
          echo "ntfy failed to start within 30 seconds"
          exit 1
        fi
        sleep 1
      done

      sleep 2

      AUTH_FILE="${config.services.ntfy-sh.settings.auth-file}"

      # Check if users already exist
      if [ -f "$AUTH_FILE" ]; then
        if ${pkgs.sqlite}/bin/sqlite3 "$AUTH_FILE" "SELECT COUNT(*) FROM user;" 2>/dev/null | grep -q "^[1-9]"; then
          echo "Users already exist in database, skipping admin user creation"
          exit 0
        fi
      fi

      # Create the auth database directory if needed and set ownership
      AUTH_DIR="$(dirname "$AUTH_FILE")"
      mkdir -p "$AUTH_DIR"
      chown ntfy-sh:ntfy-sh "$AUTH_DIR"

      ADMIN_USER=$(cat ${config.sops.secrets.ntfy-admin-username.path})
      ADMIN_PASS=$(cat ${config.sops.secrets.ntfy-admin-password.path})

      echo "No users found. Creating initial admin user: $ADMIN_USER"

      # ntfy user commands use NTFY_AUTH_FILE environment variable
      export NTFY_AUTH_FILE="$AUTH_FILE"

      echo "$ADMIN_PASS" | ${pkgs.ntfy-sh}/bin/ntfy user add --role=admin "$ADMIN_USER"

      if [ $? -eq 0 ]; then
        echo "Admin user created successfully"
        # Set proper ownership so ntfy-sh can read it
        chown ntfy-sh:ntfy-sh "$AUTH_FILE"
        chmod 640 "$AUTH_FILE"
      else
        echo "Failed to create admin user"
        exit 1
      fi
    '';
  };

  systemd.services.ntfy-sh = {
    wants = [ "ntfy-admin-init.service" ];
    after = [ "network-online.target" ];
  };

  # Register in service registry
  services.cyberspace.registeredServices.ntfy = {
    name = "ntfy";
    description = "Push notification service - send notifications to browser and phone";
    url = "https://ntfy.${domain}";
    icon = "🔔";
    enabled = true;
    port = ports.apps.ntfy;
    tags = [ "notification" "messaging" "monitoring" ];
  };

  # Configure Caddy reverse proxy with long-polling support
  services.caddy.virtualHosts."ntfy.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.ntfy} {
        # Disable buffering for SSE/WebSocket
        flush_interval -1

        # Extended timeout for long-polling (24 hours)
        transport http {
          read_timeout 86400s
        }
      }
    '';
  };
}

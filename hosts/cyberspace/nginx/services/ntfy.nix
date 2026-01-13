{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) ports;
in
{
  # Enable ntfy notification service
  services.ntfy-sh = {
    enable = true;
    settings = {
      # Network configuration
      base-url = "http://cyberspace/ntfy";
      listen-http = "127.0.0.1:${toString ports.apps.ntfy}";
      behind-proxy = true;

      # Storage
      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "12h";
      attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
      attachment-total-size-limit = "5G";
      attachment-file-size-limit = "15M";

      # Metrics (built-in Prometheus exporter)
      metrics-listen-http = "127.0.0.1:${toString ports.appExporters.ntfy}";

      # Authentication
      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";

      # Limits
      visitor-subscription-limit = 30;
      visitor-request-limit-burst = 60;
      visitor-request-limit-replenish = "5s";
      visitor-message-daily-limit = 0;  # No daily limit for authenticated users
    };
  };

  # Admin user provisioning service using sops-managed credentials
  systemd.services.ntfy-admin-init = {
    description = "Initialize ntfy admin user from sops secrets";
    after = [ "ntfy-sh.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "ntfy-sh";
      Group = "ntfy-sh";
    };

    script = ''
      # Wait for ntfy to start and be ready
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

      # Give ntfy a moment to fully initialize
      sleep 2

      # Check if user.db already exists and has users
      if [ -f "${config.services.ntfy-sh.settings.auth-file}" ]; then
        # Check if database has any users (simple check for admin)
        if ${pkgs.sqlite}/bin/sqlite3 "${config.services.ntfy-sh.settings.auth-file}" "SELECT COUNT(*) FROM user;" 2>/dev/null | grep -q "^[1-9]"; then
          echo "Users already exist in database, skipping admin user creation"
          exit 0
        fi
      fi

      # Read credentials from sops-managed secrets
      ADMIN_USER=$(cat ${config.sops.secrets.ntfy-admin-username.path})
      ADMIN_PASS=$(cat ${config.sops.secrets.ntfy-admin-password.path})

      echo "No users found. Creating initial admin user: $ADMIN_USER"

      # Create admin user via ntfy user add command
      # The ntfy CLI requires password via stdin
      echo "$ADMIN_PASS" | ${pkgs.ntfy-sh}/bin/ntfy user add \
        --config=${pkgs.writeText "ntfy-config.yml" (builtins.toJSON config.services.ntfy-sh.settings)} \
        --role=admin \
        "$ADMIN_USER"

      if [ $? -eq 0 ]; then
        echo "Admin user created successfully"

        # Grant admin user full access to all topics
        ${pkgs.ntfy-sh}/bin/ntfy user change-pass \
          --config=${pkgs.writeText "ntfy-config.yml" (builtins.toJSON config.services.ntfy-sh.settings)} \
          "$ADMIN_USER" <<EOF
$ADMIN_PASS
EOF

        echo "Admin user provisioned with full permissions"
      else
        echo "Failed to create admin user"
        exit 1
      fi
    '';
  };

  # Ensure ntfy-sh service has proper dependencies
  systemd.services.ntfy-sh = {
    wants = [ "ntfy-admin-init.service" ];
    after = [ "network-online.target" ];
  };

  # Register in service registry
  services.cyberspace.registeredServices.ntfy = {
    name = "ntfy";
    description = "Push notification service - send notifications to browser and phone";
    path = "/ntfy";
    icon = "🔔";
    enabled = true;
    port = ports.apps.ntfy;
    tags = [ "notification" "messaging" "monitoring" ];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/ntfy" = {
      return = "301 /ntfy/";
    };

    locations."^~ /ntfy/" = {
      proxyPass = "http://127.0.0.1:${toString ports.apps.ntfy}/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket/SSE support for real-time notifications
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Disable buffering for streaming
        proxy_buffering off;

        # Extended timeouts for long-polling connections
        proxy_read_timeout 86400s;
        proxy_connect_timeout 75s;
      '';
    };
  };
}

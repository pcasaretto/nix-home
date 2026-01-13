{ config, pkgs, lib, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
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

  # Configure ntfy-sh service with admin user creation
  systemd.services.ntfy-sh = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Disable DynamicUser to avoid permission issues with state directory
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "ntfy-sh";
      Group = "ntfy-sh";
      StateDirectory = "ntfy-sh";
      StateDirectoryMode = "0750";
    };

    # Create admin user after ntfy starts
    postStart = ''
      # Wait for ntfy to be ready
      for i in {1..30}; do
        if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.apps.ntfy}/v1/health > /dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      AUTH_FILE="${config.services.ntfy-sh.settings.auth-file}"
      ADMIN_USER=$(cat ${config.sops.secrets.ntfy-admin-username.path})
      ADMIN_PASS=$(cat ${config.sops.secrets.ntfy-admin-password.path})

      # Check if admin user already exists
      export NTFY_AUTH_FILE="$AUTH_FILE"
      if ${pkgs.ntfy-sh}/bin/ntfy user list 2>/dev/null | grep -q "^user $ADMIN_USER"; then
        echo "Admin user '$ADMIN_USER' already exists"
        exit 0
      fi

      echo "Creating admin user: $ADMIN_USER"
      # ntfy expects password twice (password + confirm) when piped
      printf '%s\n%s\n' "$ADMIN_PASS" "$ADMIN_PASS" | ${pkgs.ntfy-sh}/bin/ntfy user add --role=admin "$ADMIN_USER" && \
        echo "Admin user created successfully" || \
        echo "Failed to create admin user"

      # Grant admin write access to service topics
      for topic in radarr sonarr prowlarr grafana; do
        ${pkgs.ntfy-sh}/bin/ntfy access "$ADMIN_USER" "$topic" rw 2>/dev/null || true
      done
      echo "Topic permissions configured"
    '';
  };

  # Create ntfy-sh user and group
  users.users.ntfy-sh = {
    isSystemUser = true;
    group = "ntfy-sh";
    home = "/var/lib/ntfy-sh";
  };
  users.groups.ntfy-sh = {};

  # Ensure state directory has correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/ntfy-sh 0750 ntfy-sh ntfy-sh -"
    "d /var/lib/ntfy-sh/attachments 0750 ntfy-sh ntfy-sh -"
    # Fix ownership of database files if they exist with wrong permissions
    "z /var/lib/ntfy-sh/cache.db 0640 ntfy-sh ntfy-sh -"
    "z /var/lib/ntfy-sh/user.db 0640 ntfy-sh ntfy-sh -"
  ];

  # Allow ntfy-sh to read admin credentials
  sops.secrets.ntfy-admin-username.owner = lib.mkForce "ntfy-sh";
  sops.secrets.ntfy-admin-password.owner = lib.mkForce "ntfy-sh";

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

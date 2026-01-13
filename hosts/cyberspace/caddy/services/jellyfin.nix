{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
in
{
  # Enable Jellyfin media server
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    openFirewall = true;
    user = "jellyfin";
    group = "jellyfin";
  };

  # Admin user provisioning service using sops-managed credentials
  systemd.services.jellyfin-admin-init = {
    description = "Initialize Jellyfin admin user from sops secrets";
    after = [ "jellyfin.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };

    script = ''
      echo "Waiting for Jellyfin to be ready..."
      for i in {1..30}; do
        if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString ports.media.jellyfin}/health > /dev/null 2>&1; then
          echo "Jellyfin is ready"
          break
        fi
        if [ $i -eq 30 ]; then
          echo "Jellyfin failed to start within 30 seconds"
          exit 1
        fi
        sleep 1
      done

      sleep 2

      ADMIN_USER=$(cat ${config.sops.secrets.jellyfin-admin-username.path})
      ADMIN_PASS=$(cat ${config.sops.secrets.jellyfin-admin-password.path})

      USER_COUNT=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:${toString ports.media.jellyfin}/Users/Public 2>/dev/null | ${pkgs.jq}/bin/jq '. | length')

      if [ "$USER_COUNT" = "0" ]; then
        echo "No users found. Creating initial admin user: $ADMIN_USER"

        for attempt in {1..3}; do
          HTTP_CODE=$(${pkgs.curl}/bin/curl -s -w "%{http_code}" -o /tmp/jellyfin-response.txt \
            -X POST "http://127.0.0.1:${toString ports.media.jellyfin}/Startup/User" \
            -H "Content-Type: application/json" \
            -d "{\"Name\": \"$ADMIN_USER\", \"Password\": \"$ADMIN_PASS\"}")

          if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
            echo "Admin user created successfully (HTTP $HTTP_CODE)"
            ${pkgs.curl}/bin/curl -s -X POST "http://127.0.0.1:${toString ports.media.jellyfin}/Startup/Complete" \
              -H "Content-Type: application/json" > /dev/null
            echo "Startup wizard completed"
            exit 0
          else
            echo "Attempt $attempt failed with HTTP $HTTP_CODE: $(cat /tmp/jellyfin-response.txt)"
            if [ $attempt -lt 3 ]; then
              sleep 2
            fi
          fi
        done

        echo "Failed to create admin user after 3 attempts"
        exit 1
      else
        echo "Users already exist ($USER_COUNT users), skipping admin user creation"
      fi
    '';
  };

  systemd.services.jellyfin = {
    wants = [ "jellyfin-admin-init.service" ];
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
    serviceConfig = {
      SupplementaryGroups = [ "external" ];
    };
  };

  users.groups.media = {};
  users.users.pcasaretto.extraGroups = [ "media" ];
  users.users.jellyfin.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "d /mnt/external/media/music 0775 jellyfin media -"
    "d /mnt/external/media/photos 0775 jellyfin media -"
  ];

  # Register in service registry
  services.cyberspace.registeredServices.jellyfin = {
    name = "Jellyfin";
    description = "Media server for streaming movies, TV shows, and music";
    url = "https://jellyfin.${domain}";
    icon = "🎬";
    enabled = true;
    port = ports.media.jellyfin;
    tags = [ "media" "streaming" "entertainment" ];
  };

  # Configure Caddy reverse proxy with streaming support
  services.caddy.virtualHosts."jellyfin.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.jellyfin} {
        # Disable buffering for video streaming
        flush_interval -1

        # Extended timeouts for streaming
        transport http {
          read_timeout 0
          write_timeout 0
        }
      }
    '';
  };

  # Allow direct Jellyfin access on Tailscale for native apps
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ ports.media.jellyfin ];
}

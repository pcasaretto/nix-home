{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) ports;
in
{
  # Enable Jellyfin media server (using standard nixpkgs package with ARM64 support)
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    openFirewall = false;
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
      User = "root";  # Need root to read secrets and access Jellyfin API
    };

    script = ''
      # Wait for Jellyfin to start and be ready
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

      # Give Jellyfin a moment to fully initialize its API
      sleep 2

      # Read credentials from sops-managed secrets
      ADMIN_USER=$(cat ${config.sops.secrets.jellyfin-admin-username.path})
      ADMIN_PASS=$(cat ${config.sops.secrets.jellyfin-admin-password.path})

      # Check if users already exist
      USER_COUNT=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:${toString ports.media.jellyfin}/Users/Public 2>/dev/null | ${pkgs.jq}/bin/jq '. | length')

      if [ "$USER_COUNT" = "0" ]; then
        echo "No users found. Creating initial admin user: $ADMIN_USER"

        # Create admin user via Startup/User endpoint (retry a few times if needed)
        for attempt in {1..3}; do
          HTTP_CODE=$(${pkgs.curl}/bin/curl -s -w "%{http_code}" -o /tmp/jellyfin-response.txt \
            -X POST "http://127.0.0.1:${toString ports.media.jellyfin}/Startup/User" \
            -H "Content-Type: application/json" \
            -d "{\"Name\": \"$ADMIN_USER\", \"Password\": \"$ADMIN_PASS\"}")

          if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
            echo "Admin user created successfully (HTTP $HTTP_CODE)"

            # Complete the startup wizard
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

  # Ensure the init service runs after jellyfin is up, and mount dependency
  systemd.services.jellyfin = {
    wants = [ "jellyfin-admin-init.service" ];
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
    serviceConfig = {
      # Allow access to media and download directories
      SupplementaryGroups = [ "external" ];
    };
  };

  # Create media group for shared access to media files
  users.groups.media = {};

  # Add pcasaretto user to media group for file management
  users.users.pcasaretto.extraGroups = [ "media" ];

  # Add jellyfin user to media group for reading media files
  users.users.jellyfin.extraGroups = [ "media" ];

  # Ensure media directory structure exists with proper permissions
  # Note: /mnt/external/media, /mnt/external/media/movies, and /mnt/external/media/tv
  # are already created by radarr and sonarr services
  systemd.tmpfiles.rules = [
    "d /mnt/external/media/music 0775 jellyfin media -"
    "d /mnt/external/media/photos 0775 jellyfin media -"
  ];

  # Register in service registry
  services.cyberspace.registeredServices.jellyfin = {
    name = "Jellyfin";
    description = "Media server for streaming movies, TV shows, and music";
    path = "/jellyfin";
    icon = "🎬";
    enabled = true;
    port = ports.media.jellyfin;
    tags = [ "media" "streaming" "entertainment" ];
  };

  # Configure nginx reverse proxy (similar to Sonarr pattern)
  services.nginx.virtualHosts."cyberspace" = {
    locations."^~ /jellyfin" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.jellyfin}";
      extraConfig = ''
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Disable buffering for video streaming
        proxy_buffering off;

        # Large file support
        client_max_body_size 0;
      '';
    };
  };
}

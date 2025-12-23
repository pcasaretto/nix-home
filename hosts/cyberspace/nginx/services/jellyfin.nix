{ config, pkgs, ... }:

let
  # Rebuild Jellyfin 10.10.7 with .NET 8 from scratch
  jellyfin-10-10-7 = pkgs.buildDotnetModule rec {
    pname = "jellyfin";
    version = "10.10.7";

    src = pkgs.fetchFromGitHub {
      owner = "jellyfin";
      repo = "jellyfin";
      rev = "v${version}";
      hash = "sha256-GWpzX8DvCafHb5V9it0ZPTXKm+NbLS7Oepe/CcMiFuI=";
    };

    propagatedBuildInputs = [ pkgs.sqlite ];

    projectFile = "Jellyfin.Server/Jellyfin.Server.csproj";
    executables = [ "jellyfin" ];
    nugetDeps = ./jellyfin-nuget-deps.json;

    runtimeDeps = [
      pkgs.jellyfin-ffmpeg
      pkgs.fontconfig
      pkgs.freetype
    ];

    # Use .NET 8
    dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0;
    dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_8_0;

    dotnetBuildFlags = [ "--no-self-contained" ];

    makeWrapperArgs = [
      "--add-flags"
      "--ffmpeg=${pkgs.jellyfin-ffmpeg}/bin/ffmpeg"
      "--add-flags"
      "--webdir=${pkgs.jellyfin-web}/share/jellyfin-web"
    ];

    meta = pkgs.jellyfin.meta;
  };
in
{
  # Enable Jellyfin media server (downgraded to 10.10.7)
  services.jellyfin = {
    enable = false;
    package = jellyfin-10-10-7;
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
        if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:8096/health > /dev/null 2>&1; then
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
      USER_COUNT=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:8096/Users/Public 2>/dev/null | ${pkgs.jq}/bin/jq '. | length')

      if [ "$USER_COUNT" = "0" ]; then
        echo "No users found. Creating initial admin user: $ADMIN_USER"

        # Create admin user via Startup/User endpoint (retry a few times if needed)
        for attempt in {1..3}; do
          HTTP_CODE=$(${pkgs.curl}/bin/curl -s -w "%{http_code}" -o /tmp/jellyfin-response.txt \
            -X POST "http://127.0.0.1:8096/Startup/User" \
            -H "Content-Type: application/json" \
            -d "{\"Name\": \"$ADMIN_USER\", \"Password\": \"$ADMIN_PASS\"}")

          if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
            echo "Admin user created successfully (HTTP $HTTP_CODE)"

            # Complete the startup wizard
            ${pkgs.curl}/bin/curl -s -X POST "http://127.0.0.1:8096/Startup/Complete" \
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

  # Ensure the init service runs after jellyfin is up
  systemd.services.jellyfin.wants = [ "jellyfin-admin-init.service" ];

  # Create media group for shared access to media files
  users.groups.media = {};

  # Add pcasaretto user to media group for file management
  users.users.pcasaretto.extraGroups = [ "media" ];

  # Add jellyfin user to media group for reading media files
  users.users.jellyfin.extraGroups = [ "media" ];

  # Ensure media directory structure exists with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt/external/media 0775 jellyfin media -"
    "d /mnt/external/media/Movies 0775 jellyfin media -"
    "d /mnt/external/media/TV\\ Shows 0775 jellyfin media -"
    "d /mnt/external/media/Music 0775 jellyfin media -"
    "d /mnt/external/media/Photos 0775 jellyfin media -"
  ];

  # Register in service registry
  services.cyberspace.registeredServices.jellyfin = {
    name = "Jellyfin";
    description = "Media server for streaming movies, TV shows, and music";
    path = "/jellyfin";
    icon = "🎬";
    enabled = true;
    port = 8096;
    tags = [ "media" "streaming" "entertainment" ];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/jellyfin/" = {
      proxyPass = "http://127.0.0.1:8096/";
      proxyWebsockets = true;  # Enable WebSocket support for real-time features

      extraConfig = ''
        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Protocol $scheme;
        proxy_set_header X-Forwarded-Host $http_host;

        # Critical for video streaming - disable buffering
        proxy_buffering off;
        proxy_cache off;
        proxy_request_buffering off;

        # Large file support for subtitle/media uploads
        client_max_body_size 1G;

        # Extended timeouts for transcoding operations
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
      '';
    };
  };
}

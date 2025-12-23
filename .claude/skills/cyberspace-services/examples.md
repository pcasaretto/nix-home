# Real-World Service Examples

Complete examples of services you might want to add to your cyberspace service registry.

## Table of Contents

1. [Jellyfin Media Server](#jellyfin-media-server)
2. [Nextcloud Personal Cloud](#nextcloud-personal-cloud)
3. [Gitea Git Server](#gitea-git-server)
4. [Grafana Monitoring Dashboard](#grafana-monitoring-dashboard)
5. [Personal Wiki (Wiki.js)](#personal-wiki-wikijs)
6. [RSS Reader (Miniflux)](#rss-reader-miniflux)
7. [Photo Gallery (PhotoPrism)](#photo-gallery-photoprism)
8. [Code Server (VS Code in Browser)](#code-server-vs-code-in-browser)

---

## Jellyfin Media Server

A complete media server setup for movies, TV shows, and music.

**File**: `hosts/cyberspace/nginx/services/jellyfin.nix`

```nix
{ config, pkgs, ... }:

{
  # Enable Jellyfin service
  services.jellyfin = {
    enable = true;
    openFirewall = false;  # We only access via Tailscale
  };

  # Register in service registry
  services.cyberspace.registeredServices.jellyfin = {
    name = "Jellyfin";
    description = "Media server for movies, TV shows, and music";
    path = "/jellyfin";
    icon = "🎬";
    enabled = true;
    port = 8096;
    tags = ["media" "entertainment" "video"];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/jellyfin/" = {
      proxyPass = "http://127.0.0.1:8096/jellyfin/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;

        # Disable buffering for better streaming
        proxy_buffering off;

        # WebSocket support for live updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };

  # Optional: Configure media directories
  # systemd.tmpfiles.rules = [
  #   "d /media/movies 0755 jellyfin jellyfin"
  #   "d /media/tv 0755 jellyfin jellyfin"
  #   "d /media/music 0755 jellyfin jellyfin"
  # ];
}
```

**Usage**:
1. Access Jellyfin at `http://<tailscale-ip>/jellyfin`
2. Complete initial setup wizard
3. Add media libraries pointing to your media directories
4. Stream from any device on Tailscale network

---

## Nextcloud Personal Cloud

Self-hosted cloud storage and collaboration platform.

**File**: `hosts/cyberspace/nginx/services/nextcloud.nix`

```nix
{ config, pkgs, ... }:

{
  # Enable Nextcloud
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud28;
    hostName = "cyberspace.local";

    config = {
      adminpassFile = "/var/lib/nextcloud/admin-pass";

      dbtype = "pgsql";
      dbhost = "/run/postgresql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
    };

    # Additional settings
    settings = {
      overwriteprotocol = "http";
      default_phone_region = "BR";
    };
  };

  # PostgreSQL for Nextcloud
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [{
      name = "nextcloud";
      ensureDBOwnership = true;
    }];
  };

  # Register in service registry
  services.cyberspace.registeredServices.nextcloud = {
    name = "Nextcloud";
    description = "Personal cloud storage and collaboration";
    path = "/nextcloud";
    icon = "☁️";
    enabled = true;
    port = 80;  # Nextcloud runs on standard HTTP
    tags = ["productivity" "storage" "sync"];
  };

  # Nginx is automatically configured by the Nextcloud module
  # But we can add our registry-specific location
  services.nginx.virtualHosts."cyberspace.local" = {
    listen = [
      { addr = "127.0.0.1"; port = 8084; }
    ];
  };

  services.nginx.virtualHosts."cyberspace" = {
    locations."/nextcloud/" = {
      proxyPass = "http://127.0.0.1:8084/";
      extraConfig = ''
        proxy_set_header Host cyberspace.local;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebDAV support
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Increase upload size limit
        client_max_body_size 10G;
        proxy_request_buffering off;
      '';
    };
  };

  # Create admin password file (manual step)
  # Run: echo "your-secure-password" > /var/lib/nextcloud/admin-pass
  # Run: chown nextcloud:nextcloud /var/lib/nextcloud/admin-pass
  # Run: chmod 600 /var/lib/nextcloud/admin-pass
}
```

**Setup**:
1. Create admin password file (see comments in code)
2. Rebuild system
3. Access at `http://<tailscale-ip>/nextcloud`
4. Log in with username `admin` and password from file

---

## Gitea Git Server

Self-hosted Git server with web interface.

**File**: `hosts/cyberspace/nginx/services/gitea.nix`

```nix
{ config, pkgs, ... }:

{
  # Enable Gitea
  services.gitea = {
    enable = true;
    settings = {
      server = {
        DOMAIN = "cyberspace";
        HTTP_PORT = 3001;
        ROOT_URL = "http://%(DOMAIN)s/gitea/";
      };
      service = {
        DISABLE_REGISTRATION = true;  # Prevent public registration
      };
    };
  };

  # Register in service registry
  services.cyberspace.registeredServices.gitea = {
    name = "Gitea";
    description = "Self-hosted Git server";
    path = "/gitea";
    icon = "🦊";
    enabled = true;
    port = 3001;
    tags = ["development" "git" "code"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/gitea/" = {
      proxyPass = "http://127.0.0.1:3001/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Increase buffer size for Git operations
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 32 4k;

        # Increase timeouts for large repos
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
      '';
    };
  };
}
```

**Setup**:
1. Access at `http://<tailscale-ip>/gitea`
2. Complete initial configuration
3. Create admin account
4. Push your repos to Gitea

---

## Grafana Monitoring Dashboard

Monitoring and visualization dashboard.

**File**: `hosts/cyberspace/nginx/services/grafana.nix`

```nix
{ config, pkgs, ... }:

{
  # Enable Grafana
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3002;
        root_url = "http://%(domain)s/grafana/";
        serve_from_sub_path = true;
      };
      security = {
        admin_user = "admin";
        admin_password = "$__file{/var/lib/grafana/admin-password}";
      };
    };
  };

  # Enable Prometheus for metrics collection
  services.prometheus = {
    enable = true;
    port = 9090;

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9100;
      };
    };
  };

  # Register in service registry
  services.cyberspace.registeredServices.grafana = {
    name = "Grafana";
    description = "Monitoring and visualization dashboard";
    path = "/grafana";
    icon = "📊";
    enabled = true;
    port = 3002;
    tags = ["monitoring" "metrics" "system"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/grafana/" = {
      proxyPass = "http://127.0.0.1:3002/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support for live updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };

  # Create admin password file
  # Run: echo "your-secure-password" > /var/lib/grafana/admin-password
  # Run: chown grafana:grafana /var/lib/grafana/admin-password
  # Run: chmod 600 /var/lib/grafana/admin-password
}
```

**Setup**:
1. Create admin password file (see comments)
2. Rebuild system
3. Access at `http://<tailscale-ip>/grafana`
4. Add Prometheus data source: `http://localhost:9090`
5. Import dashboards from grafana.com

---

## Personal Wiki (Wiki.js)

A modern documentation and wiki platform.

**File**: `hosts/cyberspace/nginx/services/wikijs.nix`

```nix
{ config, pkgs, ... }:

{
  # Wiki.js runs via Docker
  virtualisation.docker.enable = true;

  # PostgreSQL for Wiki.js
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "wikijs" ];
    ensureUsers = [{
      name = "wikijs";
      ensureDBOwnership = true;
    }];
  };

  # Create systemd service for Wiki.js container
  systemd.services.wikijs = {
    description = "Wiki.js";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "postgresql.service" ];
    requires = [ "docker.service" "postgresql.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = ''
        ${pkgs.docker}/bin/docker run -d \
          --name wikijs \
          --restart unless-stopped \
          -p 127.0.0.1:3003:3000 \
          -e DB_TYPE=postgres \
          -e DB_HOST=/var/run/postgresql \
          -e DB_PORT=5432 \
          -e DB_NAME=wikijs \
          -e DB_USER=wikijs \
          -v /var/lib/wikijs:/wiki/data \
          --network host \
          ghcr.io/requarks/wiki:2
      '';

      ExecStop = "${pkgs.docker}/bin/docker stop wikijs";
      ExecStopPost = "${pkgs.docker}/bin/docker rm -f wikijs";
    };
  };

  # Register in service registry
  services.cyberspace.registeredServices.wikijs = {
    name = "Wiki.js";
    description = "Personal knowledge base and documentation";
    path = "/wiki";
    icon = "📖";
    enabled = true;
    port = 3003;
    tags = ["productivity" "docs" "knowledge"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/wiki/" = {
      proxyPass = "http://127.0.0.1:3003/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket for live updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };

  # Create data directory
  systemd.tmpfiles.rules = [
    "d /var/lib/wikijs 0755 root root"
  ];
}
```

---

## RSS Reader (Miniflux)

Minimalist RSS feed reader.

**File**: `hosts/cyberspace/nginx/services/miniflux.nix`

```nix
{ config, pkgs, ... }:

{
  # PostgreSQL for Miniflux
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "miniflux" ];
    ensureUsers = [{
      name = "miniflux";
      ensureDBOwnership = true;
    }];
  };

  # Miniflux service
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR = "127.0.0.1:8085";
      BASE_URL = "http://cyberspace/miniflux/";
      DATABASE_URL = "postgres://miniflux@/miniflux?host=/run/postgresql";
    };
    adminCredentialsFile = "/var/lib/miniflux/credentials";
  };

  # Register in service registry
  services.cyberspace.registeredServices.miniflux = {
    name = "Miniflux";
    description = "Minimalist RSS feed reader";
    path = "/miniflux";
    icon = "📰";
    enabled = true;
    port = 8085;
    tags = ["productivity" "news" "rss"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/miniflux/" = {
      proxyPass = "http://127.0.0.1:8085/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  # Create credentials file
  # Format: ADMIN_USERNAME=admin
  #         ADMIN_PASSWORD=your-secure-password
  # Run: sudo touch /var/lib/miniflux/credentials
  # Run: sudo chown miniflux:miniflux /var/lib/miniflux/credentials
  # Run: sudo chmod 600 /var/lib/miniflux/credentials
}
```

---

## Photo Gallery (PhotoPrism)

AI-powered photo management application.

**File**: `hosts/cyberspace/nginx/services/photoprism.nix`

```nix
{ config, pkgs, ... }:

{
  # PhotoPrism runs via Docker
  virtualisation.docker.enable = true;

  # Create systemd service for PhotoPrism
  systemd.services.photoprism = {
    description = "PhotoPrism";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = ''
        ${pkgs.docker}/bin/docker run -d \
          --name photoprism \
          --restart unless-stopped \
          -p 127.0.0.1:2342:2342 \
          -e PHOTOPRISM_ADMIN_PASSWORD=changeme \
          -e PHOTOPRISM_SITE_URL=http://cyberspace/photos/ \
          -e PHOTOPRISM_DISABLE_TLS=true \
          -v /var/lib/photoprism/storage:/photoprism/storage \
          -v /var/lib/photoprism/originals:/photoprism/originals \
          photoprism/photoprism:latest
      '';

      ExecStop = "${pkgs.docker}/bin/docker stop photoprism";
      ExecStopPost = "${pkgs.docker}/bin/docker rm -f photoprism";
    };
  };

  # Register in service registry
  services.cyberspace.registeredServices.photoprism = {
    name = "PhotoPrism";
    description = "AI-powered photo gallery and management";
    path = "/photos";
    icon = "📸";
    enabled = true;
    port = 2342;
    tags = ["media" "photos" "gallery"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/photos/" = {
      proxyPass = "http://127.0.0.1:2342/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Large upload support
        client_max_body_size 500M;
        proxy_request_buffering off;
      '';
    };
  };

  # Create data directories
  systemd.tmpfiles.rules = [
    "d /var/lib/photoprism 0755 root root"
    "d /var/lib/photoprism/storage 0755 root root"
    "d /var/lib/photoprism/originals 0755 root root"
  ];
}
```

---

## Code Server (VS Code in Browser)

Run Visual Studio Code in your browser.

**File**: `hosts/cyberspace/nginx/services/code-server.nix`

```nix
{ config, pkgs, ... }:

{
  # Code Server service
  services.code-server = {
    enable = true;
    host = "127.0.0.1";
    port = 8086;
    user = "pcasaretto";
    extraEnvironment = {
      PASSWORD = "changeme";  # Change this!
    };
    extraArguments = [
      "--disable-telemetry"
    ];
  };

  # Register in service registry
  services.cyberspace.registeredServices.code-server = {
    name = "Code Server";
    description = "VS Code running in the browser";
    path = "/code";
    icon = "💻";
    enabled = true;
    port = 8086;
    tags = ["development" "editor" "code"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/code/" = {
      proxyPass = "http://127.0.0.1:8086/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # WebSocket support for VS Code
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts for long sessions
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
      '';
    };
  };
}
```

**Setup**:
1. Change the PASSWORD in the configuration
2. Rebuild system
3. Access at `http://<tailscale-ip>/code`
4. Enter password to access VS Code

---

## Common Patterns Across Examples

### Port Management
Examples use ports in organized ranges:
- 3000-3999: Node.js apps (Gitea: 3001, Grafana: 3002, Wiki.js: 3003)
- 8000-8099: Python apps and general services (Miniflux: 8085, Code Server: 8086)
- 8096: Jellyfin (standard port)
- 2342: PhotoPrism (standard port)

### Security Considerations
All examples:
- Bind only to `127.0.0.1` (localhost)
- Proxy via nginx on Tailscale interface
- No public internet exposure
- Use password files or secrets where possible

### Database Pattern
Services with databases (Nextcloud, Gitea, Wiki.js):
- Use PostgreSQL via NixOS module
- Ensure database with `ensureDatabases`
- Ensure user with `ensureUsers`
- Connect via Unix socket when possible

### Docker Pattern
Docker-based services (Wiki.js, PhotoPrism):
- Enable Docker module
- Create systemd service to manage container
- Bind container port to `127.0.0.1`
- Use `-v` for persistent storage
- Handle start/stop/cleanup in systemd

### Directory Structure
Persistent data typically stored in:
- `/var/lib/<service-name>/` - Service data
- `/var/lib/<service-name>/config` - Configuration
- `/var/lib/<service-name>/data` - User data
- Create with `systemd.tmpfiles.rules`

## Next Steps

After implementing any of these examples:

1. **Test locally**: Verify the service works on localhost
2. **Check logs**: `sudo journalctl -u <service-name> -f`
3. **Verify dashboard**: Service appears in registry
4. **Test from another device**: Access via Tailscale IP
5. **Configure service**: Complete any initial setup wizards
6. **Backup**: Plan backup strategy for `/var/lib/<service>/`

## Customization Tips

- Adjust port numbers to avoid conflicts
- Modify paths to organize services (`/media/jellyfin`, `/tools/code`, etc.)
- Change icons to your preference
- Add/modify tags for better organization
- Increase `client_max_body_size` for file upload services
- Adjust timeouts based on service needs

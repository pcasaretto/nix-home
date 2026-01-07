# Cyberspace Service Templates

Complete, copy-paste ready templates for common service types using Caddy with subdomain routing and Let's Encrypt TLS.

## Table of Contents

1. [Simple Reverse Proxy](#simple-reverse-proxy)
2. [Streaming Application](#streaming-application)
3. [Media Server](#media-server)
4. [Static Website](#static-website)
5. [Long-Polling/SSE Service](#long-pollingsse-service)
6. [Docker Container Proxy](#docker-container-proxy)
7. [Python Web Application](#python-web-application)
8. [Node.js Application](#nodejs-application)
9. [File Upload Service](#file-upload-service)
10. [API with Large Requests](#api-with-large-requests)

---

## Simple Reverse Proxy

Basic reverse proxy to a local service.

**File**: `hosts/cyberspace/caddy/services/myapp.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Register in service registry
  services.cyberspace.registeredServices.myapp = {
    name = "My Application";
    description = "Application running on port 8080";
    url = "https://myapp.${domain}";
    icon = "🚀";
    enabled = true;
    port = ports.apps.myapp;
    tags = [ "app" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."myapp.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.myapp}
    '';
  };
}
```

---

## Streaming Application

For WebSocket, SSE, or streaming responses.

**File**: `hosts/cyberspace/caddy/services/streamapp.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.streamapp = {
    name = "Streaming App";
    description = "Real-time streaming application";
    url = "https://streamapp.${domain}";
    icon = "📡";
    enabled = true;
    port = ports.apps.streamapp;
    tags = [ "streaming" "realtime" ];
  };

  services.caddy.virtualHosts."streamapp.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.streamapp} {
        # Disable buffering for streaming
        flush_interval -1

        # Extended timeouts for long connections
        transport http {
          read_timeout 300s
          write_timeout 300s
        }
      }
    '';
  };
}
```

---

## Media Server

For video/audio streaming (Jellyfin, Plex, etc.).

**File**: `hosts/cyberspace/caddy/services/media.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable media server
  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };

  services.cyberspace.registeredServices.media = {
    name = "Media Server";
    description = "Stream movies, TV shows, and music";
    url = "https://media.${domain}";
    icon = "🎬";
    enabled = true;
    port = ports.media.jellyfin;
    tags = [ "media" "streaming" "entertainment" ];
  };

  services.caddy.virtualHosts."media.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.jellyfin} {
        # Disable buffering for video streaming
        flush_interval -1

        # No timeout for media streaming
        transport http {
          read_timeout 0
          write_timeout 0
        }
      }
    '';
  };
}
```

---

## Static Website

Serve static HTML/CSS/JS files.

**File**: `hosts/cyberspace/caddy/services/mysite.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;

  # Generate static content at build time
  webRoot = pkgs.runCommand "mysite-webroot" {} ''
    mkdir -p $out/css $out/js

    cat > $out/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My Site</title>
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
  <h1>Welcome to My Site</h1>
  <p>Built with NixOS and Caddy!</p>
</body>
</html>
EOF

    cat > $out/css/style.css <<'EOF'
body {
  font-family: system-ui, sans-serif;
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  background: #f5f5f5;
}
h1 { color: #333; }
EOF
  '';
in
{
  services.cyberspace.registeredServices.mysite = {
    name = "My Site";
    description = "Static website";
    url = "https://mysite.${domain}";
    icon = "🌐";
    enabled = true;
    tags = [ "web" "static" ];
  };

  services.caddy.virtualHosts."mysite.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      root * ${webRoot}
      file_server

      # Cache static assets
      @static {
        path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg *.woff *.woff2
      }
      header @static Cache-Control "public, max-age=2592000"
    '';
  };
}
```

---

## Long-Polling/SSE Service

For notification services with 24+ hour connections.

**File**: `hosts/cyberspace/caddy/services/notify.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.notify = {
    name = "Notifications";
    description = "Push notification service";
    url = "https://notify.${domain}";
    icon = "🔔";
    enabled = true;
    port = ports.apps.notify;
    tags = [ "notification" "messaging" ];
  };

  services.caddy.virtualHosts."notify.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.notify} {
        # Disable buffering for SSE
        flush_interval -1

        # 24-hour timeout for long-polling
        transport http {
          read_timeout 86400s
        }
      }
    '';
  };
}
```

---

## Docker Container Proxy

Proxy to a service running in Docker/Podman.

**File**: `hosts/cyberspace/caddy/services/dockerapp.nix`

```nix
{ config, pkgs, lib, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Run container with Podman
  virtualisation.oci-containers = {
    backend = "podman";

    containers.mycontainer = {
      image = "nginx:alpine";
      ports = [
        "${toString ports.apps.dockerapp}:80"
      ];
      autoStart = true;
    };
  };

  services.cyberspace.registeredServices.dockerapp = {
    name = "Docker App";
    description = "Application running in container";
    url = "https://dockerapp.${domain}";
    icon = "🐳";
    enabled = true;
    port = ports.apps.dockerapp;
    tags = [ "docker" "container" ];
  };

  services.caddy.virtualHosts."dockerapp.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.dockerapp}
    '';
  };
}
```

---

## Python Web Application

Run a Python Flask/FastAPI application with systemd.

**File**: `hosts/cyberspace/caddy/services/pyapp.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Create systemd service
  systemd.services.pyapp = {
    description = "Python Web Application";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      # Using a simple HTTP server as example
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString ports.apps.pyapp}";
      WorkingDirectory = "/var/lib/pyapp";
      Restart = "always";
      RestartSec = "10s";
      User = "pyapp";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/pyapp" ];
    };

    environment = {
      PYTHONUNBUFFERED = "1";
    };
  };

  users.users.pyapp = {
    isSystemUser = true;
    group = "pyapp";
    home = "/var/lib/pyapp";
    createHome = true;
  };

  users.groups.pyapp = {};

  services.cyberspace.registeredServices.pyapp = {
    name = "Python App";
    description = "Python web application";
    url = "https://pyapp.${domain}";
    icon = "🐍";
    enabled = true;
    port = ports.apps.pyapp;
    tags = [ "python" "backend" ];
  };

  services.caddy.virtualHosts."pyapp.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.pyapp}
    '';
  };
}
```

---

## Node.js Application

Run a Node.js application with systemd.

**File**: `hosts/cyberspace/caddy/services/nodeapp.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  systemd.services.nodeapp = {
    description = "Node.js Application";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nodejs}/bin/node /var/lib/nodeapp/server.js";
      WorkingDirectory = "/var/lib/nodeapp";
      Restart = "always";
      RestartSec = "10s";
      User = "nodeapp";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/nodeapp" ];
    };

    environment = {
      NODE_ENV = "production";
      PORT = toString ports.apps.nodeapp;
    };
  };

  users.users.nodeapp = {
    isSystemUser = true;
    group = "nodeapp";
    home = "/var/lib/nodeapp";
    createHome = true;
  };

  users.groups.nodeapp = {};

  services.cyberspace.registeredServices.nodeapp = {
    name = "Node.js App";
    description = "Node.js application";
    url = "https://nodeapp.${domain}";
    icon = "📗";
    enabled = true;
    port = ports.apps.nodeapp;
    tags = [ "nodejs" "backend" ];
  };

  services.caddy.virtualHosts."nodeapp.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.apps.nodeapp} {
        # Keep-alive for efficiency
        transport http {
          keepalive 30s
        }
      }
    '';
  };
}
```

---

## File Upload Service

Service with large file upload support.

**File**: `hosts/cyberspace/caddy/services/upload.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.upload = {
    name = "File Upload";
    description = "Large file upload service";
    url = "https://upload.${domain}";
    icon = "📤";
    enabled = true;
    port = ports.apps.upload;
    tags = [ "files" "upload" ];
  };

  services.caddy.virtualHosts."upload.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}

      # Allow large uploads (1GB)
      request_body {
        max_size 1GB
      }

      reverse_proxy http://127.0.0.1:${toString ports.apps.upload} {
        # Extended timeouts for large uploads
        transport http {
          read_timeout 600s
          write_timeout 600s
        }
      }
    '';
  };
}
```

---

## API with Large Requests

API service with CORS and large request body support.

**File**: `hosts/cyberspace/caddy/services/api.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.api = {
    name = "API";
    description = "REST API service";
    url = "https://api.${domain}";
    icon = "🔌";
    enabled = true;
    port = ports.apps.api;
    tags = [ "api" "backend" ];
  };

  services.caddy.virtualHosts."api.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}

      # CORS headers
      header {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Authorization, Content-Type"
      }

      # Handle preflight
      @options method OPTIONS
      respond @options 204

      # Large request bodies
      request_body {
        max_size 100MB
      }

      reverse_proxy http://127.0.0.1:${toString ports.apps.api}
    '';
  };
}
```

---

## Template Usage Checklist

To use a template:

1. [ ] Copy the template code
2. [ ] Create file: `hosts/cyberspace/caddy/services/<name>.nix`
3. [ ] Add port to `hosts/cyberspace/ports.nix`
4. [ ] Replace placeholders:
   - Service name
   - Display name and description
   - Subdomain
   - Icon and tags
   - Port reference
5. [ ] Add import to `hosts/cyberspace/caddy/services/default.nix`
6. [ ] Rebuild: `sudo nixos-rebuild switch --flake .#cyberspace`
7. [ ] Verify: `journalctl -u caddy -f`
8. [ ] Test: `https://<subdomain>.cyberspace.pcasaretto.com`

## Key Points

### Always Include TLS Config

Every virtualHost MUST include:
```nix
${config.services.cyberspace.tlsConfig}
```

This provides Let's Encrypt TLS via Cloudflare DNS-01 challenge.

### Use Port Variables

Always reference ports via config:
```nix
ports = config.services.cyberspace.ports;
# ...
port = ports.apps.myapp;
```

### Subdomain Naming

- Use lowercase
- Avoid hyphens when possible
- Keep it short and memorable
- Example: `grafana`, `sonarr`, `jellyfin`

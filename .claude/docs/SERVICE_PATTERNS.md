# Service Configuration Patterns Reference

This document provides concrete code patterns extracted from working cyberspace services. Use these as templates when adding new services.

## Table of Contents

1. [Service Configuration Patterns](#service-configuration-patterns)
2. [Nginx Reverse Proxy Patterns](#nginx-reverse-proxy-patterns)
3. [Prometheus Exporter Patterns](#prometheus-exporter-patterns)
4. [Grafana Dashboard Provisioning](#grafana-dashboard-provisioning)
5. [Sops Secrets Integration](#sops-secrets-integration)
6. [Port Allocations](#port-allocations)

---

## Service Configuration Patterns

### Pattern A: Simple Service (Transmission)

**Use for:** Services that don't need API keys or complex setup

```nix
{ config, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
in
{
  # Enable service
  services.transmission = {
    enable = true;
    settings = {
      rpc-bind-address = "127.0.0.1";
      rpc-port = ports.apps.transmission;
      rpc-authentication-required = false;
      download-dir = "/mnt/external/downloads";
    };
    user = "transmission";
    group = "external";
  };

  # Create directories
  systemd.tmpfiles.rules = [
    "d /mnt/external/downloads 0775 transmission external -"
  ];

  # Mount dependencies
  systemd.services.transmission = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
  };

  # User groups
  users.users.transmission.extraGroups = [ "external" ];

  # Register in service registry
  services.cyberspace.registeredServices.transmission = {
    name = "Transmission";
    description = "BitTorrent client with web interface";
    path = "/transmission";
    icon = "📥";
    enabled = true;
    port = ports.apps.transmission;
    tags = [ "download" "torrent" ];
  };

  # Nginx configuration (see nginx section)
}
```

**Source:** `hosts/cyberspace/nginx/services/transmission.nix`

---

### Pattern B: Service with API Key (*arr Services)

**Use for:** Services requiring API keys and authentication

```nix
{ config, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
in
{
  # Enable service
  services.radarr = {
    enable = true;
    openFirewall = false;
    user = "radarr";
    group = "media";
    dataDir = "/var/lib/radarr";

    # Configure URL base for reverse proxy
    settings = {
      server = {
        urlbase = "/radarr";
      };
    };
  };

  # Inject API key from sops in preStart
  systemd.services.radarr.preStart = ''
    CONFIG_FILE="/var/lib/radarr/config.xml"
    API_KEY=$(cat ${config.sops.secrets.radarr-api-key.path})

    if [ -f "$CONFIG_FILE" ]; then
      # Remove existing keys
      sed -i '/<AuthenticationMethod>/d' "$CONFIG_FILE"
      sed -i '/<ApiKey>/d' "$CONFIG_FILE"
      # Add new values
      sed -i 's|</Config>|  <AuthenticationMethod>External</AuthenticationMethod>\n</Config>|' "$CONFIG_FILE"
      sed -i "s|</Config>|  <ApiKey>$API_KEY</ApiKey>\n</Config>|" "$CONFIG_FILE"
    else
      # Create initial config
      cat > "$CONFIG_FILE" << EOF
<Config>
  <ApiKey>$API_KEY</ApiKey>
  <AuthenticationMethod>External</AuthenticationMethod>
</Config>
EOF
    fi
  '';

  # Create media directories
  systemd.tmpfiles.rules = [
    "d /mnt/external/media 0775 radarr media -"
    "d /mnt/external/media/movies 0775 radarr media -"
  ];

  # Mount dependencies
  systemd.services.radarr = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
    serviceConfig = {
      SupplementaryGroups = [ "external" ];
    };
  };

  # User groups
  users.users.radarr.extraGroups = [ "external" ];

  # Register in service registry
  services.cyberspace.registeredServices.radarr = {
    name = "Radarr";
    description = "Movie collection manager with automatic downloads";
    path = "/radarr";
    icon = "🎬";
    enabled = true;
    port = ports.media.radarr;
    tags = [ "media" "automation" "movies" ];
  };

  # Nginx configuration (see nginx section)
}
```

**Source:** `hosts/cyberspace/nginx/services/radarr.nix`

---

## Nginx Reverse Proxy Patterns

### Pattern A: Simple Reverse Proxy

**Use for:** Basic proxying without authentication

```nix
services.nginx.virtualHosts."cyberspace" = {
  locations."/transmission/" = {
    proxyPass = "http://127.0.0.1:${toString ports.apps.transmission}/transmission/";
    extraConfig = ''
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      # Pass through the RPC path
      proxy_pass_header X-Transmission-Session-Id;

      # Timeouts for long-running requests
      proxy_read_timeout 300s;
      proxy_connect_timeout 75s;
    '';
  };
};
```

**Source:** `hosts/cyberspace/nginx/services/transmission.nix:87-104`

---

### Pattern B: Proxy with WebSocket Support

**Use for:** Services needing real-time WebSocket connections

```nix
services.nginx.virtualHosts."cyberspace" = {
  locations."^~ /radarr" = {
    proxyPass = "http://127.0.0.1:${toString ports.media.radarr}";
    extraConfig = ''
      # WebSocket support
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";

      # Allow large uploads for manual imports
      client_max_body_size 0;
    '';
  };

  # Separate API location (no auth)
  locations."^~ /radarr/api" = {
    proxyPass = "http://127.0.0.1:${toString ports.media.radarr}";
    extraConfig = ''
      auth_basic off;
    '';
  };
};
```

**Source:** `hosts/cyberspace/nginx/services/radarr.nix:211-232`

**Note:** The `^~` prefix means "match prefix and stop searching for regex matches"

---

## Prometheus Exporter Patterns

### Pattern A: Built-in Exportarr

**Use for:** *arr services (Sonarr, Radarr, Lidarr, Prowlarr)

```nix
{ config, ... }:

let
  radarrExporterPort = 9708;
in
{
  # Enable built-in exporter
  services.prometheus.exporters.exportarr-radarr = {
    enable = true;
    port = radarrExporterPort;
    url = "http://127.0.0.1:7878";
    apiKeyFile = config.sops.secrets.radarr-api-key.path;
  };

  # Service dependencies
  systemd.services."prometheus-exportarr-radarr-exporter" = {
    wants = [ "radarr-setup.service" ];
    after = [ "radarr-setup.service" ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.radarr-exporter = {
    job_name = "radarr";
    description = "Radarr movie manager metrics (library, queue, quality)";
    scrape_interval = "30s";
    targets = [ "localhost:${toString radarrExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "exportarr-radarr";
      service = "radarr";
    };
    enabled = true;
    tags = [ "media" "automation" "movies" ];
  };
}
```

**Source:** `hosts/cyberspace/metrics/exporters/radarr-exporter.nix`

---

### Pattern B: Custom Exporter Service

**Use for:** Services without built-in NixOS exporters

```nix
{ config, pkgs, ... }:

let
  transmissionExporterPort = 9711;
in
{
  # Define custom systemd service
  systemd.services.prometheus-transmission-exporter = {
    description = "Prometheus Transmission Exporter";
    wantedBy = [ "multi-user.target" ];
    wants = [ "transmission.service" ];
    after = [ "transmission.service" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      ExecStart = "${pkgs.transmission-exporter}/bin/transmission-exporter --webaddr=127.0.0.1:${toString transmissionExporterPort} --transmissionaddr=http://127.0.0.1:9091";
      Restart = "on-failure";

      # Hardening
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [];
    };
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.transmission-exporter = {
    job_name = "transmission";
    description = "Transmission BitTorrent client metrics (torrents, speeds, ratios)";
    scrape_interval = "15s";
    targets = [ "localhost:${toString transmissionExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "transmission";
      service = "transmission";
    };
    enabled = true;
    tags = [ "download" "torrent" "media" ];
  };
}
```

**Source:** `hosts/cyberspace/metrics/exporters/transmission-exporter.nix`

---

## Grafana Dashboard Provisioning

### Pattern: Dashboard from Grafana.com

**Use for:** Any service with an official Grafana dashboard

```nix
{ pkgs, ... }:

let
  # Fetch dashboard from Grafana.com
  radarrDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/12896/revisions/1/download";
    hash = "sha256-wkrKTf4Bw/6hWZrnUupHPSGQ4FMh+xY5H08/6EXGhUk=";
  };

  sonarrDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/12530/revisions/1/download";
    hash = "sha256-abc123...";
  };
in
{
  # Provision dashboards via tmpfiles
  systemd.tmpfiles.rules = [
    "L+ /var/lib/grafana/dashboards/radarr-dashboard.json - - - - ${radarrDashboard}"
    "L+ /var/lib/grafana/dashboards/sonarr-dashboard.json - - - - ${sonarrDashboard}"
  ];
}
```

**To get the hash:**
```bash
nix-prefetch-url https://grafana.com/api/dashboards/<ID>/revisions/<REV>/download
```

**Source:** `hosts/cyberspace/metrics/grafana.nix`

**Popular dashboards:**
- Sonarr: 12530
- Radarr: 12896
- Lidarr: 12569
- Prowlarr: 15387
- Transmission: 10428
- Node Exporter: 1860
- Nginx: 12708

---

## Sops Secrets Integration

### Pattern: API Key Secret

**In `hosts/cyberspace/sops.nix`:**

```nix
{ config, inputs, ... }:
{
  sops.secrets.radarr-api-key = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "radarr";
    group = "media";
    mode = "0440";
  };

  sops.secrets.sonarr-api-key = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "sonarr";
    group = "media";
    mode = "0440";
  };
}
```

**Accessing in service configuration:**
```nix
# In systemd service preStart script
API_KEY=$(cat ${config.sops.secrets.radarr-api-key.path})

# In exporter configuration
apiKeyFile = config.sops.secrets.radarr-api-key.path;
```

**Source:** `hosts/cyberspace/sops.nix`

**Important:**
- API keys should be 32-character hex strings: `openssl rand -hex 16`
- Owner/group must match service user
- Mode 0440 = read-only for owner and group

---

## Port Allocations

### Centralized Port Management

**All ports are now managed in `hosts/cyberspace/ports.nix`**

This provides:
- Type-safe port allocation
- Clear categorization
- Documentation for each port
- Easy reference across all services

### Port Categories

Defined in `hosts/cyberspace/ports.nix`:

```nix
config.services.cyberspace.ports = {
  dns = { ... };          # 50-99: DNS and network services
  frontend = { ... };     # 3000-3999: Frontend/UI services
  media = { ... };        # 7000-7999: Media management (*arr stack)
  apps = { ... };         # 8000-8999: Application services
  monitoring = { ... };   # 9000-9099: Core monitoring services
  exporters = { ... };    # 9100-9199: System/infrastructure exporters
  appExporters = { ... }; # 9700-9799: Application exporters
  ai = { ... };           # 11000-11999: AI/ML services
  p2p = { ... };          # 51000-51999: P2P and peer ports
};
```

### Current Allocations

**Media Services (7000-7999):**
- 7878: Radarr
- 7989: Sonarr
- 7696: Prowlarr

**Application Services (8000-8999):**
- 8053: Pi-hole web
- 8091: Transmission

**Frontend Services (3000-3999):**
- 3000: Grafana
- 3080: Open WebUI

**System Exporters (9100-9199):**
- 9100: Node exporter
- 9113: Nginx exporter

**Application Exporters (9700-9799):**
- 9707: Sonarr exporter
- 9708: Radarr exporter
- 9710: Prowlarr exporter
- 9711: Transmission exporter

**AI Services (11000-11999):**
- 11434: Ollama

### Adding New Ports

**Always add ports to `ports.nix` first:**

```nix
# In hosts/cyberspace/ports.nix

# For a new media service
media = {
  # ... existing
  bazarr = lib.mkOption {
    type = lib.types.int;
    default = 6767;
    description = "Bazarr subtitle management service port";
  };
};

# For its exporter
appExporters = {
  # ... existing
  bazarr = lib.mkOption {
    type = lib.types.int;
    default = 9712;
    description = "Bazarr exporter port";
  };
};
```

**Then reference in service files:**

```nix
let
  ports = config.services.cyberspace.ports;
in
{
  services.bazarr.port = ports.media.bazarr;

  services.nginx.virtualHosts."cyberspace" = {
    locations."/bazarr" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.bazarr}";
    };
  };

  services.cyberspace.registeredServices.bazarr = {
    port = ports.media.bazarr;
  };
}
```

### Port Range Guidelines

- **50-99**: DNS and network services
- **3000-3999**: Frontend/UI services (Grafana, web UIs)
- **7000-7999**: Media management (*arr services)
- **8000-8999**: General applications
- **9000-9099**: Core monitoring (Prometheus)
- **9100-9199**: System/infrastructure exporters
- **9700-9799**: Application exporters
- **11000-11999**: AI/ML services
- **51000-51999**: P2P and peer ports

---

## Service Registry Schema

All services must register with this exact schema:

```nix
services.cyberspace.registeredServices.<service-name> = {
  name = "Display Name";              # Required: Human-readable
  description = "What this does";     # Required: Short description
  path = "/<service-name>";           # Required: URL path
  icon = "🎯";                        # Required: Emoji icon
  enabled = true;                     # Optional: Default true
  port = 8080;                        # Optional: Backend port
  tags = ["category" "type"];         # Optional: Categories
};
```

**Common tags:**
- `media` - Media-related services
- `automation` - Automated management
- `download` - Download clients
- `monitoring` - Metrics and monitoring
- `system` - System utilities
- `productivity` - Productivity tools

**Common icons:**
- 📥 Downloads
- 🎬 Movies (Radarr)
- 📺 TV Shows (Sonarr)
- 🎵 Music (Lidarr)
- 🔍 Search/Indexing (Prowlarr)
- 📊 Monitoring/Dashboards
- ⚙️ System tools

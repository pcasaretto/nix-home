# Real-World Service Examples

Complete examples of services running on cyberspace using Caddy with subdomain routing and Let's Encrypt TLS via Cloudflare.

## Current Services

These services are already deployed and can be used as reference:

| Service | Subdomain | File |
|---------|-----------|------|
| Dashboard | `dashboard.cyberspace.pcasaretto.com` | `caddy/services/dashboard.nix` |
| Grafana | `grafana.cyberspace.pcasaretto.com` | `caddy/services/grafana.nix` |
| Prometheus | `prometheus.cyberspace.pcasaretto.com` | `caddy/services/prometheus.nix` |
| Jellyfin | `jellyfin.cyberspace.pcasaretto.com` | `caddy/services/jellyfin.nix` |
| Sonarr | `sonarr.cyberspace.pcasaretto.com` | `caddy/services/sonarr.nix` |
| Radarr | `radarr.cyberspace.pcasaretto.com` | `caddy/services/radarr.nix` |
| Prowlarr | `prowlarr.cyberspace.pcasaretto.com` | `caddy/services/prowlarr.nix` |
| Transmission | `transmission.cyberspace.pcasaretto.com` | `caddy/services/transmission.nix` |
| Pi-hole | `pihole.cyberspace.pcasaretto.com` | `caddy/services/pihole.nix` |
| Ollama | `ollama.cyberspace.pcasaretto.com` | `caddy/services/ollama.nix` |
| Open WebUI | `openwebui.cyberspace.pcasaretto.com` | `caddy/services/open-webui.nix` |
| ntfy | `ntfy.cyberspace.pcasaretto.com` | `caddy/services/ntfy.nix` |

---

## Example: Jellyfin Media Server

A complete media server with video streaming support.

**File**: `hosts/cyberspace/caddy/services/jellyfin.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable Jellyfin media server
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
      User = "root";
    };

    script = ''
      # Wait for Jellyfin, check for existing users, create admin if needed
      # ... (see actual file for full script)
    '';
  };

  # Mount external drive for media
  systemd.services.jellyfin = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
  };

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
}
```

**Key Points:**
- `flush_interval -1` disables buffering for smooth video streaming
- `read_timeout 0` allows unlimited streaming duration
- Mount dependencies ensure media drive is available

---

## Example: Sonarr TV Management

TV show management with automatic download integration.

**File**: `hosts/cyberspace/caddy/services/sonarr.nix`

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable Sonarr - NO urlbase needed with subdomain routing!
  services.sonarr = {
    enable = true;
    openFirewall = false;
    user = "sonarr";
    group = "media";
    dataDir = "/var/lib/sonarr";
  };

  # Set API key from sops and disable authentication (Tailscale provides auth)
  systemd.services.sonarr.preStart = ''
    CONFIG_FILE="/var/lib/sonarr/config.xml"
    API_KEY=$(cat ${config.sops.secrets.sonarr-api-key.path})
    # ... configure API key and disable auth
  '';

  # Configure Transmission as download client via API
  systemd.services.sonarr-setup = {
    description = "Configure Sonarr download client";
    after = [ "sonarr.service" ];
    # ... auto-configure Transmission integration
  };

  # Register with Prowlarr for indexer syncing
  systemd.services.sonarr-prowlarr-sync = {
    # ... auto-sync indexers from Prowlarr
  };

  services.cyberspace.registeredServices.sonarr = {
    name = "Sonarr";
    description = "TV show collection manager with automatic downloads";
    url = "https://sonarr.${domain}";
    icon = "📺";
    enabled = true;
    port = ports.media.sonarr;
    tags = [ "media" "automation" "tv" ];
  };

  services.caddy.virtualHosts."sonarr.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.sonarr}
    '';
  };
}
```

**Key Points:**
- No `urlbase` configuration needed - subdomains work out of the box
- API key managed via sops-nix
- Auto-configuration of download clients via API
- Integration with Prowlarr for indexer management

---

## Example: ntfy Notification Service

Push notifications with long-polling support.

**File**: `hosts/cyberspace/caddy/services/ntfy.nix`

```nix
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
      base-url = "https://ntfy.${domain}";
      listen-http = "127.0.0.1:${toString ports.apps.ntfy}";
      behind-proxy = true;

      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "12h";

      metrics-listen-http = "127.0.0.1:${toString ports.appExporters.ntfy}";

      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";
    };
  };

  # Admin user provisioning
  systemd.services.ntfy-admin-init = {
    description = "Initialize ntfy admin user from sops secrets";
    after = [ "ntfy-sh.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };

    script = ''
      # Wait for ntfy, create admin user if needed
      # ... (see actual file for full script)
    '';
  };

  services.cyberspace.registeredServices.ntfy = {
    name = "ntfy";
    description = "Push notification service - send notifications to browser and phone";
    url = "https://ntfy.${domain}";
    icon = "🔔";
    enabled = true;
    port = ports.apps.ntfy;
    tags = [ "notification" "messaging" "monitoring" ];
  };

  # Configure Caddy with long-polling support
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
```

**Key Points:**
- 24-hour read timeout for long-polling connections
- `flush_interval -1` for real-time SSE delivery
- Admin user created from sops secrets
- Prometheus metrics endpoint on separate port

---

## Example: Grafana Monitoring

Monitoring dashboard with Prometheus integration.

**File**: `hosts/cyberspace/caddy/services/grafana.nix` (with `metrics/grafana.nix`)

```nix
{ config, lib, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
  domain = config.services.cyberspace.domain;
in
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        protocol = "http";
        http_addr = "127.0.0.1";
        http_port = ports.frontend.grafana;
        domain = "grafana.${domain}";
        root_url = "https://grafana.${domain}/";
      };

      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
      };

      # Anonymous viewing for Tailscale users
      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";
      };
    };

    # Declarative Prometheus datasource
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
    };
  };
}
```

**Separate Caddy config** in `caddy/services/grafana.nix`:

```nix
{ config, ... }:

let
  domain = config.services.cyberspace.domain;
  grafanaConfig = config.services.grafana.settings.server;
  grafanaPort = grafanaConfig.http_port;
in
{
  services.cyberspace.registeredServices.grafana = {
    name = "Grafana";
    description = "Metrics visualization and monitoring dashboard";
    url = "https://grafana.${domain}";
    icon = "📊";
    enabled = true;
    port = grafanaPort;
    tags = [ "monitoring" "metrics" "visualization" ];
  };

  services.caddy.virtualHosts."grafana.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://${grafanaConfig.http_addr}:${toString grafanaPort}
    '';
  };
}
```

**Key Points:**
- No more `serve_from_sub_path = true` needed
- `root_url` uses the full subdomain URL
- Anonymous read-only access for Tailscale users
- Password managed via sops-nix

---

## Example: Pi-hole DNS

Ad-blocking DNS running in a container.

**File**: `hosts/cyberspace/caddy/services/pihole.nix`

```nix
{ config, pkgs, lib, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Run Pi-hole in Podman container
  virtualisation.oci-containers = {
    backend = "podman";

    containers.pihole = {
      image = "pihole/pihole:latest";

      ports = [
        "${toString ports.dns.pihole}:53/tcp"
        "${toString ports.dns.pihole}:53/udp"
        "${toString ports.apps.piholeWeb}:80/tcp"
      ];

      environment = {
        TZ = "America/Sao_Paulo";
        PIHOLE_DNS_ = "1.1.1.1;1.0.0.1;8.8.8.8;8.8.4.4";
        FTLCONF_webserver_api_password = "";
      };

      volumes = [
        "/var/lib/pihole/pihole:/etc/pihole"
        "/var/lib/pihole/dnsmasq.d:/etc/dnsmasq.d"
      ];

      autoStart = true;
    };
  };

  services.cyberspace.registeredServices.pihole = {
    name = "Pi-hole";
    description = "Network-wide ad blocking via DNS";
    url = "https://pihole.${domain}";
    icon = "🛡️";
    enabled = true;
    port = ports.apps.piholeWeb;
    tags = [ "dns" "security" "privacy" ];
  };

  # Much simpler with subdomain - no sub_filter hacks!
  services.caddy.virtualHosts."pihole.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      # Redirect root to admin interface
      redir / /admin/ permanent

      reverse_proxy http://127.0.0.1:${toString ports.apps.piholeWeb} {
        transport http {
          read_timeout 300s
        }
      }
    '';
  };
}
```

**Key Points:**
- No more `sub_filter` hacks for URL rewriting
- Simple redirect from `/` to `/admin/`
- Container managed via Podman
- DNS port exposed for network-wide ad blocking

---

## Architecture Patterns

### Port Management

All ports are centralized in `hosts/cyberspace/ports.nix`:

```nix
{
  services.cyberspace.ports = {
    apps = {
      transmission = 9091;
      ntfy = 2586;
      piholeWeb = 8053;
      openWebUI = 3100;
    };

    media = {
      jellyfin = 8096;
      sonarr = 8989;
      radarr = 7878;
      prowlarr = 9696;
    };

    ai = {
      ollama = 11434;
    };

    monitoring = {
      prometheus = 9090;
    };

    frontend = {
      grafana = 3000;
    };

    exporters = {
      node = 9100;
      nginx = 9113;  # Now used for Caddy metrics
    };
  };
}
```

### TLS Configuration

All services inherit TLS config from `caddy/default.nix`:

```nix
tlsConfig = ''
  tls {
    dns cloudflare {env.CF_API_TOKEN}
    resolvers 1.1.1.1 8.8.8.8
  }
'';
```

This provides:
- Let's Encrypt certificates via DNS-01 challenge
- Cloudflare API for DNS verification
- Public resolvers (not Tailscale MagicDNS)

### Secrets Management

All secrets use sops-nix. Example from `sops.nix`:

```nix
sops.secrets.grafana-admin-password = {
  sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
  owner = "grafana";
  group = "grafana";
  mode = "0400";
};
```

Services reference secrets via path:
```nix
admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
```

---

## Benefits of Subdomain Routing

### Before (nginx with paths)

```nix
# Required urlbase configuration
services.sonarr.settings.server.urlbase = "/sonarr";

# nginx needed path rewriting
locations."/sonarr" = {
  proxyPass = "http://127.0.0.1:8989/sonarr";
  # Complex sub_filter for Pi-hole
  # URL base configs everywhere
};
```

### After (Caddy with subdomains)

```nix
# No urlbase needed!
services.sonarr.enable = true;

# Simple Caddy config
services.caddy.virtualHosts."sonarr.${domain}" = {
  extraConfig = ''
    ${config.services.cyberspace.tlsConfig}
    reverse_proxy http://127.0.0.1:8989
  '';
};
```

**Advantages:**
- Works with all applications out of the box
- No path rewriting complexity
- Proper cookie handling
- Cleaner URLs for bookmarks
- Automatic TLS for all subdomains

---

## Troubleshooting Reference

### Certificate Issues

```bash
# Check Caddy logs for ACME errors
journalctl -u caddy -n 100 | grep -i acme

# Verify DNS resolution
dig myservice.cyberspace.pcasaretto.com

# Force certificate renewal
sudo systemctl restart caddy
```

### Service Not Accessible

```bash
# Check backend is running
systemctl status <service>
curl http://127.0.0.1:<port>

# Check Caddy virtualHost
cat /etc/caddy/caddy_config | grep -A5 "myservice"

# Check TLS config included
grep "tlsConfig" hosts/cyberspace/caddy/services/<service>.nix
```

### Port Conflicts

```bash
# Find all port usages
grep -r "ports\." hosts/cyberspace/

# Check listening ports
ss -tlnp | grep <port>
```

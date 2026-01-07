---
name: cyberspace-services
description: Add and manage Caddy-backed services in the cyberspace NixOS service registry. Create service files, configure Caddy reverse proxy with subdomain routing, register in dashboard, and handle static sites, reverse proxies, and custom applications. Use when adding services to cyberspace, working with the service registry, configuring Caddy locations, or managing web services.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Cyberspace Service Registry

Automates the complete workflow for adding and managing Caddy-backed services in the cyberspace NixOS host's service registry. Services appear automatically in the web dashboard and are accessible via subdomains.

## When to Use This Skill

Use this skill when you need to:
- Add new services to the cyberspace service registry
- Configure Caddy routing for services (static sites, reverse proxies, apps)
- Register services in the dashboard with metadata
- Edit existing service configurations
- Understand the service registry pattern

## Architecture Overview

**Domain**: `cyberspace.pcasaretto.com`
**TLS**: Let's Encrypt via Cloudflare DNS-01 challenge
**Routing**: Subdomain-based (e.g., `grafana.cyberspace.pcasaretto.com`)

### Why Subdomains?

Many services don't support path-based routing well (require `urlbase` hacks, `sub_filter`, etc.). Subdomain routing:
- Works with all applications out of the box
- Cleaner URLs for bookmarks
- No path rewriting complexity
- Proper cookie handling

### Network Flow

```
Browser → Cloudflare DNS → CNAME → Tailscale MagicDNS → cyberspace
                                                            ↓
                                                      Caddy (TLS)
                                                            ↓
                                                     localhost:port
```

## Service Registry Pattern

**Architecture:**
- **Registry Module**: `@hosts/cyberspace/service-registry.nix`
  - Defines `services.cyberspace.registeredServices` option
  - Schema: name, description, url, icon, enabled, port, tags

- **Caddy Config**: `@hosts/cyberspace/caddy/default.nix`
  - Custom Caddy with Cloudflare DNS plugin
  - Exports `services.cyberspace.tlsConfig` for all services
  - Handles TLS via Let's Encrypt DNS-01 challenge

- **Service Files**: `@hosts/cyberspace/caddy/services/<name>.nix`
  - Each service in its own file
  - Configures Caddy virtualHost with subdomain
  - Includes TLS config from `config.services.cyberspace.tlsConfig`
  - Registers itself in the service registry
  - All imported in `@hosts/cyberspace/caddy/services/default.nix`

- **Dashboard**: Automatically generated at `dashboard.cyberspace.pcasaretto.com`
  - Shows all registered services with icons and descriptions
  - Links to each service subdomain
  - Displays tags, ports, and status

## Workflow: Adding a New Service

### Step 1: Gather Information

Ask the user for:
- **Service name** (kebab-case, e.g., "my-app")
- **Service type** (static site, reverse proxy, or custom app)
- **Display name** (e.g., "My App")
- **Description** (what the service does)
- **Subdomain** (e.g., "myapp" → `myapp.cyberspace.pcasaretto.com`)
- **Icon** (emoji, e.g., "🚀")
- **Port** (the backend port, e.g., 8080)
- **Tags** (categories, e.g., ["media", "productivity"])

### Step 2: Allocate Port

Check `hosts/cyberspace/ports.nix` for available ports and add the new service:

```nix
# In hosts/cyberspace/ports.nix
apps = {
  # ... existing apps
  myapp = 8080;  # Add new port
};
```

### Step 3: Create Service File

Create `hosts/cyberspace/caddy/services/<service-name>.nix`:

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable the service (if using a NixOS module)
  services.myapp = {
    enable = true;
    # ... service-specific config
  };

  # Register in service registry
  services.cyberspace.registeredServices.myapp = {
    name = "My Application";
    description = "Description of what this does";
    url = "https://myapp.${domain}";
    icon = "🚀";
    enabled = true;
    port = ports.apps.myapp;
    tags = [ "category" "type" ];
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

### Step 4: Add Import

Update `@hosts/cyberspace/caddy/services/default.nix` to import the new service:

```nix
{
  imports = [
    ./dashboard.nix
    ./grafana.nix
    # ... existing services
    ./myapp.nix  # Add this line
  ];
}
```

### Step 5: Rebuild

```bash
sudo nixos-rebuild switch --flake .#cyberspace
```

### Step 6: Verify

After rebuild:
1. Check Caddy logs: `journalctl -u caddy -f`
2. Wait for TLS certificate (may take a minute)
3. Access: `https://myapp.cyberspace.pcasaretto.com`

## Service Templates

### Template 1: Simple Reverse Proxy

For proxying to a local service:

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
    description = "Application proxied to port 8080";
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

### Template 2: Streaming/WebSocket Application

For apps with streaming, WebSocket, or long-polling:

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.streaming-app = {
    name = "Streaming App";
    description = "Application with WebSocket/SSE support";
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

        # Extended timeouts
        transport http {
          read_timeout 300s
          write_timeout 300s
        }
      }
    '';
  };
}
```

### Template 3: Media Streaming (Jellyfin-style)

For video streaming applications:

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.media = {
    name = "Media Server";
    description = "Video streaming server";
    url = "https://media.${domain}";
    icon = "🎬";
    enabled = true;
    port = ports.media.myserver;
    tags = [ "media" "streaming" ];
  };

  services.caddy.virtualHosts."media.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.media.myserver} {
        # Disable buffering for video streaming
        flush_interval -1

        # No timeout for streaming
        transport http {
          read_timeout 0
          write_timeout 0
        }
      }
    '';
  };
}
```

### Template 4: Static Website

For serving static HTML/CSS/JS files:

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;

  webRoot = pkgs.runCommand "my-site" {} ''
    mkdir -p $out
    cat > $out/index.html <<EOF
    <!DOCTYPE html>
    <html>
      <head><title>My Site</title></head>
      <body><h1>Hello World</h1></body>
    </html>
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
    '';
  };
}
```

### Template 5: Long-Polling/SSE (ntfy-style)

For notification services with very long timeouts:

```nix
{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  services.cyberspace.registeredServices.notifications = {
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

## Registry Schema Reference

All services must register with this schema:

```nix
services.cyberspace.registeredServices.<service-name> = {
  name = "Display Name";                    # Required: Human-readable name
  description = "What this does";           # Required: Short description
  url = "https://myapp.${domain}";          # Required: Full URL to service
  icon = "🎯";                              # Optional: Emoji icon (default: "🔧")
  enabled = true;                           # Optional: Active status (default: true)
  port = 8080;                              # Optional: Backend port for display
  tags = ["category" "type"];               # Optional: Categories (default: [])
};
```

## TLS Configuration

Every virtualHost MUST include the shared TLS config:

```nix
services.caddy.virtualHosts."myapp.${domain}" = {
  extraConfig = ''
    ${config.services.cyberspace.tlsConfig}
    # ... rest of config
  '';
};
```

This ensures:
- TLS via Let's Encrypt DNS-01 challenge
- Cloudflare DNS provider for certificate verification
- Public DNS resolvers (1.1.1.1, 8.8.8.8) for ACME verification

## File Locations

- **Service Registry Module**: `@hosts/cyberspace/service-registry.nix`
- **Caddy Config**: `@hosts/cyberspace/caddy/default.nix`
- **Services Directory**: `@hosts/cyberspace/caddy/services/`
- **Services Index**: `@hosts/cyberspace/caddy/services/default.nix`
- **Port Allocations**: `@hosts/cyberspace/ports.nix`
- **Sops Secrets**: `@hosts/cyberspace/sops.nix`

## Port Management

Ports are centrally managed in `hosts/cyberspace/ports.nix`:

```nix
services.cyberspace.ports = {
  apps = {
    transmission = 9091;
    ntfy = 2586;
    # ... add new app ports here
  };
  media = {
    jellyfin = 8096;
    sonarr = 8989;
    # ... media-related ports
  };
  monitoring = {
    prometheus = 9090;
    # ... monitoring ports
  };
  # ... other categories
};
```

Always:
1. Check for conflicts before adding ports
2. Use descriptive categories
3. Reference via `config.services.cyberspace.ports.<category>.<service>`

## Best Practices

### Naming Conventions
- Service files: kebab-case (e.g., `my-service.nix`)
- Registry keys: kebab-case (e.g., `my-service`)
- Subdomains: lowercase, no hyphens preferred (e.g., `myservice`)

### Always Include TLS Config
Every virtualHost must include `${config.services.cyberspace.tlsConfig}` or TLS won't work.

### Use Port Variables
Always use `config.services.cyberspace.ports` instead of hardcoding:
```nix
# Good
reverse_proxy http://127.0.0.1:${toString ports.apps.myapp}

# Bad
reverse_proxy http://127.0.0.1:8080
```

### Security
- Services are only accessible via Tailscale + proper TLS
- Caddy binds to tailscale0 interface only
- No public internet exposure
- Use sops-nix for secrets

## Troubleshooting

### TLS Certificate Issues

1. Check Caddy logs: `journalctl -u caddy -n 100`
2. Look for ACME errors
3. Verify `config.services.cyberspace.tlsConfig` is included
4. Ensure Cloudflare API token is valid
5. Check DNS propagation: `dig myapp.cyberspace.pcasaretto.com`

### Service doesn't appear in dashboard

1. Check service is imported in `caddy/services/default.nix`
2. Verify registry entry has `enabled = true`
3. Check URL format: `url = "https://myapp.${domain}"`
4. Rebuild: `sudo nixos-rebuild switch --flake .#cyberspace`

### Caddy fails to start

1. Check config: `caddy validate --config /etc/caddy/caddy_config`
2. View errors: `journalctl -u caddy -n 50`
3. Common issues:
   - Missing TLS config
   - Port conflicts
   - Invalid Caddyfile syntax

### Service returns 502

1. Verify backend is running: `systemctl status <service>`
2. Test backend directly: `curl http://127.0.0.1:<port>`
3. Check backend logs: `journalctl -u <service>`

### DNS doesn't resolve

1. Check Cloudflare DNS for CNAME record
2. Verify: `dig myapp.cyberspace.pcasaretto.com`
3. Should return CNAME → `cyberspace.tyrannosaurus-regulus.ts.net`

## Commands

### Rebuild and Apply Changes
```bash
sudo nixos-rebuild switch --flake .#cyberspace
```

### Check Caddy Configuration
```bash
caddy validate --config /etc/caddy/caddy_config --adapter caddyfile
```

### View Caddy Logs
```bash
journalctl -u caddy -f
```

### Restart Caddy (for TLS issues)
```bash
sudo systemctl restart caddy
```

### Test Service Locally
```bash
curl http://127.0.0.1:<port>
```

### Check DNS Resolution
```bash
dig myapp.cyberspace.pcasaretto.com
```

### Validate Nix Syntax
```bash
nix flake check --no-build
```

## References

- Caddy documentation: https://caddyserver.com/docs/
- Caddy Cloudflare DNS: https://github.com/caddy-dns/cloudflare
- Let's Encrypt DNS-01: https://letsencrypt.org/docs/challenge-types/#dns-01-challenge
- Tailscale: https://tailscale.com/kb/

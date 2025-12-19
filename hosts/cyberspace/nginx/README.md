# Nginx Reverse Proxy Configuration

Modular nginx setup for Tailscale-only access to services on cyberspace with **automatic service discovery**.

## Architecture

- `default.nix` - Main nginx configuration with recommended settings
- `service-registry.nix` - Service registration module for automatic dashboard updates
- `tailscale-binding.nix` - Tailscale network binding and firewall rules
- `services/` - Individual service reverse proxy configs
  - `system-info.nix` - Dynamic system dashboard (auto-generated from registry)
  - `jellyfin.nix.example` - Example service with auto-registration

## Network Access

Nginx is configured for **Tailscale-only access**:
- Firewall restricts port 80 to `tailscale0` interface only
- Uses HTTP (no SSL/TLS) since Tailscale encrypts traffic with WireGuard
- Access via: `http://<tailscale-ip>/` or `http://cyberspace/` (if MagicDNS enabled)

Get your Tailscale IP: `tailscale ip -4`

## 🎯 Auto-Registration System

Services automatically appear on the dashboard when registered! No manual HTML editing required.

### How It Works

1. Each service declares its metadata using `services.cyberspace.registeredServices`
2. The system-info dashboard reads the registry at build time
3. HTML is automatically generated with all registered services
4. Service count, icons, descriptions, and links are all automatic

## Adding a New Service

### Step 1: Create Service Configuration

Create `services/<service-name>.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  # ✨ Register the service - it will appear on the dashboard automatically!
  services.cyberspace.registeredServices.<service-name> = {
    name = "Display Name";
    description = "What this service does";
    path = "/";  # Or "/subpath" for path-based routing
    icon = "🎬";  # Emoji icon
    enabled = true;
    port = 8096;  # Optional: backend port for display
    tags = ["media" "streaming"];  # Optional: categories
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."<service-name>" = {
    listen = [
      { addr = "0.0.0.0"; port = 80; }
    ];

    locations."/" = {
      proxyPass = "http://127.0.0.1:<backend-port>";
      proxyWebsockets = true;  # If service needs WebSockets

      extraConfig = ''
        # Common reverse proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
```

### Step 2: Import the Service

Add to `services/default.nix`:

```nix
imports = [
  ./system-info.nix
  ./<service-name>.nix  # Add your new service here
];
```

### Step 3: Deploy

```bash
# Check syntax
nix flake check

# Test build
nixos-rebuild dry-build --flake .#cyberspace

# Deploy
sudo nixos-rebuild switch --flake .#cyberspace
```

**That's it!** The service will automatically appear on the dashboard at `http://<tailscale-ip>/` ✨

## Service Registration Options

All available options for `services.cyberspace.registeredServices.<name>`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | string | *required* | Display name shown on dashboard |
| `description` | string | *required* | Short description of the service |
| `path` | string | `"/"` | URL path where service is accessible |
| `icon` | string | `"🔧"` | Emoji icon for visual identification |
| `enabled` | bool | `true` | Whether service is active (filtered if false) |
| `port` | int? | `null` | Backend port (shown on dashboard for reference) |
| `tags` | list | `[]` | Categories/tags (e.g., `["media" "streaming"]`) |

## Complete Example: Jellyfin

See `services/jellyfin.nix.example` for a complete working example:

```nix
{ config, lib, pkgs, ... }:

{
  # Auto-register on dashboard
  services.cyberspace.registeredServices.jellyfin = {
    name = "Jellyfin";
    description = "Media server for streaming movies, TV shows, and music";
    path = "/";
    icon = "🎬";
    enabled = true;
    port = 8096;
    tags = ["media" "streaming" "entertainment"];
  };

  # Nginx reverse proxy config
  services.nginx.virtualHosts."jellyfin" = {
    listen = [{ addr = "0.0.0.0"; port = 80; }];

    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;

      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_buffering off;  # For streaming
      '';
    };
  };

  # Enable the actual Jellyfin service
  services.jellyfin.enable = true;
}
```

To use this example:
```bash
# Copy the example
cp services/jellyfin.nix.example services/jellyfin.nix

# Add to services/default.nix
# imports = [ ./jellyfin.nix ];

# Deploy
sudo nixos-rebuild switch --flake .#cyberspace
```

## Common Configuration Patterns

### WebSocket Support

```nix
locations."/" = {
  proxyPass = "http://127.0.0.1:3000";
  proxyWebsockets = true;
};
```

### Large File Uploads

```nix
locations."/" = {
  proxyPass = "http://127.0.0.1:3000";
  extraConfig = ''
    client_max_body_size 1G;
  '';
};
```

### Path-Based Routing (Subpaths)

```nix
# Register with subpath
services.cyberspace.registeredServices.myservice = {
  name = "My Service";
  path = "/myservice";  # Accessible at http://ip/myservice
  # ...
};

# Nginx config for subpath
services.nginx.virtualHosts."cyberspace" = {
  locations."/myservice/" = {
    proxyPass = "http://127.0.0.1:3000/";
    extraConfig = ''
      proxy_set_header X-Forwarded-Prefix /myservice;
    '';
  };
};
```

### Disable Buffering (Streaming)

```nix
extraConfig = ''
  proxy_buffering off;
  proxy_request_buffering off;
'';
```

## Icon Suggestions

Choose an emoji icon for your service:

- 🎬 Media (Jellyfin, Plex)
- 📁 Files (Nextcloud, Syncthing)
- 🏠 Home Automation (Home Assistant)
- 📊 Monitoring (Grafana, Prometheus)
- 🔐 Password Manager (Vaultwarden)
- 📖 Documentation (Wiki.js, BookStack)
- 💬 Chat (Matrix, Mattermost)
- 🎮 Gaming (Game servers)
- 🖼️ Photos (PhotoPrism, Immich)
- 🎵 Music (Navidrome, Airsonic)

## Dashboard Features

The auto-generated dashboard shows:
- ✅ Service count (e.g., "3 active")
- 🎨 Icons for visual identification
- 📝 Service descriptions
- 🔢 Backend ports (if specified)
- 🏷️ Tags/categories
- ✨ Active/Inactive status

All automatically updated on rebuild - no manual HTML editing!

## Verification

After deploying:

```bash
# Check nginx status
systemctl status nginx

# View nginx logs
journalctl -u nginx -f

# Check port binding
ss -tlnp | grep nginx

# Test from another Tailscale device
curl http://$(tailscale ip -4)/

# Or open in browser to see the dashboard
```

## Troubleshooting

### Nginx won't start
```bash
# Check nginx logs
journalctl -u nginx -xe

# Verify syntax
nginx -t
```

### Service not appearing on dashboard
- Check that `enabled = true` in registration
- Verify service is imported in `services/default.nix`
- Rebuild and check for errors: `nixos-rebuild switch`

### Can't access from Tailscale
```bash
# Verify Tailscale interface exists
ip addr show tailscale0

# Check firewall rules
sudo iptables -L -n -v | grep 80
```

### Service not responding
```bash
# Verify backend service is running
systemctl status <service-name>

# Check if service is listening on localhost
ss -tlnp | grep <port>
```

## Advanced: Custom Service Modules

For complex services, you can create a full NixOS module:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myCustomService;
in
{
  options.services.myCustomService = {
    enable = lib.mkEnableOption "My Custom Service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 3000;
    };
  };

  config = lib.mkIf cfg.enable {
    # Auto-register when enabled
    services.cyberspace.registeredServices.myservice = {
      name = "My Service";
      description = "A custom service";
      icon = "⚡";
      port = cfg.port;
    };

    # Nginx config
    services.nginx.virtualHosts."myservice" = {
      # ... proxy config
    };

    # Backend service
    systemd.services.myCustomService = {
      # ... service definition
    };
  };
}
```

## Security Notes

- Nginx only accepts connections from Tailscale interface
- Backend services should listen on `127.0.0.1` (localhost), not `0.0.0.0`
- Traffic is encrypted by Tailscale's WireGuard tunnel
- Security headers are configured even for HTTP connections
- Service metadata is evaluated at build time, not runtime

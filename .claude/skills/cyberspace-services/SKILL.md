---
name: cyberspace-services
description: Add and manage nginx-backed services in the cyberspace NixOS service registry. Create service files, configure nginx routing, register in dashboard, and handle static sites, reverse proxies, and custom applications. Use when adding services to cyberspace, working with the service registry, configuring nginx locations, or managing web services on Tailscale.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Cyberspace Service Registry

Automates the complete workflow for adding and managing nginx-backed services in the cyberspace NixOS host's service registry. Services appear automatically in the web dashboard accessible via Tailscale.

## When to Use This Skill

Use this skill when you need to:
- Add new services to the cyberspace service registry
- Configure nginx routing for services (static sites, reverse proxies, apps)
- Register services in the dashboard with metadata
- Edit existing service configurations
- Understand the service registry pattern

## Service Registry Pattern

The cyberspace host uses a custom service registry system that automatically maintains a web dashboard of all services.

**Architecture:**
- **Registry Module**: `@hosts/cyberspace/nginx/service-registry.nix`
  - Defines `services.cyberspace.registeredServices` option
  - Schema: name, description, path, icon, enabled, port, tags

- **Service Files**: `@hosts/cyberspace/nginx/services/<name>.nix`
  - Each service in its own file
  - Configures nginx virtualHost or location
  - Registers itself in the service registry
  - All imported in `@hosts/cyberspace/nginx/services/default.nix`

- **Dashboard**: Automatically generated at nginx root
  - Shows all registered services with icons and descriptions
  - Links to each service path
  - Displays tags, ports, and status

**Network:**
- nginx binds only to Tailscale interface (tailscale0)
- HTTP only (Tailscale provides encryption)
- Accessible from any device on your Tailscale network

## Workflow: Adding a New Service

### Step 1: Gather Information

Ask the user for:
- **Service name** (kebab-case, e.g., "my-app")
- **Service type** (static site, reverse proxy, or custom app)
- **Display name** (e.g., "My App")
- **Description** (what the service does)
- **URL path** (e.g., "/my-app" or "/" for root)
- **Icon** (emoji, e.g., "🚀")
- **Port** (if reverse proxy, e.g., 8080)
- **Tags** (categories, e.g., ["media", "productivity"])

### Step 2: Create Service File

Create `hosts/cyberspace/nginx/services/<service-name>.nix` based on the service type (see templates below).

### Step 3: Add Import

Update `@hosts/cyberspace/nginx/services/default.nix` to import the new service:

```nix
{
  imports = [
    ./system-info.nix
    ./my-service.nix  # Add this line
  ];
}
```

### Step 4: Rebuild

Provide the rebuild command:
```bash
sudo nixos-rebuild switch --flake .#cyberspace
```

### Step 5: Verify

After rebuild, the service should appear in the dashboard at the Tailscale IP address.

## Service Templates

### Template 1: Static Website

For serving static HTML/CSS/JS files:

```nix
{ config, pkgs, ... }:

let
  # Create static site content
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
  # Register in service registry
  services.cyberspace.registeredServices.my-site = {
    name = "My Site";
    description = "Static website example";
    path = "/my-site";
    icon = "🌐";
    enabled = true;
    tags = ["web" "static"];
  };

  # Configure nginx
  services.nginx.virtualHosts."cyberspace" = {
    locations."/my-site" = {
      alias = "${webRoot}";
      index = "index.html";
      extraConfig = ''
        try_files $uri $uri/ /my-site/index.html;
      '';
    };
  };
}
```

### Template 2: Reverse Proxy

For proxying to a local service on a specific port:

```nix
{ config, ... }:

{
  # Register in service registry
  services.cyberspace.registeredServices.my-app = {
    name = "My Application";
    description = "Application proxied to port 8080";
    path = "/my-app";
    icon = "🚀";
    enabled = true;
    port = 8080;
    tags = ["app" "proxy"];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/my-app/" = {
      proxyPass = "http://127.0.0.1:8080/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
```

### Template 3: Custom Application with systemd

For running a custom application with systemd and proxying:

```nix
{ config, pkgs, ... }:

{
  # Create systemd service
  systemd.services.my-custom-app = {
    description = "My Custom Application";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8090";
      WorkingDirectory = "/var/lib/my-app";
      Restart = "always";
      User = "my-app";
    };
  };

  # Create user for the service
  users.users.my-app = {
    isSystemUser = true;
    group = "my-app";
    home = "/var/lib/my-app";
    createHome = true;
  };

  users.groups.my-app = {};

  # Register in service registry
  services.cyberspace.registeredServices.my-custom-app = {
    name = "My Custom App";
    description = "Custom application with systemd service";
    path = "/my-custom-app";
    icon = "⚡";
    enabled = true;
    port = 8090;
    tags = ["custom" "app"];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/my-custom-app/" = {
      proxyPass = "http://127.0.0.1:8090/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
      '';
    };
  };
}
```

## Registry Schema Reference

All services must register with this schema:

```nix
services.cyberspace.registeredServices.<service-name> = {
  name = "Display Name";              # Required: Human-readable name
  description = "What this does";     # Required: Short description
  path = "/service-path";             # Required: URL path (default: "/")
  icon = "🎯";                        # Optional: Emoji icon (default: "🔧")
  enabled = true;                     # Optional: Active status (default: true)
  port = 8080;                        # Optional: Backend port for display (default: null)
  tags = ["category" "type"];         # Optional: Categories (default: [])
};
```

## File Locations

- **Service Registry Module**: `@hosts/cyberspace/nginx/service-registry.nix`
- **Services Directory**: `@hosts/cyberspace/nginx/services/`
- **Services Index**: `@hosts/cyberspace/nginx/services/default.nix`
- **Reference Example**: `@hosts/cyberspace/nginx/services/system-info.nix`
- **Main nginx Config**: `@hosts/cyberspace/nginx/default.nix`

## Best Practices

### Naming Conventions
- Service files: kebab-case (e.g., `my-service.nix`)
- Registry keys: kebab-case (e.g., `my-service`)
- Paths: lowercase with hyphens (e.g., `/my-service`)

### Path Management
- Choose unique paths (check existing services first)
- Use sub-paths for related services (e.g., `/media/jellyfin`, `/media/navidrome`)
- Root path (`/`) is reserved for the dashboard

### Port Management
- Document the port even if it's internal
- Avoid port conflicts (check existing services)
- Common ports: 8080-8099 for apps, 3000-3999 for Node.js, 5000-5999 for Python

### Security
- Services are only accessible via Tailscale network
- nginx binds to tailscale0 interface only
- No public internet exposure
- Use systemd hardening when running custom services

### Icons and Tags
- Choose descriptive emoji icons
- Common tags: "media", "productivity", "monitoring", "system", "app", "web"
- Tags help organize services in the dashboard

## Common Patterns

### Serving Static HTML from Nix

Use `pkgs.writeTextFile` or `pkgs.runCommand` to generate static content:

```nix
let
  htmlPage = pkgs.writeTextFile {
    name = "page.html";
    text = ''
      <!DOCTYPE html>
      <html>
        <body><h1>Generated at build time</h1></body>
      </html>
    '';
  };
in
{
  services.nginx.virtualHosts."cyberspace" = {
    locations."/page" = {
      alias = htmlPage;
    };
  };
}
```

### Proxying WebSocket Applications

Add WebSocket support to reverse proxy:

```nix
services.nginx.virtualHosts."cyberspace" = {
  locations."/websocket-app/" = {
    proxyPass = "http://127.0.0.1:8080/";
    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    '';
  };
}
```

### Multiple Paths for One Service

A service can have multiple nginx locations:

```nix
services.nginx.virtualHosts."cyberspace" = {
  locations."/app" = {
    proxyPass = "http://127.0.0.1:8080/";
  };

  locations."/app-api" = {
    proxyPass = "http://127.0.0.1:8080/api/";
  };
}
```

## Troubleshooting

### Service doesn't appear in dashboard

1. Check service is imported in `services/default.nix`
2. Verify registry entry has `enabled = true`
3. Run `sudo nixos-rebuild switch --flake .#cyberspace`
4. Clear browser cache and refresh

### nginx fails to start

1. Check nginx config syntax: `sudo nginx -t`
2. View errors: `sudo journalctl -u nginx.service -n 50`
3. Common issues:
   - Duplicate location paths
   - Invalid proxy addresses
   - Port already in use

### Service returns 404

1. Verify path matches registry entry
2. Check nginx location configuration
3. Test backend is running: `curl http://127.0.0.1:<port>`
4. Review nginx access logs: `sudo journalctl -u nginx.service | grep "GET /your-path"`

### Port conflicts

1. List all registered ports: `grep -r "port =" hosts/cyberspace/nginx/services/`
2. Check listening ports: `sudo ss -tulpn`
3. Choose a different port for your service

## Examples

For detailed examples, see [@.claude/skills/cyberspace-services/examples.md](./examples.md)

For complete service templates, see [@.claude/skills/cyberspace-services/service-templates.md](./service-templates.md)

## Commands

### Rebuild and Apply Changes
```bash
sudo nixos-rebuild switch --flake .#cyberspace
```

### Check nginx Configuration
```bash
sudo nginx -t
```

### View nginx Logs
```bash
sudo journalctl -u nginx.service -f
```

### Test Service Locally
```bash
curl http://127.0.0.1:<port>
```

### Get Tailscale IP
```bash
tailscale ip -4
```

### Validate Nix Syntax
```bash
nix flake check --no-build
```

## References

- NixOS nginx options: https://search.nixos.org/options?query=services.nginx
- nginx reverse proxy guide: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- Tailscale best practices: https://tailscale.com/kb/1019/

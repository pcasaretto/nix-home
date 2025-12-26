---
name: add-service
description: Add services to cyberspace with nginx routing, prometheus exporters, and grafana dashboards. Automates complete setup from service config to metrics visualization.
argument-hint: <service-name>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, WebSearch
model: sonnet
---

# Add Service to Cyberspace

You are adding the service: **$1**

## Critical Anti-Hallucination Rules

**NEVER:**
- Guess nginx options → Always copy from existing patterns
- Invent port numbers → Research official docs + verify existing allocations
- Create packages without research → Check nixpkgs first
- Skip validation → Run `nixos-rebuild build` after EVERY phase
- Proceed without sub-agent research → Always verify before implementing

**ALWAYS:**
- Use Task tool with Explore subagent to find existing patterns
- Use Task tool with Plan subagent to research NixOS modules
- Use WebSearch for official documentation when needed
- Copy exact patterns from working service files
- Validate with `nixos-rebuild build --flake .#cyberspace` after each phase

## 5-Phase Workflow

### Phase 0: Research & Discovery

**Before writing any code, research the service:**

1. **Launch Explore subagent** to find similar services:
   ```
   Task(subagent_type=Explore):
   "Find similar services to $1 in hosts/cyberspace/nginx/services/
   Identify which pattern to follow (simple proxy, auth-enabled app, static site)"
   ```

2. **Launch Plan subagent** to research service configuration:
   ```
   Task(subagent_type=Plan):
   "Research $1 service for NixOS:
   - Check if services.$1 module exists in NixOS
   - Find default port from official documentation
   - Identify authentication requirements
   - Check if prometheus exporter exists (exportarr-$1 or community exporter)
   - Find grafana dashboard on grafana.com"
   ```

3. **Read ports.nix** to understand port allocation:
   - File: `hosts/cyberspace/ports.nix`
   - Check existing allocations
   - Determine appropriate category for new service

4. **Ask user for service details:**
   - Display name (e.g., "Bazarr")
   - Description (what the service does)
   - Icon (emoji, e.g., "📺")
   - URL path preference (e.g., "/bazarr")
   - Port category (media, apps, frontend, etc.)
   - Confirm port number from research
   - Any special requirements

**Validation:** Present research findings to user for confirmation before proceeding.

---

### Phase 1: Configure Service & Ports

**Goal:** Add port allocation and create service configuration

**Files:**
- `hosts/cyberspace/ports.nix` (port allocation)
- `hosts/cyberspace/nginx/services/$1.nix` (service config)

**Steps:**

1. **Add port to ports.nix:**

   Determine appropriate category based on service type:
   - `media` (7000-7999): Media management (*arr services)
   - `apps` (8000-8999): General applications
   - `frontend` (3000-3999): Web UIs/frontends
   - `ai` (11000-11999): AI/ML services

   Add service port in appropriate category:
   ```nix
   # Example: Adding bazarr to media category
   media = {
     # ... existing services
     bazarr = lib.mkOption {
       type = lib.types.int;
       default = 6767;  # from research
       description = "Bazarr subtitle management service port";
     };
   };
   ```

   If service needs an exporter, also add to `appExporters` (9700-9799):
   ```nix
   appExporters = {
     # ... existing exporters
     bazarr = lib.mkOption {
       type = lib.types.int;
       default = 9712;  # next available
       description = "Bazarr exporter port";
     };
   };
   ```

2. **Read existing pattern** to understand structure:
   - Simple proxy: Read `hosts/cyberspace/nginx/services/transmission.nix`
   - *arr service: Read `hosts/cyberspace/nginx/services/radarr.nix`
   - Choose pattern based on Phase 0 research

3. **Create service file** following the pattern:
   ```nix
   { config, pkgs, ... }:

   let
     ports = config.services.cyberspace.ports;
   in
   {
     # Enable service
     services.$1 = {
       enable = true;
       # Use port from centralized config
       # port = ports.media.$1;  # or appropriate category
       # ... other configuration from research
     };

     # Register in service registry
     services.cyberspace.registeredServices.$1 = {
       name = "Display Name";
       description = "Service description";
       path = "/$1";
       icon = "emoji";
       enabled = true;
       port = ports.media.$1;  # Reference centralized port
       tags = ["category"];
     };

     # Nginx configuration (next phase)
   }
   ```

3. **If service needs API key/password:**
   - Add secret to `hosts/cyberspace/sops.nix`:
     ```nix
     sops.secrets.$1-api-key = {
       sopsFile = "\${inputs.mysecrets}/secrets/cyberspace.yaml";
       owner = "$1";
       group = "media";  # or appropriate group
       mode = "0440";
     };
     ```

4. **Add import** to `hosts/cyberspace/nginx/services/default.nix`:
   ```nix
   imports = [
     ...
     ./$1.nix
   ];
   ```

**Validation:**
```bash
nixos-rebuild build --flake .#cyberspace
```
Check for errors. Fix before proceeding.

---

### Phase 2: Configure Nginx Reverse Proxy

**Goal:** Add nginx configuration to the same service file

**Pattern selection based on service type:**

**A) Simple Proxy** (like Transmission):
```nix
services.nginx.virtualHosts."cyberspace" = {
  locations."^~ /$1" = {
    proxyPass = "http://127.0.0.1:${toString ports.apps.$1}";
    extraConfig = ''
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    '';
  };
};
```

**B) Auth-Enabled App** (like Radarr/Sonarr):
```nix
services.nginx.virtualHosts."cyberspace" = {
  locations."^~ /$1" = {
    proxyPass = "http://127.0.0.1:${toString ports.media.$1}";
    extraConfig = ''
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      # WebSocket support (if needed)
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    '';
  };

  # Separate API location if needed
  locations."^~ /$1/api" = {
    proxyPass = "http://127.0.0.1:${toString ports.media.$1}/api";
    extraConfig = ''
      proxy_set_header Host $host;
    '';
  };
};
```

**Reference existing files:**
- `hosts/cyberspace/nginx/services/transmission.nix`
- `hosts/cyberspace/nginx/services/radarr.nix`
- `hosts/cyberspace/nginx/services/sonarr.nix`

**NEVER guess nginx options - always copy from working examples!**

**Validation:**
```bash
nixos-rebuild build --flake .#cyberspace
```
Check for nginx configuration errors.

---

### Phase 3: Prometheus Exporter (Smart Detection)

**Goal:** Configure metrics collection if exporter exists

**Detection logic:**

1. Check if built-in NixOS exporter exists:
   - Search for `services.prometheus.exporters.exportarr-$1`
   - Or similar exporters in NixOS

2. Check if community exporter exists:
   - Like `transmission-exporter` for Transmission

3. **If NO exporter found:**
   - Skip this phase
   - Notify user: "No Prometheus exporter found for $1. Metrics collection skipped."
   - Proceed to Phase 4

**If exporter EXISTS:**

**File:** `hosts/cyberspace/metrics/exporters/$1-exporter.nix`

**Port allocation:**
- Exporter port should already be added to `ports.nix` in Phase 1
- Located in `appExporters` category (9700-9799 range)

**For built-in exportarr:**
```nix
{ config, ... }:

let
  ports = config.services.cyberspace.ports;
in
{
  # Enable exporter
  services.prometheus.exporters.exportarr-$1 = {
    enable = true;
    port = ports.appExporters.$1;  # Use centralized port
    url = "http://127.0.0.1:${toString ports.media.$1}";  # Service port
    apiKeyFile = config.sops.secrets.$1-api-key.path;
  };

  # Service dependencies
  systemd.services."prometheus-exportarr-$1-exporter" = {
    wants = [ "$1.service" ];
    after = [ "$1.service" ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.$1-exporter = {
    job_name = "$1";
    description = "$1 service metrics";
    scrape_interval = "30s";
    targets = [ "localhost:${toString ports.appExporters.$1}" ];
    labels = {
      instance = "cyberspace";
      exporter = "exportarr-$1";
      service = "$1";
    };
    enabled = true;
    tags = [ "media" "automation" ];  # Adjust tags appropriately
  };
}
```

**Add import** to `hosts/cyberspace/metrics/exporters/default.nix`:
```nix
imports = [
  ...
  ./$1-exporter.nix
];
```

**Validation:**
```bash
nixos-rebuild build --flake .#cyberspace
```

---

### Phase 4: Grafana Dashboard (Smart Detection)

**Goal:** Provision dashboard if available on Grafana.com

**Detection:**

1. **Search Grafana.com:**
   ```
   WebSearch: "grafana.com $1 dashboard"
   ```
   Or visit: `https://grafana.com/grafana/dashboards/?search=$1`

2. **If NO dashboard found:**
   - Skip this phase
   - Notify user: "No official Grafana dashboard found for $1. Dashboard provisioning skipped."
   - Proceed to Phase 5

**If dashboard EXISTS:**

1. **Get dashboard hash:**
   ```bash
   nix-prefetch-url https://grafana.com/api/dashboards/<ID>/revisions/<REV>/download
   ```

2. **Add to** `hosts/cyberspace/metrics/grafana.nix`:

   Add inside the `let` block:
   ```nix
   $1Dashboard = pkgs.fetchurl {
     url = "https://grafana.com/api/dashboards/<ID>/revisions/<REV>/download";
     hash = "sha256-<hash-from-prefetch>";
   };
   ```

   Add to `systemd.tmpfiles.rules`:
   ```nix
   "L+ /var/lib/grafana/dashboards/$1-dashboard.json - - - - \${$1Dashboard}"
   ```

**Validation:**
```bash
nixos-rebuild build --flake .#cyberspace
```

---

### Phase 5: Summary & Next Steps

**Goal:** Review changes and provide deployment commands

**Summary to provide:**

1. **Files created/modified:**
   - `hosts/cyberspace/nginx/services/$1.nix` (created)
   - `hosts/cyberspace/nginx/services/default.nix` (modified)
   - `hosts/cyberspace/metrics/exporters/$1-exporter.nix` (created if exporter exists)
   - `hosts/cyberspace/metrics/exporters/default.nix` (modified if exporter exists)
   - `hosts/cyberspace/metrics/grafana.nix` (modified if dashboard exists)
   - `hosts/cyberspace/sops.nix` (modified if API key needed)

2. **Port allocations:**
   - Service port: <port>
   - Exporter port: <port> (if applicable)

3. **What was configured:**
   - ✓ Service: $1
   - ✓ Nginx reverse proxy
   - ✓/✗ Prometheus exporter (explain status)
   - ✓/✗ Grafana dashboard (explain status)

4. **Final validation:**
   ```bash
   nixos-rebuild build --flake .#cyberspace
   ```

5. **If build succeeds, provide switch command:**
   ```bash
   sudo nixos-rebuild switch --flake .#cyberspace
   ```

6. **Access information:**
   - Get Tailscale IP: `tailscale ip -4`
   - Access URL: `http://<tailscale-ip>/$1`
   - Service will appear in dashboard at: `http://<tailscale-ip>/`

---

## Reference Files & Patterns

**Service patterns:**
- Simple proxy: `hosts/cyberspace/nginx/services/transmission.nix`
- *arr services: `hosts/cyberspace/nginx/services/radarr.nix`, `sonarr.nix`
- Indexer: `hosts/cyberspace/nginx/services/prowlarr.nix`

**Exporter patterns:**
- Built-in: `hosts/cyberspace/metrics/exporters/radarr-exporter.nix`
- Custom: `hosts/cyberspace/metrics/exporters/transmission-exporter.nix`

**Dashboard provisioning:**
- `hosts/cyberspace/metrics/grafana.nix`

**Secrets management:**
- `hosts/cyberspace/sops.nix`

**Current port allocations:**
- Services: 6789 (transmission), 7878 (radarr), 8989 (sonarr), 9696 (prowlarr)
- Exporters: 9707-9711 (used)

---

## Workflow Checklist

- [ ] Phase 0: Research completed with sub-agents
- [ ] Phase 0: User confirmation received
- [ ] Phase 1: Service file created
- [ ] Phase 1: Import added to default.nix
- [ ] Phase 1: Build validation passed
- [ ] Phase 2: Nginx configuration added
- [ ] Phase 2: Build validation passed
- [ ] Phase 3: Exporter configured (or skipped if N/A)
- [ ] Phase 3: Build validation passed
- [ ] Phase 4: Dashboard provisioned (or skipped if N/A)
- [ ] Phase 4: Build validation passed
- [ ] Phase 5: Final summary provided
- [ ] Phase 5: Switch command provided

---

**Remember:** This command uses `nixos-rebuild build` for validation only. The user must run `sudo nixos-rebuild switch` themselves to apply changes.

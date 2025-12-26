# Build Validation Guide

This guide explains how to validate your service configuration at each phase using `nixos-rebuild build`.

## Why Build-Only Validation?

Using `build` instead of `switch`:
- ✓ Validates Nix syntax without affecting running system
- ✓ Catches errors before deployment
- ✓ Safe to run multiple times
- ✓ Doesn't require sudo
- ✓ Can be run on any machine with the flake

## Validation Command

After EVERY phase, run:

```bash
nixos-rebuild build --flake .#cyberspace
```

**Expected output on success:**
```
building the system configuration...
```

The build will create a `result` symlink pointing to the new system configuration.

## Common Errors and Fixes

### Error: Syntax Error

**Example:**
```
error: syntax error, unexpected '}', expecting ';'
at /nix/store/.../hosts/cyberspace/nginx/services/bazarr.nix:15:3
```

**Cause:** Missing semicolon or invalid Nix syntax

**Fix:**
1. Read the error location: `bazarr.nix:15:3`
2. Open the file and go to line 15
3. Check for:
   - Missing semicolons
   - Unclosed braces/brackets
   - Unbalanced quotes
4. Fix and re-run build

---

### Error: Undefined Variable

**Example:**
```
error: undefined variable 'ports'
at /nix/store/.../hosts/cyberspace/nginx/services/bazarr.nix:10:20
```

**Cause:** Trying to use a variable that isn't defined

**Fix:**
1. Add `let` block at top of file if needed:
   ```nix
   let
     ports = config.services.cyberspace.ports;
   in
   ```
2. Or use full path: `config.services.cyberspace.ports.media.bazarr`
3. Re-run build

---

### Error: Attribute Not Found

**Example:**
```
error: attribute 'bazarr' missing
at /nix/store/.../hosts/cyberspace/nginx/services/bazarr.nix:8:3
```

**Cause:** Trying to access a service that doesn't exist in NixOS

**Fix:**
1. Check if the service exists: `nix search nixpkgs bazarr`
2. If service doesn't exist in nixpkgs, you need to create a custom package
3. Verify service name is correct (case-sensitive)
4. Re-run build

---

### Error: File Not Found

**Example:**
```
error: getting status of '/nix/store/.../bazarr.nix': No such file or directory
```

**Cause:** Service file imported in `default.nix` but doesn't exist

**Fix:**
1. Verify file exists: `ls hosts/cyberspace/nginx/services/bazarr.nix`
2. Check import statement in `default.nix` matches filename
3. Ensure git has tracked the file: `git add hosts/cyberspace/nginx/services/bazarr.nix`
4. Re-run build

---

### Error: Duplicate Attribute

**Example:**
```
error: attribute 'services.nginx.virtualHosts.cyberspace' already defined
```

**Cause:** Defining the same nginx virtualHost twice in one file

**Fix:**
1. Merge all nginx locations into one `virtualHosts."cyberspace"` block
2. Good pattern:
   ```nix
   services.nginx.virtualHosts."cyberspace" = {
     locations."/service1" = { ... };
     locations."/service2" = { ... };
   };
   ```
3. Bad pattern:
   ```nix
   services.nginx.virtualHosts."cyberspace" = {
     locations."/service1" = { ... };
   };
   services.nginx.virtualHosts."cyberspace" = {  # ERROR: duplicate!
     locations."/service2" = { ... };
   };
   ```
4. Re-run build

---

### Error: Infinite Recursion

**Example:**
```
error: infinite recursion encountered
```

**Cause:** Circular dependency or self-referencing attribute

**Fix:**
1. Check for service depending on itself
2. Review systemd service dependencies (after/wants/requires)
3. Use `wants` instead of `requires` when possible
4. Re-run build

---

### Error: Hash Mismatch

**Example:**
```
error: hash mismatch in fixed-output derivation
specified: sha256-abc123...
   got:    sha256-xyz789...
```

**Cause:** Incorrect hash for fetchurl (dashboard download)

**Fix:**
1. Get correct hash:
   ```bash
   nix-prefetch-url https://grafana.com/api/dashboards/12896/revisions/1/download
   ```
2. Update hash in grafana.nix
3. Re-run build

---

### Error: Port Already in Use

**Example:**
```
error: The option `services.prometheus.exporters.exportarr-bazarr.port' has conflicting definitions
```

**Cause:** Port number already allocated to another service

**Fix:**
1. Check current allocations in SERVICE_PATTERNS.md
2. Choose next available port
3. Update port number in exporter configuration
4. Re-run build

---

## Validation Checklist

After each phase, verify:

### Phase 1: Service Configuration
- [ ] Build completes successfully
- [ ] Service file exists: `ls hosts/cyberspace/nginx/services/<service>.nix`
- [ ] Import added to default.nix
- [ ] No syntax errors
- [ ] Service registry entry present
- [ ] Sops secrets defined (if needed)

### Phase 2: Nginx Configuration
- [ ] Build completes successfully
- [ ] Nginx virtualHost defined
- [ ] All required proxy headers present
- [ ] No duplicate location blocks
- [ ] WebSocket support added (if needed)

### Phase 3: Prometheus Exporter
- [ ] Build completes successfully
- [ ] Exporter file exists (if created)
- [ ] Import added to exporters/default.nix (if created)
- [ ] Port not conflicting with existing services
- [ ] Metrics registry entry correct
- [ ] Skipped if no exporter available (OK)

### Phase 4: Grafana Dashboard
- [ ] Build completes successfully
- [ ] Dashboard hash correct
- [ ] Tmpfiles rule added
- [ ] Skipped if no dashboard available (OK)

### Phase 5: Final Validation
- [ ] All previous phases validated
- [ ] Build completes successfully
- [ ] Ready for switch

---

## When to Proceed vs Fix

### ✅ Proceed to Next Phase When:
- Build completes with no errors
- All warnings are expected (deprecation warnings are OK)
- Output shows "building the system configuration..."
- `result` symlink created successfully

### ❌ Stop and Fix When:
- Any syntax errors
- Attribute not found errors
- File not found errors
- Hash mismatch errors
- Port conflict errors
- Infinite recursion errors

**Golden Rule:** Never proceed to the next phase if the build fails. Fix all errors first.

---

## Advanced Validation

### Check Specific Service Configuration

After build completes, inspect the generated config:

```bash
# View service configuration
nix-instantiate --eval -E '(import <nixpkgs/nixos> { configuration = ./hosts/cyberspace/default.nix; }).config.services.bazarr'

# View nginx configuration
nix-instantiate --eval -E '(import <nixpkgs/nixos> { configuration = ./hosts/cyberspace/default.nix; }).config.services.nginx.virtualHosts.cyberspace'
```

### Validate Without Building

Quick syntax check:

```bash
nix flake check --no-build
```

This checks flake structure and Nix syntax without actually building.

### Format Nix Files

Before final validation, format all nix files:

```bash
nix fmt
```

This ensures consistent formatting and may catch some syntax issues.

---

## Final Switch

Only after ALL phases validate successfully:

```bash
sudo nixos-rebuild switch --flake .#cyberspace
```

**This command:**
- Builds the configuration
- Activates it on the running system
- Restarts modified services
- Makes changes permanent

**Warning:** Only run this after thorough validation!

---

## Troubleshooting Tips

### Build is Slow
- First build downloads packages (slow)
- Subsequent builds use cache (fast)
- Use `--option eval-cache true` to speed up evaluation

### Build Fails After Recent Flake Update
```bash
nix flake update
nixos-rebuild build --flake .#cyberspace
```

### Can't Find Error Location
Look for the file path and line number in error message:
```
at /nix/store/.../path/to/file.nix:15:3
                                    ^^  ^^
                                   line column
```

### Stuck on "evaluating"
- Likely infinite recursion
- Press Ctrl+C to cancel
- Check for circular dependencies
- Review recent changes

### Permission Denied
```bash
# Don't use sudo for build:
nixos-rebuild build --flake .#cyberspace  # ✓ Correct

# Only use sudo for switch:
sudo nixos-rebuild switch --flake .#cyberspace  # ✓ Correct
```

---

## Quick Reference

**After each phase:**
```bash
nixos-rebuild build --flake .#cyberspace
```

**If build succeeds:** ✅ Proceed to next phase

**If build fails:** ❌ Read error, fix, retry

**Final deployment:**
```bash
sudo nixos-rebuild switch --flake .#cyberspace
```

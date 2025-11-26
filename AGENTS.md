# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Apply configuration (macOS)
darwin-rebuild switch --flake .

# Format nix files
nix fmt

# Update flake inputs
nix flake update

# Update a specific input
nix flake lock --update-input <input-name>

# Check flake for errors
nix flake check
```

## Architecture

This is a Nix flake-based configuration for managing macOS systems using nix-darwin and home-manager.

### Directory Structure

- `flake.nix` - Entry point defining inputs (nixpkgs, home-manager, nix-darwin) and host configurations
- `hosts/` - Per-machine configurations
  - `hosts/<hostname>/default.nix` - System-level config (nix-darwin)
  - `hosts/<hostname>/home-manager/` - User-level config for that host
  - `hosts/common/` - Shared configuration modules (core, darwin-specific)
- `home-manager/common/` - Shared home-manager modules (programs like git, tmux, zsh, doom emacs)
- `home-manager/darwin/` - macOS-specific home-manager modules
- `overlays/` - Package modifications and additions (unstable packages via `pkgs.unstable`)
- `pkgs/` - Custom package definitions
- `modules/` - Reusable NixOS and home-manager modules

### Current Hosts

- `heatseeker` - Work machine (user: paulo.casaretto)
- `littlelover` - Personal machine (user: pcasaretto)
- `overdose` - Additional machine

### Adding a New Host

1. Create `hosts/<hostname>/default.nix` with system config
2. Create `hosts/<hostname>/home-manager/default.nix` with user config
3. Add the host to `darwinConfigurations` in `flake.nix`

### Package Access Patterns

- Stable packages: `pkgs.<package>`
- Unstable packages: `pkgs.unstable.<package>` (via overlay)
- Custom packages: defined in `pkgs/` and accessed via `additions` overlay

# Base Pi configuration - personal preferences and generic extensions
{
  config,
  lib,
  pkgs,
  ...
}: let
  cc-safety-net = pkgs.callPackage ../../../../pkgs/cc-safety-net {};

  # Custom rules for cc-safety-net (shared with Claude Code)
  safetyNetConfig = {
    version = 1;
    rules = [
      {
        name = "gt-submit-force";
        command = "gt";
        subcommand = "submit";
        block_args = ["--force"];
        reason = "gt submit --force overwrites remote PRs without confirmation";
      }
    ];
  };
  safetyNetConfigFile = pkgs.writeText "cc-safety-net-config.json" (builtins.toJSON safetyNetConfig);

  # Generate safety-net.ts with the correct binary path
  safetyNetExtension = pkgs.replaceVars ./extensions/safety-net.ts {
    safetyNetBinary = "${cc-safety-net}/bin/cc-safety-net";
  };

  # All common extensions (safety-net is generated, rest are static)
  commonExtensions = [
    {
      name = "safety-net.ts";
      path = safetyNetExtension;
    }
    {
      name = "notify.ts";
      path = ./extensions/notify.ts;
    }
  ];

  # Settings we want to control via nix (merged with existing settings.json)
  nixSettings = {
    hideThinkingBlock = false;
    defaultThinkingLevel = "high";
  };
  nixSettingsFile = pkgs.writeText "pi-settings-nix.json" (builtins.toJSON nixSettings);
in {
  # Symlink extensions, skills, prompts, and AGENTS.md into ~/.pi/agent/
  # (AGENTS.md is also copied to ~/.omp/agent/ so the OMP native provider loads it)
  home.file =
    # Global agent instructions
    {
      ".pi/agent/AGENTS.md".source = ./AGENTS.md;
      ".omp/agent/AGENTS.md".source = ./AGENTS.md;
      # Directory extensions (multi-file)
      # ".pi/agent/extensions/vim-mode".source = ./extensions/vim-mode;
      # cc-safety-net custom rules
      ".cc-safety-net/config.json".source = safetyNetConfigFile;
    }
    # Common extensions
    // builtins.listToAttrs (map (ext: {
        name = ".pi/agent/extensions/${ext.name}";
        value = {source = ext.path;};
      })
      commonExtensions);

  # Migrate ~/.pi/agent-shopify → ~/.pi/agent and set up symlinks
  # After migration: ~/.pi/agent/ is the real directory, ~/.pi/agent-shopify → agent
  home.activation.migratePiAgent = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # If agent-shopify is the real dir and agent is a symlink to it, flip them
    if [ -d ~/.pi/agent-shopify ] && [ ! -L ~/.pi/agent-shopify ]; then
      # agent-shopify is a real directory — migrate it

      # Remove the old agent symlink (or dir) if it exists
      if [ -L ~/.pi/agent ]; then
        rm ~/.pi/agent
      fi

      # Move agent-shopify contents into agent
      mv ~/.pi/agent-shopify ~/.pi/agent

      # Create the compat symlink
      ln -s agent ~/.pi/agent-shopify
      echo "Migrated ~/.pi/agent-shopify → ~/.pi/agent"
    fi

    # Ensure ~/.pi/agent exists as a real directory
    mkdir -p ~/.pi/agent

    # Ensure ~/.pi/agent-shopify is a symlink to agent
    if [ ! -e ~/.pi/agent-shopify ]; then
      ln -s agent ~/.pi/agent-shopify
    fi
  '';

  # Merge nix settings into existing settings.json (preserves runtime state)
  home.activation.mergePiSettings = lib.hm.dag.entryAfter ["migratePiAgent"] ''
    if [ -f ~/.pi/agent/settings.json ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
        ~/.pi/agent/settings.json \
        ${nixSettingsFile} \
        > ~/.pi/agent/settings.json.tmp && mv ~/.pi/agent/settings.json.tmp ~/.pi/agent/settings.json
    else
      cp ${nixSettingsFile} ~/.pi/agent/settings.json
    fi
  '';
}

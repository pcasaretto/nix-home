# Base Claude Code configuration - personal preferences and generic tools
{
  config,
  lib,
  pkgs,
  ...
}: let
  cc-safety-net = pkgs.callPackage ../../../../pkgs/cc-safety-net {};

  # Settings we want to control via nix (merged with existing settings.json)
  nixSettings = {
    model = "opus";
    alwaysThinkingEnabled = true;
    includeCoAuthoredBy = false;
    permissions.deny = ["Bash(git rebase)"];
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
    # Disable the plugin since we manage it via nix
    enabledPlugins."safety-net@cc-marketplace" = false;
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${cc-safety-net}/bin/cc-safety-net --claude-code";
            }
          ];
        }
      ];
    };
  };
  nixSettingsFile = pkgs.writeText "claude-settings-nix.json" (builtins.toJSON nixSettings);
in {
  programs.claude-code = {
    enable = true;
    package = null; # Managed externally (not via nix)

    memory.source = ./memory-personal.md;

    commandsDir = ./commands;
    skillsDir = ./skills;
    agentsDir = ./agents;
  };

  # Merge nix settings into existing settings.json (preserves Shopify auth config)
  home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -f ~/.claude/settings.json ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
        ~/.claude/settings.json \
        ${nixSettingsFile} \
        > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
    else
      cp ${nixSettingsFile} ~/.claude/settings.json
    fi
  '';
}

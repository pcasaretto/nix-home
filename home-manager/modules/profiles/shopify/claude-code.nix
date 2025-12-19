# Shopify-specific Claude Code additions
# Extends the common claude-code config with work-specific memory, commands, and skills
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Read memory content from both sources
  personalMemory = builtins.readFile ../../common/claude-code/memory-personal.md;
  shopifyMemory = builtins.readFile ./claude-code-memory.md;

  # Merge command directories (common + shopify)
  mergedCommands = pkgs.symlinkJoin {
    name = "claude-code-commands";
    paths = [
      ../../common/claude-code/commands
      ./commands
    ];
  };

  # Merge skill directories (common + shopify)
  mergedSkills = pkgs.symlinkJoin {
    name = "claude-code-skills";
    paths = [
      ../../common/claude-code/skills
      ./skills
    ];
  };

  # Shopify-specific settings to merge (adds MCP tool permissions)
  shopifySettings = {
    permissions.allow = [
      "mcp__vault-set-search__search_vault_set"
      "mcp__experiments-mcp__flag_status"
      "mcp__experiments-mcp__flag_create"
      "mcp__data-portal__list_data_platform_docs"
      "mcp__data-portal__search_data_platform"
      "mcp__data-portal__get_entry_metadata"
      "mcp__data-portal__query_bigquery"
      "mcp__data-portal__analyze_query_results"
      "mcp__gworkspace-mcp__get_file_content"
      "mcp__macos-notify__notify"
    ];
  };
  shopifySettingsFile = pkgs.writeText "claude-settings-shopify.json" (builtins.toJSON shopifySettings);
in {
  programs.claude-code = {
    # Override memory with combined personal + shopify content
    memory = {
      source = lib.mkForce null;
      text = ''
        ${personalMemory}

        ${shopifyMemory}
      '';
    };

    # Use merged directories for commands and skills
    commandsDir = lib.mkForce mergedCommands;
    skillsDir = lib.mkForce mergedSkills;
    # agents stay as common (no Shopify-specific agents)
  };

  # Merge Shopify settings after common settings
  home.activation.mergeClaudeSettingsShopify = lib.hm.dag.entryAfter ["mergeClaudeSettings"] ''
    ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
      ~/.claude/settings.json \
      ${shopifySettingsFile} \
      > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
  '';
}

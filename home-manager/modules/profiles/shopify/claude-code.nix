# Shopify-specific Claude Code additions
# Extends the common claude-code config with work-specific memory, commands, and skills
{
  config,
  lib,
  pkgs,
  ...
}: let
  cc-safety-net = pkgs.callPackage ../../../../pkgs/cc-safety-net {};

  # Read memory content from both sources
  personalMemory = builtins.readFile ../../common/claude-code/memory-personal.md;
  shopifyMemory = builtins.readFile ./claude-code-memory.md;

  # Merge command directories (common + shopify + safety-net)
  mergedCommands = pkgs.symlinkJoin {
    name = "claude-code-commands";
    paths = [
      ../../common/claude-code/commands
      ./commands
      "${cc-safety-net}/share/cc-safety-net/commands"
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
      # MCP tools - Shopify internal
      "mcp__vault-set-search__search_vault_set"
      "mcp__experiments-mcp__flag_status"
      "mcp__experiments-mcp__flag_create"
      "mcp__experiments-mcp__search"
      "mcp__shopify-internal__grokt_search"

      # MCP tools - Data portal
      "mcp__data-portal__list_data_platform_docs"
      "mcp__data-portal__search_data_platform"
      "mcp__data-portal__get_entry_metadata"
      "mcp__data-portal__query_bigquery"
      "mcp__data-portal__analyze_query_results"

      # MCP tools - Google Workspace
      "mcp__gworkspace-mcp__get_file_content"
      "mcp__gworkspace-mcp__read_file"

      # MCP tools - Slack
      "mcp__playground-slack-mcp__get_messages"
      "mcp__playground-slack-mcp__slack_search"
      "mcp__playground-slack-mcp__slack_get_thread_replies"


      "mcp__observe__*"
      "mcp__observe__query_dataset"
      "mcp__observe__get_datasets_by_signal"
      "mcp__observe__get_error_groups"
      "mcp__observe__get_observe_metrics"
      "mcp__observe__get_investigate_query_docs"
      "mcp__observe__range_metrics_query"

      # MCP tools - Notifications
      "mcp__macos-notify__notify"

      # Bash - File utilities (read-only)
      "Bash(ls:*)"
      "Bash(find:*)"
      "Bash(cat:*)"
      "Bash(head:*)"
      "Bash(wc:*)"
      "Bash(lsof:*)"

      # Bash - Search/text processing
      "Bash(grep:*)"
      "Bash(rg:*)"
      "Bash(jq:*)"
      "Bash(awk:*)"

      # Bash - System info
      "Bash(scutil:*)"
      "Bash(brew list:*)"
      "Bash(launchctl list:*)"
      "Bash(dig:*)"
      "Bash(time:*)"
      "Bash(echo $GEM_HOME)"

      # Bash - Git (read-only)
      "Bash(git status:*)"
      "Bash(git log:*)"
      "Bash(git diff:*)"
      "Bash(git branch:*)"
      "Bash(git show:*)"
      "Bash(git reflog:*)"
      "Bash(git rev-parse:*)"
      "Bash(git merge-base:*)"
      "Bash(git ls-tree:*)"
      "Bash(git remote get-url:*)"

      # Bash - GitHub CLI
      "Bash(gh pr:*)"
      "Bash(gh issue:*)"
      "Bash(gh api:*)"
      "Bash(gh repo view:*)"
      "Bash(gh search:*)"

      # Bash - Nix ecosystem
      "Bash(nix-store:*)"
      "Bash(nix fmt:*)"
      "Bash(nix build:*)"
      "Bash(nix flake:*)"
      "Bash(nix flake check:*)"
      "Bash(nix develop:*)"
      "Bash(nix-shell:*)"
      "Bash(nix eval:*)"

      # Bash - Dev tools
      "Bash(ruby:*)"
      "Bash(python3:*)"
      "Bash(make:*)"
      "Bash(mkdir:*)"
      "Bash(/usr/bin/osascript:*)"
      "Bash(monobus --help:*)"

      # Bash - Shopify dev commands
      "Bash(/opt/dev/bin/dev version)"
      "Bash(/opt/dev/bin/dev test:*)"
      "Bash(/opt/dev/bin/dev style:*)"
      "Bash(/opt/dev/bin/dev typecheck:*)"
      "Bash(/opt/dev/bin/dev up:*)"

      # Bash - shadowenv exec combinations
      "Bash(shadowenv exec:*)"
      "Bash(shadowenv exec -- /opt/dev/bin/dev test:*)"
      "Bash(shadowenv exec -- /opt/dev/bin/dev style:*)"
      "Bash(shadowenv exec -- /opt/dev/bin/dev typecheck:*)"
      "Bash(shadowenv exec -- /opt/dev/bin/dev up:*)"
      "Bash(shadowenv exec -- bundle exec rspec:*)"
      "Bash(shadowenv exec -- bundle exec ruby:*)"
      "Bash(shadowenv exec -- bundle exec rake:*)"

      # Skills
      "Skill(shopify-verdict-flags)"
      "Skill(macos-notify)"
      "Skill(code-delta)"

      # Web access
      "WebSearch"
      "WebFetch(domain:github.com)"
      "WebFetch(domain:raw.githubusercontent.com)"

      # Read access
      "Read(/Users/paulo.casaretto/world/**)"
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

# Shopify-specific Pi configuration
# Adds proxy provider config and Shopify-specific settings
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Shopify-specific settings to merge
  shopifySettings = {
    defaultProvider = "anthropic-1m";
    defaultModel = "claude-opus-4-6";
  };
  shopifySettingsFile = pkgs.writeText "pi-settings-shopify.json" (builtins.toJSON shopifySettings);

  # Shopify-specific skills (shared with Claude Code)
  shopifySkills = [
    {
      name = "observe-dashboard-generator";
      path = ../skills/observe-dashboard-generator;
    }
    {
      name = "verdict-flags";
      path = ../skills/verdict-flags;
    }
  ];
in {
  # models.json and Shopify skills
  home.file =
    {".pi/agent/models.json".source = ./models.json;}
    // builtins.listToAttrs (map (skill: {
        name = ".pi/agent/skills/${skill.name}";
        value = {source = skill.path;};
      })
      shopifySkills);

  # Merge Shopify settings after common settings
  home.activation.mergePiSettingsShopify = lib.hm.dag.entryAfter ["mergePiSettings"] ''
    ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
      ~/.pi/agent/settings.json \
      ${shopifySettingsFile} \
      > ~/.pi/agent/settings.json.tmp && mv ~/.pi/agent/settings.json.tmp ~/.pi/agent/settings.json
  '';
}

{ config, inputs, lib, ... }:
{
  # Use SSH host keys for age encryption (automatically generated when openssh is enabled)
  sops.age.sshKeyPaths = lib.filter
    (path: lib.hasSuffix "ssh_host_ed25519_key" path)
    (builtins.map (key: key.path) config.services.openssh.hostKeys);

  # Define secrets
  sops.secrets.tailscale_authkey = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
  };

  sops.secrets.grafana-admin-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "grafana";
    group = "grafana";
  };

  sops.secrets.pcasaretto-password-hash = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    neededForUsers = true;
  };

  # Media service API keys for *arr services and exporters
  sops.secrets.sonarr-api-key = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "sonarr";
    group = "media";
    mode = "0440";
  };

  sops.secrets.radarr-api-key = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "radarr";
    group = "media";
    mode = "0440";
  };

  sops.secrets.prowlarr-api-key = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "prowlarr";
    group = "media";
    mode = "0440";
  };

  sops.secrets.jellyfin-admin-username = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "jellyfin";
    group = "jellyfin";
    mode = "0400";
  };

  sops.secrets.jellyfin-admin-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "jellyfin";
    group = "jellyfin";
    mode = "0400";
  };


  # Nextcloud admin credentials
  sops.secrets.nextcloud-admin-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0400";
  };

  # Nextcloud exporter credentials (reuses admin password)
  sops.secrets.nextcloud-exporter-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    key = "nextcloud-admin-password";
    owner = "nextcloud-exporter";
    group = "nextcloud-exporter";
    mode = "0400";
  };

  # Cloudflare API token for Caddy DNS-01 challenge (Let's Encrypt wildcard certs)
  sops.secrets.cloudflare-api-token = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "caddy";
    group = "caddy";
    mode = "0400";
  };

  # Telegram bot token for clawdbot service
  sops.secrets.clawdbot-telegram-token = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "clawdbot";
    group = "clawdbot";
    mode = "0400";
  };

  # Telegram bot token readable by *arr services
  sops.secrets.telegram-token = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    key = "clawdbot-telegram-token";
    group = "media";
    mode = "0440";
  };

  # Telegram chat ID for *arr services
  sops.secrets.clawdbot-telegram-chat-id = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    group = "media";
    mode = "0440";
  };

  # Home Assistant Long-Lived Access Token for Prometheus scraping
  # Generate from Home Assistant UI: Profile -> Security -> Long-Lived Access Tokens
  # Only enabled when services.cyberspace.homeAssistant.enableMetrics = true
  sops.secrets.home-assistant-token = lib.mkIf config.services.cyberspace.homeAssistant.enableMetrics {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "prometheus";
    group = "prometheus";
    mode = "0400";
  };
}

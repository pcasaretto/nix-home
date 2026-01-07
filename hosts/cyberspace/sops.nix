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

  # ntfy notification service credentials
  sops.secrets.ntfy-admin-username = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "ntfy-sh";
    group = "ntfy-sh";
    mode = "0400";
  };

  sops.secrets.ntfy-admin-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "ntfy-sh";
    group = "ntfy-sh";
    mode = "0400";
  };

  # ntfy credentials readable by *arr services for notification integration
  sops.secrets.ntfy-username = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    key = "ntfy-admin-username";
    group = "media";
    mode = "0440";
  };

  sops.secrets.ntfy-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    key = "ntfy-admin-password";
    group = "media";
    mode = "0440";
  };

  # ntfy credentials for Grafana alerting
  sops.secrets.ntfy-grafana-username = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    key = "ntfy-admin-username";
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  sops.secrets.ntfy-grafana-password = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    key = "ntfy-admin-password";
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  # Cloudflare API token for Caddy DNS-01 challenge (Let's Encrypt wildcard certs)
  sops.secrets.cloudflare-api-token = {
    sopsFile = "${inputs.mysecrets}/secrets/cyberspace.yaml";
    owner = "caddy";
    group = "caddy";
    mode = "0400";
  };
}

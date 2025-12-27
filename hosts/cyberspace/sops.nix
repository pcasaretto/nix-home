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
}

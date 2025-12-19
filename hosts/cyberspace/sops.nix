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
}

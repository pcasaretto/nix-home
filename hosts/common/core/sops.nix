{ inputs, config, ... }:
let
  secretsPath = builtins.toString inputs.mysecrets;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = "${secretsPath}/hosts/common/secrets.yaml";
    validateSopsFiles = false;

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      nixos-password = { neededForUsers = true; };
    };
  };
}

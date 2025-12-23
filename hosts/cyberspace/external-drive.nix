{
  config,
  lib,
  pkgs,
  ...
}: {
  # Create dedicated group for external drive access
  users.groups.external = {
    gid = 1001;
  };

  # Mount external SanDisk Extreme drive
  # UUID: 6941-B41D (exFAT partition)
  fileSystems."/mnt/external" = {
    device = "/dev/disk/by-uuid/6941-B41D";
    fsType = "exfat";
    options = [
      "nofail" # Don't fail boot if drive is not connected
      "uid=1000" # Set owner to pcasaretto
      "gid=1001" # Set group to external
      "dmask=0002" # Directory permissions: rwxrwxr-x (group writable)
      "fmask=0113" # File permissions: rw-rw-r--
    ];
  };

  # Ensure the mount point exists
  systemd.tmpfiles.rules = [
    "d /mnt/external 0755 pcasaretto external -"
  ];

  # Install exfat utilities
  environment.systemPackages = with pkgs; [
    exfatprogs
  ];
}

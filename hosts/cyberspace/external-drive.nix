{
  config,
  lib,
  pkgs,
  ...
}: {
  # Mount external SanDisk Extreme drive
  # UUID: 6941-B41D (exFAT partition)
  fileSystems."/mnt/external" = {
    device = "/dev/disk/by-uuid/6941-B41D";
    fsType = "exfat";
    options = [
      "nofail" # Don't fail boot if drive is not connected
      "uid=1000" # Set owner to pcasaretto
      "gid=100" # Set group to users
      "dmask=0022" # Directory permissions: rwxr-xr-x
      "fmask=0133" # File permissions: rw-r--r--
    ];
  };

  # Ensure the mount point exists
  systemd.tmpfiles.rules = [
    "d /mnt/external 0755 pcasaretto users -"
  ];

  # Install exfat utilities
  environment.systemPackages = with pkgs; [
    exfatprogs
  ];
}

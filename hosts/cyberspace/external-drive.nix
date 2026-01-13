_: {
  # Create dedicated group for external drive access
  users.groups.external = {
    gid = 1001;
  };

  # Mount external SanDisk Extreme drive (ext4)
  fileSystems."/mnt/external" = {
    device = "/dev/disk/by-uuid/cc461254-dbd7-43fb-9d5d-06c4ccec15f7";
    fsType = "ext4";
    options = [
      "nofail" # Don't fail boot if drive is not connected
    ];
  };

  # Ensure the mount point and subdirectories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt/external 0775 root external -"
    "d /mnt/external/nextcloud 0750 nextcloud nextcloud -"
    "d /mnt/external/media 0775 pcasaretto external -"
    "d /mnt/external/downloads 0775 pcasaretto external -"
  ];
}

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
      "x-systemd.automount" # Auto-mount when accessed and on reconnect
      "x-systemd.idle-timeout=0" # Never unmount due to idle
      "x-systemd.mount-timeout=30" # Give it time to mount
    ];
  };

  # Ensure the mount point and subdirectories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt/external 0775 root external -"
    "d /mnt/external/nextcloud 0750 nextcloud nextcloud -"
    "d /mnt/external/media 0775 pcasaretto external -"
    "d /mnt/external/downloads 0775 pcasaretto external -"
  ];

  # Self-healing: restart media services when external drive is (re)mounted
  systemd.services.external-drive-services-restart = {
    description = "Restart services after external drive mount";
    after = [ "mnt-external.mount" ];
    bindsTo = [ "mnt-external.mount" ];
    wantedBy = [ "mnt-external.mount" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Wait for mount to stabilize before restarting services
      ExecStartPre = "/run/current-system/sw/bin/sleep 3";
      ExecStart = "/run/current-system/sw/bin/systemctl restart --no-block jellyfin sonarr radarr transmission phpfpm-nextcloud";
    };

    # Only restart if services were previously running (avoid restart on boot)
    unitConfig = {
      ConditionPathExists = "/run/systemd/units/invocation:jellyfin.service";
    };
  };

  # Disable USB autosuspend for SanDisk drives to prevent disconnects
  services.udev.extraRules = ''
    # Disable autosuspend for SanDisk USB devices
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0781", ATTR{power/autosuspend}="-1"
  '';
}

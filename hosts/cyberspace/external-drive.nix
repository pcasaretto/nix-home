{
  pkgs,
  lib,
  ...
}: let
  driveUuid = "cc461254-dbd7-43fb-9d5d-06c4ccec15f7";
  mountpoint = "/mnt/external";
  mountUnit = "mnt-external.mount";
  dependentServices = "jellyfin sonarr radarr transmission";

  mediaServices = [
    "jellyfin"
    "jellyfin-admin-init"
    "radarr"
    "radarr-setup"
    "radarr-telegram-setup"
    "radarr-prowlarr-sync"
    "sonarr"
    "sonarr-setup"
    "sonarr-telegram-setup"
    "sonarr-prowlarr-sync"
    "transmission"
    "prometheus-transmission-exporter"
    "prometheus-exportarr-radarr-exporter"
    "prometheus-exportarr-sonarr-exporter"
  ];

  skipWhenExternalMissing = lib.genAttrs mediaServices (_: {
    # These services are useful only when the external media drive is mounted.
    # Do not let them pull mnt-external.mount into the boot transaction when
    # the drive is absent; skip them cleanly instead.
    unitConfig.ConditionPathExists = "/dev/disk/by-uuid/${driveUuid}";
    requires = lib.mkForce [];
    serviceConfig.TimeoutStartSec = "30s";
  });

  watchdogScript = pkgs.writeShellScript "external-drive-watchdog" ''
    # Only check if the mount is supposed to be active
    if ! ${pkgs.util-linux}/bin/findmnt -rn -t ext4 --target "${mountpoint}" >/dev/null; then
      exit 0
    fi

    # Test write access
    if touch "${mountpoint}/.healthcheck" 2>/dev/null; then
      rm -f "${mountpoint}/.healthcheck"
      exit 0
    fi

    echo "Mount ${mountpoint} is unhealthy, attempting recovery"

    # Lazy unmount the zombie
    ${pkgs.util-linux}/bin/umount -l "${mountpoint}" 2>/dev/null

    # Wait briefly for the old mount to clear
    sleep 2

    # Check if the device is present
    DEVICE=$(${pkgs.util-linux}/bin/blkid -U "${driveUuid}" 2>/dev/null)
    if [ -z "$DEVICE" ]; then
      echo "Device not present, skipping remount"
      exit 1
    fi

    # Filesystem check before remounting
    ${pkgs.e2fsprogs}/bin/fsck.ext4 -y "$DEVICE" 2>/dev/null || true

    # Remount
    ${pkgs.util-linux}/bin/mount "$DEVICE" "${mountpoint}"

    if ${pkgs.util-linux}/bin/findmnt -rn -t ext4 --target "${mountpoint}" >/dev/null && touch "${mountpoint}/.healthcheck" 2>/dev/null; then
      rm -f "${mountpoint}/.healthcheck"
      echo "Recovery complete, restarting services"
      ${pkgs.systemd}/bin/systemctl restart --no-block ${dependentServices}
    else
      echo "Recovery failed"
      exit 1
    fi
  '';
in {
  # Create dedicated group for external drive access
  users.groups.external = {
    gid = 1001;
  };

  # Mount external SanDisk Extreme drive (ext4)
  fileSystems."${mountpoint}" = {
    device = "/dev/disk/by-uuid/${driveUuid}";
    fsType = "ext4";
    options = [
      "nofail" # Don't fail boot if drive is not connected
      "noauto" # Do not try to mount during boot; services skip if absent
      "x-systemd.automount" # Mount on demand when the drive is present/accessed
      "x-systemd.device-timeout=5s" # Do not wait 90s for a missing USB disk
      "x-systemd.mount-timeout=15s"
      "errors=remount-ro" # Remount read-only on error
      "nodelalloc" # Reduce corruption risk on surprise removal
      "commit=3" # Shorter sync window for USB
      "noatime" # Fewer unnecessary writes
    ];
  };

  # Ensure the mount point and subdirectories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d ${mountpoint} 0775 root external -"
    "d ${mountpoint}/media 0775 pcasaretto external -"
    "d ${mountpoint}/downloads 0775 pcasaretto external -"
  ];

  # Apply the external-drive guard to all media services and setup/exporter
  # oneshots. Several of those services are also enabled by multi-user.target,
  # and the setup oneshots contain polling loops; without this guard, a missing
  # USB disk can block the boot transaction and graphical.target.
  systemd.services =
    skipWhenExternalMissing
    // {
      # Self-healing: restart media services when external drive is (re)mounted
      # Handles the clean case where systemd sees the mount go away and come back
      external-drive-services-restart = {
        unitConfig.ConditionPathExists = "/dev/disk/by-uuid/${driveUuid}";
        description = "Restart services after external drive mount";
        after = [mountUnit];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "/run/current-system/sw/bin/sleep 3";
          ExecStart = "/run/current-system/sw/bin/systemctl restart --no-block ${dependentServices}";
        };
      };

      # Watchdog: detect zombie mounts (kernel keeps broken mount alive after USB disconnect)
      # The bindsTo approach above can't catch this because systemd still sees the mount as active
      external-drive-watchdog = {
        unitConfig.ConditionPathExists = "/dev/disk/by-uuid/${driveUuid}";
        description = "Health check for external drive mount";
        after = [mountUnit];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = watchdogScript;
        };
      };
    };

  systemd.timers.external-drive-watchdog = {
    description = "Periodic health check for external drive";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "60";
      OnUnitActiveSec = "30";
    };
  };

  # Disable USB autosuspend for SanDisk drives to prevent disconnects
  services.udev.extraRules = ''
    # Disable autosuspend for SanDisk USB devices
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0781", ATTR{power/autosuspend}="-1"
  '';
}

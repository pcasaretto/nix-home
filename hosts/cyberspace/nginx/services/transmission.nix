{ config, pkgs, ... }:

{
  # Enable Transmission BitTorrent daemon
  services.transmission = {
    enable = true;

    # Network settings
    settings = {
      # Download location
      download-dir = "/mnt/external/downloads";
      incomplete-dir = "/mnt/external/downloads/.incomplete";
      incomplete-dir-enabled = true;

      # Web UI settings
      rpc-bind-address = "127.0.0.1";
      rpc-port = 9091;
      rpc-authentication-required = false;  # Safe since only accessible via Tailscale
      rpc-host-whitelist-enabled = false;
      rpc-whitelist-enabled = false;

      # Download settings
      download-queue-enabled = true;
      download-queue-size = 5;
      speed-limit-down-enabled = false;
      speed-limit-up-enabled = false;

      # Peer settings
      peer-port = 51413;
      peer-port-random-on-start = false;
      port-forwarding-enabled = true;

      # Privacy and encryption
      encryption = 2;  # Require encryption
      dht-enabled = true;
      pex-enabled = true;
      lpd-enabled = true;

      # Misc settings
      umask = 2;  # rw-rw-r-- permissions for downloaded files
      ratio-limit-enabled = false;
      idle-seeding-limit-enabled = false;
    };

    # Run as transmission user (will be created)
    user = "transmission";
    group = "transmission";

    # Ensure download directory exists and has proper permissions
    home = "/var/lib/transmission";
  };

  # Ensure the downloads directory exists with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt/external/downloads 0775 transmission transmission -"
    "d /mnt/external/downloads/.incomplete 0775 transmission transmission -"
  ];

  # Add pcasaretto user to transmission group for access to downloads
  users.users.pcasaretto.extraGroups = [ "transmission" ];

  # Register in service registry
  services.cyberspace.registeredServices.transmission = {
    name = "Transmission";
    description = "BitTorrent client with web interface - downloads to external drive";
    path = "/transmission";
    icon = "📥";
    enabled = true;
    port = 9091;
    tags = [ "download" "torrent" "media" ];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/transmission/" = {
      proxyPass = "http://127.0.0.1:9091/transmission/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Pass through the RPC path
        proxy_pass_header X-Transmission-Session-Id;

        # Timeouts for long-running requests
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
      '';
    };
  };
}

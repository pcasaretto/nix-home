{ config, pkgs, lib, ... }:

let
  certDomain = "cyberspace.tyrannosaurus-regulus.ts.net";
  certDir = "/var/lib/tailscale-certs";
  certScript = pkgs.writeShellScript "tailscale-cert-renew" ''
    set -e

    # Create cert directory if it doesn't exist
    mkdir -p ${certDir}
    chmod 755 ${certDir}

    # Generate/renew certificate
    echo "Requesting certificate for ${certDomain}..."
    cd ${certDir}
    ${pkgs.tailscale}/bin/tailscale cert ${certDomain}

    # Set proper permissions
    chmod 644 ${certDomain}.crt
    chmod 600 ${certDomain}.key

    echo "Certificate generated successfully at ${certDir}"
    echo "Certificate: ${certDir}/${certDomain}.crt"
    echo "Key: ${certDir}/${certDomain}.key"

    # Reload nginx if it's running
    if systemctl is-active nginx.service > /dev/null 2>&1; then
      echo "Reloading nginx..."
      systemctl reload nginx.service
    fi
  '';
in
{
  # Service to generate/renew Tailscale TLS certificates
  systemd.services.tailscale-cert-renew = {
    description = "Renew Tailscale TLS certificates";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "tailscaled.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = certScript;
      # Run as root to access tailscale
      User = "root";
    };
  };

  # Timer to renew certificates every 60 days (certs are valid for 90)
  systemd.timers.tailscale-cert-renew = {
    description = "Timer for Tailscale TLS certificate renewal";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "5min";  # Run 5 minutes after boot
      OnUnitActiveSec = "60d";  # Renew every 60 days
      Persistent = true;  # Catch up if system was off
    };
  };

  # Path unit to reload nginx when certs change
  systemd.paths.tailscale-cert-watcher = {
    description = "Watch Tailscale certificates for changes";
    wantedBy = [ "multi-user.target" ];

    pathConfig = {
      PathChanged = "${certDir}/${certDomain}.crt";
      Unit = "nginx-reload-on-cert-change.service";
    };
  };

  systemd.services.nginx-reload-on-cert-change = {
    description = "Reload nginx when Tailscale cert changes";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reload nginx.service";
    };
  };
}

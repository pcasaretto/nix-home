{pkgs, ...}: {
  systemd.services.tailscale-funnel = {
    description = "Tailscale Funnel for public services";
    after = [
      "network-online.target"
      "tailscaled.service"
      "caddy.service"
    ];
    wants = ["network-online.target"];
    requires = [
      "tailscaled.service"
      "caddy.service"
    ];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [pkgs.tailscale pkgs.jq];
    script = ''
      # Wait for Tailscale to be fully connected
      for i in $(seq 1 30); do
        status=$(tailscale status --json | jq -r '.BackendState')
        if [ "$status" = "Running" ]; then
          break
        fi
        sleep 2
      done

      if [ "$status" != "Running" ]; then
        echo "Tailscale not running after 60s, giving up"
        exit 1
      fi

      # Expose spellbook via Funnel on port 8443 (443 is used by Caddy for internal services)
      tailscale funnel --bg --https=8443 http://localhost:8180
    '';
  };
}

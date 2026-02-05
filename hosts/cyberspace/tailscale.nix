{ config, ... }:
{
  services.tailscale = {
    enable = true;
    # Use a preauthorized key from sops
    authKeyFile = config.sops.secrets.tailscale_authkey.path;
    useRoutingFeatures = "server"; # for subnet routers/exit nodes
    permitCertUid = "caddy"; # Allow Caddy to fetch Tailscale TLS certs for Funnel
  };
}

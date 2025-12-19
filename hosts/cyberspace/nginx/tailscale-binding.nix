{ config, lib, pkgs, ... }:

{
  # Restrict nginx to Tailscale interface only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}

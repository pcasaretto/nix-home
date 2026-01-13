_:

let
  certDomain = "cyberspace.tyrannosaurus-regulus.ts.net";
  certDir = "/var/lib/tailscale-certs";
in
{
  # Restrict nginx to Tailscale interface only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 443 ];

  # Configure the main virtual host with Tailscale TLS certificates
  services.nginx.virtualHosts."cyberspace" = {
    serverName = certDomain;
    onlySSL = true;
    listen = [
      { addr = "0.0.0.0"; port = 443; ssl = true; }
    ];
    sslCertificate = "${certDir}/${certDomain}.crt";
    sslCertificateKey = "${certDir}/${certDomain}.key";
  };
}

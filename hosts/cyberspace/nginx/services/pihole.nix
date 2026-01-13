{ config, ... }:

let
  inherit (config.services.cyberspace) ports;
  piholeWebPort = ports.apps.piholeWeb;  # Custom port for Pi-hole web interface
  piholeDnsPort = ports.dns.pihole;      # Standard DNS port
in
{
  # Enable OCI container runtime
  virtualisation.oci-containers = {
    backend = "podman";  # Use podman as the container runtime

    containers.pihole = {
      image = "pihole/pihole:latest";

      # Port mappings
      ports = [
        "${toString piholeDnsPort}:53/tcp"    # DNS TCP
        "${toString piholeDnsPort}:53/udp"    # DNS UDP
        "${toString piholeWebPort}:80/tcp"    # Web interface
      ];

      # Environment variables for Pi-hole configuration
      environment = {
        TZ = "America/Sao_Paulo";

        # Upstream DNS servers (Cloudflare primary, Google backup)
        PIHOLE_DNS_ = "1.1.1.1;1.0.0.1;8.8.8.8;8.8.4.4";

        # Disable authentication (Tailscale provides network security)
        # Pi-hole v6 uses FTLCONF_webserver_api_password instead of WEBPASSWORD
        # Empty string = no password required (persists across restarts)
        FTLCONF_webserver_api_password = "";
        VIRTUAL_HOST = "pihole.local";

        # Enable query logging
        QUERY_LOGGING = "true";

        # Disable IPv6 if not needed
        IPv6 = "false";

        # Set DNS listening mode to accept queries from all networks
        # This overrides the default local-service restriction
        # Options: "LOCAL" (default, one-hop only), "ALL" (all networks), "BIND" (specific interfaces)
        FTLCONF_dns_listeningMode = "ALL";
      };

      # Persistent volumes for Pi-hole data
      volumes = [
        "/var/lib/pihole/pihole:/etc/pihole"
        "/var/lib/pihole/dnsmasq.d:/etc/dnsmasq.d"
      ];

      # Automatically start on boot
      autoStart = true;

      # Additional options
      extraOptions = [
        "--cap-add=NET_ADMIN"  # Required for DHCP and network features
        "--dns=127.0.0.1"      # Use itself for DNS
        "--dns=1.1.1.1"        # Fallback DNS
      ];
    };
  };

  # Create directories for Pi-hole data with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/pihole 0755 root root -"
    "d /var/lib/pihole/pihole 0755 root root -"
    "d /var/lib/pihole/dnsmasq.d 0755 root root -"
  ];


  # Open firewall ports for DNS
  networking.firewall.allowedTCPPorts = [ piholeDnsPort ];
  networking.firewall.allowedUDPPorts = [ piholeDnsPort ];

  # Register in service registry
  services.cyberspace.registeredServices.pihole = {
    name = "Pi-hole";
    description = "Network-wide ad blocking via DNS - blocks ads and trackers";
    path = "/pihole";
    icon = "🛡️";
    enabled = true;
    port = piholeWebPort;
    tags = [ "dns" "security" "privacy" "network" ];
  };

  # Configure nginx reverse proxy for web interface
  services.nginx.virtualHosts."cyberspace" = {
    # Redirect /pihole to /pihole/admin/
    locations."/pihole" = {
      extraConfig = ''
        return 301 /pihole/admin/;
      '';
    };

    # Main Pi-hole proxy - handles all paths under /pihole/
    locations."/pihole/" = {
      proxyPass = "http://127.0.0.1:${toString piholeWebPort}/";
      extraConfig = ''
        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        # Critical: Rewrite redirects from backend
        # Converts Location: /admin/login -> Location: /pihole/admin/login
        proxy_redirect / /pihole/;

        # Handle websockets if needed
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Increase timeouts for long queries
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;

        # Enable sub_filter to rewrite HTML content if needed
        sub_filter 'href="/' 'href="/pihole/';
        sub_filter 'src="/' 'src="/pihole/';
        sub_filter 'action="/' 'action="/pihole/';
        sub_filter "window.location = '/" "window.location = '/pihole/";
        sub_filter_once off;
        sub_filter_types text/html text/css text/javascript application/javascript;
      '';
    };

    # Catch Pi-hole API requests from JavaScript (absolute paths)
    # These are made by Pi-hole's frontend JS which doesn't know about /pihole subpath
    locations."/api/" = {
      proxyPass = "http://127.0.0.1:${toString piholeWebPort}/api/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Increase timeouts
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
      '';
    };
  };
}

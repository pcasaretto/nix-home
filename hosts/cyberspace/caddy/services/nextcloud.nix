{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) domain;
in
{
  # Enable Nextcloud with automatic PostgreSQL and Redis
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = "nextcloud.${domain}";
    https = true;

    # Store data on external drive
    datadir = "/mnt/external/nextcloud";

    # Automatic database setup
    database.createLocally = true;

    # Automatic Redis caching
    configureRedis = true;

    # Admin configuration
    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
    };

    # File upload settings (memory_limit is automatically set to match)
    maxUploadSize = "16G";

    # Additional PHP performance settings (opcache)
    phpOptions = {
      "opcache.memory_consumption" = "128";
      "opcache.interned_strings_buffer" = "16";
    };
  };

  # Fix PHP-FPM pool to use caddy instead of nginx
  services.phpfpm.pools.nextcloud.settings = {
    "listen.owner" = "caddy";
    "listen.group" = "caddy";
  };

  # Ensure Nextcloud services wait for external drive
  systemd.services.phpfpm-nextcloud = {
    requires = [ "mnt-external.mount" ];
    after = [ "mnt-external.mount" ];
  };

  # Register in service registry
  services.cyberspace.registeredServices.nextcloud = {
    name = "Nextcloud";
    description = "Self-hosted file sync and share platform";
    url = "https://nextcloud.${domain}";
    icon = "☁️";
    enabled = true;
    port = null;  # Uses PHP-FPM socket
    tags = [ "productivity" "storage" "collaboration" ];
  };

  # Configure Caddy reverse proxy for PHP-FPM
  services.caddy.virtualHosts."nextcloud.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}

      root * ${config.services.nextcloud.package}

      # PHP-FPM reverse proxy
      php_fastcgi unix//run/phpfpm/nextcloud.sock {
        env front_controller_active true
        read_timeout 3600s
      }

      file_server

      # Security headers
      header {
        Strict-Transport-Security "max-age=31536000;"
        Referrer-Policy "no-referrer"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
      }

      # Request body size limit
      request_body {
        max_size 16GB
      }

      # Static asset caching
      @static {
        path *.css *.js *.svg *.gif *.png *.jpg *.ico *.woff *.woff2
      }
      header @static Cache-Control "public, max-age=15778463"

      # WebDAV/CalDAV redirects
      redir /.well-known/carddav /remote.php/dav 301
      redir /.well-known/caldav /remote.php/dav 301
    '';
  };
}

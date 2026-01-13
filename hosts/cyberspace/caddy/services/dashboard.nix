{ config, lib, pkgs, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) registeredServices;

  # Generate HTML for a single service - using url instead of path
  serviceHtml = _name: service: ''
    <li class="service-item">
      <a href="${service.url}">
        <div>
          <div class="service-name">${service.icon} ${service.name}</div>
          <div class="service-desc">${service.description}</div>
          ${if service.port != null then ''<div class="service-port">Port: ${toString service.port}</div>'' else ""}
          ${if service.tags != [] then ''<div class="service-tags">${lib.concatStringsSep " " (map (tag: "#${tag}") service.tags)}</div>'' else ""}
        </div>
        <span class="status">${if service.enabled then "Active" else "Inactive"}</span>
      </a>
    </li>
  '';

  servicesListHtml = lib.concatStrings (
    lib.mapAttrsToList serviceHtml (
      lib.filterAttrs (_name: service: service.enabled) registeredServices
    )
  );

  serviceCount = lib.length (lib.attrNames (lib.filterAttrs (_name: service: service.enabled) registeredServices));

  systemInfoPage = pkgs.writeTextFile {
    name = "system-info.html";
    text = ''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Cyberspace - System Information</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 2rem;
            color: #333;
          }
          .container { max-width: 1000px; margin: 0 auto; }
          .card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 12px;
            padding: 2rem;
            margin-bottom: 1.5rem;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
          }
          h1 { color: #667eea; margin-bottom: 1rem; font-size: 2.5rem; }
          h2 {
            color: #764ba2;
            margin-bottom: 1rem;
            font-size: 1.5rem;
            border-bottom: 2px solid #667eea;
            padding-bottom: 0.5rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .service-count {
            font-size: 0.9rem;
            font-weight: normal;
            color: #666;
            background: #f0f4ff;
            padding: 0.3rem 0.8rem;
            border-radius: 12px;
          }
          .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
            margin-top: 1rem;
          }
          .info-item {
            padding: 1rem;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #667eea;
          }
          .info-item label {
            font-weight: 600;
            color: #555;
            display: block;
            margin-bottom: 0.5rem;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
          }
          .info-item value {
            color: #333;
            font-size: 1.1rem;
            font-family: 'Courier New', monospace;
          }
          .services-list { list-style: none; }
          .service-item {
            padding: 1rem;
            margin-bottom: 0.75rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 8px;
            transition: transform 0.2s, box-shadow 0.2s;
          }
          .service-item:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
          }
          .service-item a {
            color: white;
            text-decoration: none;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-weight: 500;
          }
          .service-item .service-name { font-size: 1.1rem; margin-bottom: 0.3rem; }
          .service-item .service-desc { font-size: 0.9rem; opacity: 0.9; }
          .service-item .service-port {
            font-size: 0.8rem;
            opacity: 0.8;
            margin-top: 0.3rem;
            font-family: 'Courier New', monospace;
          }
          .service-item .service-tags {
            font-size: 0.8rem;
            opacity: 0.8;
            margin-top: 0.3rem;
            font-style: italic;
          }
          .status {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 12px;
            font-size: 0.8rem;
          }
          .footer {
            text-align: center;
            color: white;
            margin-top: 2rem;
            opacity: 0.8;
          }
          .loading { color: #666; font-style: italic; }
          .info-box {
            margin-top: 1rem;
            padding: 1rem;
            background: #f0f4ff;
            border-radius: 8px;
            border-left: 4px solid #667eea;
          }
          .info-box strong { color: #667eea; }
          .info-box p { margin-top: 0.5rem; color: #555; line-height: 1.5; }
          .info-box code {
            background: #e0e7ff;
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
          }
          .build-info { font-size: 0.85rem; color: #666; margin-top: 0.5rem; font-style: italic; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="card">
            <h1>🚀 Cyberspace</h1>
            <p>NixOS System Dashboard - Tailscale Network</p>
            <p class="build-info">Generated with NixOS - Configuration as Code</p>
          </div>

          <div class="card">
            <h2>📊 System Information</h2>
            <div class="info-grid">
              <div class="info-item">
                <label>Hostname</label>
                <value>cyberspace</value>
              </div>
              <div class="info-item">
                <label>Architecture</label>
                <value>aarch64-linux (Apple Silicon)</value>
              </div>
              <div class="info-item">
                <label>OS</label>
                <value>NixOS 25.11 (Asahi Linux)</value>
              </div>
              <div class="info-item">
                <label>User</label>
                <value>pcasaretto</value>
              </div>
              <div class="info-item">
                <label>Timezone</label>
                <value>America/Sao_Paulo</value>
              </div>
              <div class="info-item">
                <label>Tailscale</label>
                <value id="tailscale-ip" class="loading">Loading...</value>
              </div>
            </div>

            <div id="dynamic-info" style="margin-top: 1.5rem;">
              <div class="info-item">
                <label>Uptime</label>
                <value id="uptime" class="loading">Loading...</value>
              </div>
            </div>
          </div>

          <div class="card">
            <h2>
              <span>🔧 Available Services</span>
              <span class="service-count">${toString serviceCount} active</span>
            </h2>
            <ul class="services-list">
              ${servicesListHtml}
            </ul>
            <div class="info-box">
              <strong>💡 Subdomain Routing:</strong>
              <p>
                All services are accessible via subdomains:
              </p>
              <ul style="margin-left: 1.5rem; margin-top: 0.5rem; line-height: 1.8;">
                <li><code>grafana.${domain}</code></li>
                <li><code>sonarr.${domain}</code></li>
                <li><code>jellyfin.${domain}</code></li>
                <li>etc.</li>
              </ul>
              <p style="margin-top: 0.5rem;">
                Powered by Caddy with Let's Encrypt wildcard certificates via Cloudflare DNS.
              </p>
            </div>
          </div>

          <div class="footer">
            <p>Powered by NixOS + Caddy + Tailscale + Cloudflare</p>
            <p style="margin-top: 0.5rem; font-size: 0.9rem;">
              Config: <code>/home/pcasaretto/src/github.com/pcasaretto/nix-home</code>
            </p>
          </div>
        </div>

        <script>
          async function updateSystemInfo() {
            try {
              const response = await fetch('/api/system-info');
              if (response.ok) {
                const data = await response.json();
                document.getElementById('tailscale-ip').textContent = data.tailscale_ip || 'N/A';
                document.getElementById('uptime').textContent = data.uptime || 'N/A';
              } else {
                document.getElementById('tailscale-ip').textContent = 'Use: tailscale ip -4';
                document.getElementById('uptime').textContent = 'N/A';
              }
            } catch (error) {
              document.getElementById('tailscale-ip').textContent = 'Use: tailscale ip -4';
              document.getElementById('uptime').textContent = 'N/A';
            }
            document.getElementById('tailscale-ip').classList.remove('loading');
            document.getElementById('uptime').classList.remove('loading');
          }
          updateSystemInfo();
          setInterval(updateSystemInfo, 30000);
        </script>
      </body>
      </html>
    '';
  };

  webRoot = pkgs.runCommand "cyberspace-webroot" {} ''
    mkdir -p $out
    cp ${systemInfoPage} $out/index.html
  '';
in
{
  # Register the system dashboard
  services.cyberspace.registeredServices.dashboard = {
    name = "System Dashboard";
    description = "System information and service directory";
    url = "https://dashboard.${domain}";
    icon = "🚀";
    enabled = true;
    tags = ["system" "monitoring"];
  };

  # Configure Caddy to serve the dashboard
  services.caddy.virtualHosts."dashboard.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      root * ${webRoot}
      file_server

      # API endpoint placeholder
      handle /api/system-info {
        respond "Not implemented" 404
      }
    '';
  };
}

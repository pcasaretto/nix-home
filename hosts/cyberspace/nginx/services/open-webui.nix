{ config, pkgs, ... }:

let
  ollamaConfig = config.services.ollama;
  openWebUIPort = 8080;
  openWebUIPath = config.services.cyberspace.registeredServices.open-webui.path;
in
{
  # Create systemd service for Open WebUI
  systemd.services.open-webui = {
    description = "Open WebUI - Web Interface for Ollama";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "ollama.service" ];
    wants = [ "ollama.service" ];

    environment = {
      # Point to local ollama instance (uses actual ollama config)
      OLLAMA_BASE_URL = "http://${ollamaConfig.host}:${toString ollamaConfig.port}";
      # Data directory for storing conversations, settings, etc.
      DATA_DIR = "/var/lib/open-webui";
      # Port to listen on
      PORT = toString openWebUIPort;
      # Disable analytics
      ANONYMIZED_TELEMETRY = "False";
      # Listen on localhost only - nginx will proxy
      HOST = "127.0.0.1";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.open-webui}/bin/open-webui serve";
      WorkingDirectory = "/var/lib/open-webui";
      StateDirectory = "open-webui";
      Restart = "always";
      RestartSec = "10s";

      # Security hardening
      User = "open-webui";
      Group = "open-webui";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/open-webui" ];
    };
  };

  # Tailscale service configuration file
  environment.etc."tailscale/openwebui-service.json" = {
    text = builtins.toJSON {
      version = "0.0.1";
      services = {
        "svc:openwebui" = {
          endpoints = {
            "https:443" = "http://localhost:80";
          };
        };
      };
    };
  };

  # Configure Tailscale serve for the openwebui service
  systemd.services.tailscale-serve-openwebui = {
    description = "Tailscale Serve - Open WebUI Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" "nginx.service" ];
    wants = [ "nginx.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --service=svc:openwebui --http=80 127.0.0.1:${toString openWebUIPort}";
    };
  };

  # Create user for the service
  users.users.open-webui = {
    isSystemUser = true;
    group = "open-webui";
    home = "/var/lib/open-webui";
    createHome = true;
    description = "Open WebUI service user";
  };

  users.groups.open-webui = {};

  # Register in service registry
  services.cyberspace.registeredServices.open-webui = {
    name = "Open WebUI";
    description = "Chat interface for Ollama LLMs with conversation history";
    path = "http://openwebui";  # Tailscale service endpoint
    icon = "💬";
    enabled = true;
    port = openWebUIPort;
    tags = [ "ai" "chat" "ui" "llm" "tailscale-service" ];
  };

  # Configure nginx reverse proxy on Tailscale service endpoint
  services.nginx.virtualHosts."openwebui" = {
    serverAliases = [ "openwebui.${config.networking.hostName}.ts.net" ];

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString openWebUIPort}";
      extraConfig = ''
        # Proxy headers - required for uvicorn
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        # WebSocket support - critical for Open WebUI
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        # Timeouts for long-running LLM requests
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;

        # Buffering settings for streaming responses
        proxy_buffering off;
        proxy_cache off;
        proxy_request_buffering off;

        # File upload support
        client_max_body_size 100M;
      '';
    };
  };
}

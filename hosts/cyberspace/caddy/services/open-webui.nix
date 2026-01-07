{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
  ollamaConfig = config.services.ollama;
  openWebUIPort = ports.apps.openWebUI;
in
{
  # Create systemd service for Open WebUI
  systemd.services.open-webui = {
    description = "Open WebUI - Web Interface for Ollama";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "ollama.service" ];
    wants = [ "ollama.service" ];

    environment = {
      OLLAMA_BASE_URL = "http://${ollamaConfig.host}:${toString ollamaConfig.port}";
      DATA_DIR = "/var/lib/open-webui";
      PORT = toString openWebUIPort;
      ANONYMIZED_TELEMETRY = "False";
      HOST = "127.0.0.1";
      WEBUI_AUTH = "False";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.open-webui}/bin/open-webui serve";
      WorkingDirectory = "/var/lib/open-webui";
      StateDirectory = "open-webui";
      Restart = "always";
      RestartSec = "10s";

      User = "open-webui";
      Group = "open-webui";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/open-webui" ];
    };
  };

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
    url = "https://openwebui.${domain}";
    icon = "💬";
    enabled = true;
    port = openWebUIPort;
    tags = [ "ai" "chat" "ui" "llm" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."openwebui.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString openWebUIPort} {
        # Streaming support for LLM responses
        flush_interval -1

        # Extended timeouts for long-running LLM requests
        transport http {
          read_timeout 300s
        }
      }

      # File upload support
      request_body {
        max_size 100MB
      }
    '';
  };
}

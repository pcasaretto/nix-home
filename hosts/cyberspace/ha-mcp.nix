{
  config,
  pkgs,
  ...
}: let
  ports = config.services.cyberspace.ports;
  haMcpPort = ports.ai.haMcp;
  tunnelHealthPort = ports.ai.openaiMcpTunnelHealth;
  haMcpUrl = "http://127.0.0.1:${toString haMcpPort}/mcp";
in {
  # Render secret-backed environment files at activation time. The placeholders
  # are substituted by sops-nix without putting secret values in the Nix store.
  sops.templates.ha-mcp-env = {
    content = ''
      HOMEASSISTANT_TOKEN=${config.sops.placeholder."home-assistant-mcp-token"}
    '';
    mode = "0400";
  };

  sops.templates.openai-mcp-tunnel-env = {
    content = ''
      CONTROL_PLANE_API_KEY=${config.sops.placeholder."openai-mcp-tunnel-api-key"}
      CONTROL_PLANE_TUNNEL_ID=${config.sops.placeholder."openai-mcp-tunnel-id"}
    '';
    mode = "0400";
  };

  # ha-mcp runs as a private, localhost-only MCP HTTP server. It is intentionally
  # not exposed through Caddy; OpenAI tunnel-client is the only intended remote path.
  virtualisation.oci-containers.containers.ha-mcp = {
    image = "ghcr.io/homeassistant-ai/ha-mcp:7.9.0";
    pull = "missing";
    cmd = ["ha-mcp-web"];
    environmentFiles = [config.sops.templates.ha-mcp-env.path];
    environment = {
      HOMEASSISTANT_URL = "http://127.0.0.1:${toString ports.smartHome.homeAssistant}";
      MCP_HOST = "127.0.0.1";
      MCP_PORT = toString haMcpPort;
      MCP_SECRET_PATH = "/mcp";
      BACKUP_HINT = "normal";
      ENABLE_TOOL_SEARCH = "true";
      TOOL_SEARCH_MAX_RESULTS = "5";
      LOG_LEVEL = "INFO";
    };
    extraOptions = [
      "--network=host"
      "--restart=no"
    ];
  };

  systemd.services.podman-ha-mcp = {
    after = ["home-assistant.service"];
    wants = ["home-assistant.service"];
  };

  # OpenAI Secure MCP Tunnel: outbound-only bridge from OpenAI to the private
  # ha-mcp localhost endpoint.
  systemd.services.openai-mcp-tunnel = {
    description = "OpenAI Secure MCP Tunnel for Home Assistant MCP";
    wantedBy = ["multi-user.target"];
    after = ["podman-ha-mcp.service" "network-online.target"];
    wants = ["podman-ha-mcp.service" "network-online.target"];

    environment = {
      HEALTH_LISTEN_ADDR = "127.0.0.1:${toString tunnelHealthPort}";
      LOG_LEVEL = "info";
    };

    script = ''
      exec ${pkgs.openai-tunnel-client}/bin/tunnel-client run \
        --control-plane.api-key env:CONTROL_PLANE_API_KEY \
        --mcp.server-url url=${haMcpUrl},channel=main \
        --health.listen-addr 127.0.0.1:${toString tunnelHealthPort}
    '';

    serviceConfig = {
      Type = "simple";
      EnvironmentFile = config.sops.templates.openai-mcp-tunnel-env.path;
      Restart = "always";
      RestartSec = "10s";
      DynamicUser = true;
      StateDirectory = "openai-mcp-tunnel";
      WorkingDirectory = "/var/lib/openai-mcp-tunnel";

      # Hardening: this process only needs outbound HTTPS and localhost access.
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service" "~@privileged"];
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    };
  };
}

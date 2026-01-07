{ config, pkgs, ... }:

let
  domain = config.services.cyberspace.domain;
  ports = config.services.cyberspace.ports;
in
{
  # Enable ollama service
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = ports.ai.ollama;
    acceleration = "vulkan";
  };

  # Register in service registry
  services.cyberspace.registeredServices.ollama = {
    name = "Ollama";
    description = "Local AI model serving platform for running LLMs";
    url = "https://ollama.${domain}";
    icon = "🤖";
    enabled = true;
    port = ports.ai.ollama;
    tags = [ "ai" "llm" "ml" ];
  };

  # Configure Caddy reverse proxy with streaming support
  services.caddy.virtualHosts."ollama.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.ai.ollama} {
        # Streaming support for model generation
        flush_interval -1

        # Extended timeouts for long-running requests
        transport http {
          read_timeout 300s
        }
      }
    '';
  };
}

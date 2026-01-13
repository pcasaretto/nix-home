{ config, ... }:

let
  inherit (config.services.cyberspace) ports;
in
{
  # Enable ollama service
  services.ollama = {
    enable = true;
    # Ollama runs on localhost:11434 by default
    host = "127.0.0.1";
    port = ports.ai.ollama;
    # Use Vulkan acceleration for Apple Silicon
    acceleration = "vulkan";
    # Models can be pulled through Open WebUI interface or manually with: ollama pull <model>
  };

  # Register in service registry
  services.cyberspace.registeredServices.ollama = {
    name = "Ollama";
    description = "Local AI model serving platform for running LLMs";
    path = "/ollama";
    icon = "🤖";
    enabled = true;
    port = ports.ai.ollama;
    tags = [ "ai" "llm" "ml" ];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/ollama/" = {
      proxyPass = "http://127.0.0.1:${toString ports.ai.ollama}/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Ollama can have long-running requests for model generation
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;

        # Enable streaming responses
        proxy_buffering off;
        proxy_cache off;

        # WebSocket support for interactive sessions
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };
}

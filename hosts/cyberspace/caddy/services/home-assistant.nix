{ config, lib, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
in
{
  # Option to enable Prometheus metrics scraping
  # Set to true after generating a Long-Lived Access Token from Home Assistant UI
  options.services.cyberspace.homeAssistant.enableMetrics = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable Prometheus metrics scraping for Home Assistant.
      Requires a Long-Lived Access Token to be configured in sops secrets.
      Generate from Home Assistant UI: Profile -> Security -> Long-Lived Access Tokens
    '';
  };

  config = {
    # Enable Prometheus metrics scraping
    services.cyberspace.homeAssistant.enableMetrics = true;

    # Enable Home Assistant service
    services.home-assistant = {
      enable = true;
      extraComponents = [
        # Required for onboarding
        "analytics"
        "google_translate"
        "met"
        "radio_browser"
        "shopping_list"
        # Prometheus metrics
        "prometheus"
        # AI integrations
        "ollama"
        "openai_conversation"
        # Voice integrations
        "piper"
        "whisper"
        "wyoming"
        # Alexa integration
        "alexa"
        # Common integrations
        "default_config"
      ];

      config = {
        # Basic configuration
        homeassistant = {
          name = "Home";
          unit_system = "metric";
          time_zone = config.time.timeZone;
          # Allow Caddy reverse proxy
          external_url = "https://homeassistant.${domain}";
          internal_url = "http://127.0.0.1:${toString ports.smartHome.homeAssistant}";
        };

        # HTTP configuration
        http = {
          server_port = ports.smartHome.homeAssistant;
          server_host = "127.0.0.1";
          use_x_forwarded_for = true;
          trusted_proxies = [ "127.0.0.1" "::1" ];
        };

        # Enable Prometheus metrics endpoint at /api/prometheus
        prometheus = { };

        # Default integrations
        default_config = { };
      };
    };

    # Register in service registry for dashboard
    services.cyberspace.registeredServices.home-assistant = {
      name = "Home Assistant";
      description = "Open source home automation platform";
      url = "https://homeassistant.${domain}";
      icon = "🏠";
      enabled = true;
      port = ports.smartHome.homeAssistant;
      tags = [ "automation" "iot" "smart-home" ];
    };

    # Wyoming Piper - Text-to-Speech (Brazilian Portuguese)
    services.wyoming.piper.servers.home = {
      enable = true;
      uri = "tcp://0.0.0.0:${toString ports.smartHome.wyomingPiper}";
      voice = "pt_BR-faber-medium";
    };

    # Wyoming Faster Whisper - Speech-to-Text (Portuguese)
    services.wyoming.faster-whisper.servers.home = {
      enable = true;
      uri = "tcp://0.0.0.0:${toString ports.smartHome.wyomingWhisper}";
      model = "medium";  # Multilingual model (not .en)
      language = "pt";
    };

    # Wyoming OpenWakeWord - Wake Word Detection
    # NOTE: Disabled due to build issue in nixpkgs (pyopen-wakeword segfault)
    # services.wyoming.openwakeword = {
    #   enable = true;
    #   uri = "tcp://0.0.0.0:${toString ports.smartHome.wyomingOpenWakeWord}";
    # };

    # Configure Caddy reverse proxy with WebSocket support
    services.caddy.virtualHosts."homeassistant.${domain}" = {
      extraConfig = ''
        ${config.services.cyberspace.tlsConfig}
        reverse_proxy http://127.0.0.1:${toString ports.smartHome.homeAssistant} {
          # WebSocket support for real-time updates
          flush_interval -1

          # Extended timeouts for long-polling and streaming
          transport http {
            read_timeout 0
            write_timeout 0
          }
        }
      '';
    };
  };
}

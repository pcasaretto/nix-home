{ lib, ... }:

{
  options.services.cyberspace.ports = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # DNS and Network Services (50-99)
        dns = {
          pihole = lib.mkOption {
            type = lib.types.int;
            default = 53;
            description = "Pi-hole DNS service port";
          };
        };

        # Frontend/UI Services (3000-3999)
        frontend = {
          grafana = lib.mkOption {
            type = lib.types.int;
            default = 3000;
            description = "Grafana web interface port";
          };
        };

        # Media Management Services (7000-7999, 8000-8999, 9000-9999)
        media = {
          radarr = lib.mkOption {
            type = lib.types.int;
            default = 7878;
            description = "Radarr movie management service port";
          };

          sonarr = lib.mkOption {
            type = lib.types.int;
            default = 8989;
            description = "Sonarr TV show management service port";
          };

          prowlarr = lib.mkOption {
            type = lib.types.int;
            default = 9696;
            description = "Prowlarr indexer manager service port";
          };

          jellyfin = lib.mkOption {
            type = lib.types.int;
            default = 8096;
            description = "Jellyfin media server port";
          };
        };

        # Application Services (8000-8999, 9000-9999)
        apps = {
          piholeWeb = lib.mkOption {
            type = lib.types.int;
            default = 8053;
            description = "Pi-hole web interface port";
          };

          transmission = lib.mkOption {
            type = lib.types.int;
            default = 9091;
            description = "Transmission RPC/web interface port";
          };

          openWebUI = lib.mkOption {
            type = lib.types.int;
            default = 8080;
            description = "Open WebUI interface port";
          };

          ntfy = lib.mkOption {
            type = lib.types.int;
            default = 2586;
            description = "ntfy notification service HTTP port";
          };
        };

        # Core Monitoring Services (9000-9099)
        monitoring = {
          prometheus = lib.mkOption {
            type = lib.types.int;
            default = 9090;
            description = "Prometheus metrics server port";
          };
        };

        # System Exporters (9100-9199)
        exporters = {
          node = lib.mkOption {
            type = lib.types.int;
            default = 9100;
            description = "Node exporter port for system metrics";
          };
        };

        # Application Exporters (9700-9799)
        appExporters = {
          sonarr = lib.mkOption {
            type = lib.types.int;
            default = 9707;
            description = "Sonarr exporter port";
          };

          radarr = lib.mkOption {
            type = lib.types.int;
            default = 9708;
            description = "Radarr exporter port";
          };

          prowlarr = lib.mkOption {
            type = lib.types.int;
            default = 9710;
            description = "Prowlarr exporter port";
          };

          transmission = lib.mkOption {
            type = lib.types.int;
            default = 9711;
            description = "Transmission exporter port";
          };

          ntfy = lib.mkOption {
            type = lib.types.int;
            default = 9713;
            description = "ntfy metrics exporter port";
          };

          nextcloud = lib.mkOption {
            type = lib.types.int;
            default = 9714;
            description = "Nextcloud exporter port";
          };
        };

        # Smart Home / IoT Services (10000-10999)
        smartHome = {
          homeAssistant = lib.mkOption {
            type = lib.types.int;
            default = 10123;
            description = "Home Assistant home automation platform port";
          };
          wyomingPiper = lib.mkOption {
            type = lib.types.int;
            default = 10200;
            description = "Wyoming Piper TTS service port";
          };
          wyomingWhisper = lib.mkOption {
            type = lib.types.int;
            default = 10300;
            description = "Wyoming Faster Whisper STT service port";
          };
          wyomingOpenWakeWord = lib.mkOption {
            type = lib.types.int;
            default = 10400;
            description = "Wyoming OpenWakeWord detection service port";
          };
        };

        # AI/ML Services (11000-11999)
        ai = {
          ollama = lib.mkOption {
            type = lib.types.int;
            default = 11434;
            description = "Ollama AI model serving port";
          };
        };

        # P2P and Peer Ports (51000-51999)
        p2p = {
          transmissionPeer = lib.mkOption {
            type = lib.types.int;
            default = 51413;
            description = "Transmission BitTorrent peer port";
          };
        };
      };
    };
    default = {};
    description = ''
      Centralized port allocation for all cyberspace services.

      Port allocation scheme (preserving existing allocations):
      - 50-99: DNS and network services
      - 3000-3999: Frontend/UI services
      - 7000-9999: Application services (media management, downloads, etc)
      - 9000-9099: Core monitoring services
      - 9100-9199: System/infrastructure exporters
      - 9700-9799: Application exporters
      - 10000-10999: Smart home / IoT services
      - 11000-11999: AI/ML services
      - 51000-51999: P2P and peer ports
    '';
  };
}

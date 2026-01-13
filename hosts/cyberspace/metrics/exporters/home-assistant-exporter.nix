{ config, lib, ... }:

let
  inherit (config.services.cyberspace) ports;
  metricsEnabled = config.services.cyberspace.homeAssistant.enableMetrics;
in
{
  # Home Assistant has a built-in Prometheus endpoint at /api/prometheus
  # This endpoint requires bearer token authentication (Long-Lived Access Token)
  # The token must be generated from the Home Assistant UI after initial setup:
  # Profile -> Security -> Long-Lived Access Tokens -> Create Token

  config = lib.mkIf metricsEnabled {
    # Disable config check since credentials_file doesn't exist at build time
    # (sops-nix creates it at runtime)
    services.prometheus.checkConfig = "syntax-only";

    # Add custom scrape config with authorization
    # (Can't use metrics registry since it doesn't support auth headers)
    services.prometheus.scrapeConfigs = [
      {
        job_name = "home-assistant";
        scrape_interval = "30s";
        metrics_path = "/api/prometheus";
        authorization = {
          type = "Bearer";
          credentials_file = config.sops.secrets.home-assistant-token.path;
        };
        static_configs = [{
          targets = [ "localhost:${toString ports.smartHome.homeAssistant}" ];
          labels = {
            instance = "cyberspace";
            service = "home-assistant";
          };
        }];
      }
    ];

  };
}

{ lib, ... }:

with lib;

{
  options.services.cyberspace.metrics = {
    # Metrics registry for automatic Prometheus scrape configuration
    registeredMetrics = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          job_name = mkOption {
            type = types.str;
            description = "Prometheus job name for this metrics source";
          };

          description = mkOption {
            type = types.str;
            description = "Human-readable description of what metrics this provides";
          };

          scrape_interval = mkOption {
            type = types.str;
            default = "15s";
            description = "How often to scrape this endpoint";
          };

          targets = mkOption {
            type = types.listOf types.str;
            description = "List of host:port targets to scrape";
            example = [ "localhost:9100" ];
          };

          labels = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Static labels to add to all metrics from this job";
          };

          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Whether this metrics source is active";
          };

          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tags for categorizing metrics (system, application, etc)";
          };
        };
      });
      default = {};
      description = "Registry of metrics endpoints available on this system";
    };
  };

  config = {
    # No default registrations here - exporters will register themselves
  };
}

{ config, lib, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
in
{
  services.loki = {
    enable = true;

    configuration = {
      # Disable auth for single-tenant homelab
      auth_enabled = false;

      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = ports.monitoring.loki;
        grpc_listen_port = 9096;
        log_level = "info";
      };

      # Common configuration
      common = {
        instance_addr = "127.0.0.1";
        path_prefix = "/var/lib/loki";
        storage = {
          filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
        };
        replication_factor = 1;
        ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };

      # Modern TSDB schema (required for Loki 3.x)
      schema_config = {
        configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      # Storage configuration for TSDB
      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };
      };

      # Query performance tuning
      query_range = {
        results_cache = {
          cache = {
            embedded_cache = {
              enabled = true;
              max_size_mb = 100;
            };
          };
        };
      };

      # Compactor for TSDB (required for good performance)
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        compaction_interval = "10m";
      };

      # Limits configuration
      limits_config = {
        retention_period = "720h"; # 30 days
        reject_old_samples = true;
        reject_old_samples_max_age = "168h"; # 7 days
        ingestion_rate_mb = 10;
        ingestion_burst_size_mb = 20;
        max_query_length = "721h"; # Slightly more than retention for queries
      };
    };
  };

  # Ensure proper startup order
  systemd.services.loki = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}

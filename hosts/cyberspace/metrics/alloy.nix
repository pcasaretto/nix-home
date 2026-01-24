{ config, lib, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
  lokiUrl = "http://127.0.0.1:${toString ports.monitoring.loki}";

  # Alloy configuration in River format
  alloyConfig = pkgs.writeText "alloy-config.river" ''
    // Loki write endpoint
    loki.write "local" {
      endpoint {
        url = "${lokiUrl}/loki/api/v1/push"
      }
      external_labels = {
        host        = "cyberspace",
        environment = "homelab",
      }
    }

    // Systemd journal log source
    loki.source.journal "systemd" {
      format_as_json = true
      max_age        = "12h"
      labels         = {
        job = "systemd-journal",
      }

      forward_to = [loki.relabel.journal.receiver]
    }

    // Relabel journal entries to extract useful labels
    loki.relabel "journal" {
      forward_to = [loki.write.local.receiver]

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal__hostname"]
        target_label  = "hostname"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }

      rule {
        source_labels = ["__journal__transport"]
        target_label  = "transport"
      }
    }

    // File-based log scraping from /var/log/
    loki.source.file "varlog" {
      targets = [
        {__path__ = "/var/log/*.log", job = "varlogs"},
        {__path__ = "/var/log/messages", job = "syslog"},
      ]
      forward_to = [loki.write.local.receiver]
    }

    // Container logs (for future Docker/Podman support)
    // Uncomment when containers are added
    // loki.source.docker "containers" {
    //   host       = "unix:///var/run/docker.sock"
    //   targets    = []
    //   forward_to = [loki.relabel.docker.receiver]
    // }
    //
    // loki.relabel "docker" {
    //   forward_to = [loki.write.local.receiver]
    //
    //   rule {
    //     source_labels = ["__meta_docker_container_name"]
    //     target_label  = "container"
    //   }
    // }
  '';
in
{
  services.alloy = {
    enable = true;
    extraFlags = [
      "--storage.path=/var/lib/alloy"
      "--server.http.listen-addr=127.0.0.1:${toString ports.monitoring.alloy}"
      "--stability.level=public-preview"
    ];
  };

  # Override the default configuration to use our River config
  systemd.services.alloy = {
    serviceConfig = {
      ExecStart = lib.mkForce ''
        ${pkgs.grafana-alloy}/bin/alloy run \
          --storage.path=/var/lib/alloy \
          --server.http.listen-addr=127.0.0.1:${toString ports.monitoring.alloy} \
          --stability.level=public-preview \
          ${alloyConfig}
      '';
      # Ensure alloy can read journal and log files
      SupplementaryGroups = [ "systemd-journal" ];
      ReadOnlyPaths = [ "/var/log" ];
    };
    after = [ "loki.service" "network-online.target" ];
    wants = [ "loki.service" "network-online.target" ];
    requires = [ "loki.service" ];
  };

  # Create storage directory
  systemd.tmpfiles.rules = [
    "d /var/lib/alloy 0755 alloy alloy -"
  ];
}

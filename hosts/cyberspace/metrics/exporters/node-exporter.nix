{ config, lib, pkgs, ... }:

let
  nodeExporterPort = 9100;
in
{
  # Enable node_exporter with comprehensive collectors
  services.prometheus.exporters.node = {
    enable = true;
    port = nodeExporterPort;

    # Listen on localhost only
    listenAddress = "127.0.0.1";

    # Enable additional collectors for detailed system metrics
    enabledCollectors = [
      "systemd"        # Systemd service metrics
      "processes"      # Process statistics
      "interrupts"     # Interrupt statistics
      "tcpstat"        # TCP connection statistics
      "wifi"           # WiFi statistics (for laptop)
    ];

    # Disable collectors that may not be relevant
    disabledCollectors = [
      "arp"
      "bonding"
      "infiniband"
    ];

    # Extra flags for fine-tuning collectors
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
      "--collector.netclass.ignored-devices=^(veth.*|br.*|docker.*|virbr.*|lo)$$"
      "--collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo)$$"
    ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.node-exporter = {
    job_name = "node";
    description = "System-level metrics (CPU, memory, disk, network) from node_exporter";
    scrape_interval = "15s";
    targets = [ "localhost:${toString nodeExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "node";
    };
    enabled = true;
    tags = [ "system" "hardware" "performance" ];
  };
}

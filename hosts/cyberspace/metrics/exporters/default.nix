{ ... }:

{
  imports = [
    ./node-exporter.nix
    ./nginx-exporter.nix
    # Future exporters can be added here:
    # ./ollama-exporter.nix
  ];
}

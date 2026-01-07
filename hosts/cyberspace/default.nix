# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    # ./hardware-configuration.nix

    # `home-manager` module
    inputs.home-manager.nixosModules.home-manager

    # sops-nix for secrets management
    inputs.sops-nix.nixosModules.sops

    inputs.nixos-apple-silicon.nixosModules.apple-silicon-support

    # Centralized port allocation
    ./ports.nix

    # Service registry for dashboard
    ./service-registry.nix

    # ./apple-silicon-support
    ./hardware-configuration.nix
    ./mosh.nix
    ./networking.nix
    ./openssh.nix
    ./sops.nix
    ./tailscale.nix
    ./hyprland.nix
    # Caddy replaces nginx - auto-manages Tailscale TLS certs
    ./caddy
    ./metrics
    ./external-drive.nix
    # No longer needed - Caddy handles TLS certs automatically:
    # ./tailscale-certs.nix
  ];

  # hardware.asahi.peripheralFirmwareDirectory = pkgs.requireFile {
  #   name = "asahi";
  #   hashMode = "recursive";
  #   hash = "sha256-Ib4xHM1gK01mu9/ievdpASpmqnN//2W05N/a3c69t0w=";
  #   message = ''
  #     nix-store --add-fixed sha256 --recursive /boot/asahi
  #   '';
  # };

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      # Import your home-manager configuration
      "pcasaretto" = import ./home-manager;
    };
  };

  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  environment.systemPackages =
    with pkgs;
    [
      # Core utilities
      git
      distrobox
      curl
      wget
      htop
      tree
      file
      which
      rsync
      lsof
      iotop
      sysz
      dust
      mprocs
      pv
      killall

      # System tools
      vim
      nano
      pciutils
      usbutils
      bind.dnsutils
      nmap
      traceroute
      iperf3
      # Desktop-specific packages
      pavucontrol
      wireplumber
      v4l-utils
      cheese
      pipewire
      bluez
      bluez-tools
      pcsclite
      libfido2
      iw
      wirelesstools

      pkgs.unstable.beads
      pkgs.unstable.claude-code
    ];

  # Deduplicate and optimize nix store
  # nix.optimise.automatic = true;
  nix.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Bluetooth configuration
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;

  # Game controller udev rules (including Switch Pro Controller)
  services.udev.packages = [
    pkgs.gamecontroller-udev-rules
  ];

  virtualisation.docker = {
    enable = true;
  };

# Optional: Add your user to the "docker" group to run docker without sudo

  # Prevent logind from suspending on lid close; Hyprland handles DPMS + lock instead
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # Auto-login on an alternate VT so the user session (services) starts at boot
  services.getty.autologinUser = "pcasaretto";
  systemd.services."getty@tty2".enable = true;
  systemd.services."getty@tty2".wantedBy = ["multi-user.target"];

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  users.users.pcasaretto = {
    isNormalUser = true;
    home = "/home/pcasaretto";
    extraGroups = ["docker" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC5IzKxcJzMplMhh+j5bcY6eAIz9PsQ0t7PpusMslJ2F pcasaretto Nix SSH Key"
    ];
    description = "Paulo Casaretto";
    shell = pkgs.zsh;
    linger = true;
    hashedPasswordFile = config.sops.secrets.pcasaretto-password-hash.path;
  };

  time.timeZone = "America/Sao_Paulo";
  
  environment.enableAllTerminfo = true;

  system.stateVersion = "25.11";
}

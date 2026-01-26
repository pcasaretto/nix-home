{
	inputs,
		pkgs,
		...
}: {
	programs.hyprland = {
		enable = true;
		withUWSM = true;  # Proper systemd integration
# set the flake package
		package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
# portal package in sync
		portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
	};
    hardware.graphics = {
      package = pkgs.unstable.mesa;
    };

    programs = {
      xwayland.enable = true;
      dconf.enable = true;
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --cmd 'uwsm start hyprland-uwsm.desktop'";
          user = "greeter";
        };
      };
    };

    services = {
      dbus.enable = true;
      gnome.gnome-keyring.enable = true;
      power-profiles-daemon.enable = true;
      pipewire = {
        enable = true;
        alsa.enable = true;
        # Note: alsa.support32Bit doesn't work on ARM64
        pulse.enable = true;
        extraConfig.pipewire."92-low-latency" = {
          "context.properties" = {
            "default.clock.allowed-rates" = [ 48000 ];
            "default.clock.quantum" = 2048;
            "default.clock.min-quantum" = 1024;
          };
        };
      };
    };

    # PAM configuration for hyprlock
    security.pam.services.hyprlock = {
      text = ''
        auth sufficient pam_fprintd.so
        auth include login
      '';
    };
}

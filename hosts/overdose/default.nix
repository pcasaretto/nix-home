{ pkgs, lib, programs, ... }:
{
  home-manager.users.pcasaretto = {
    imports = [
      ./home.nix
      ./git.nix
      ./kitty.nix
      ./tmux.nix
      ./zsh.nix
    ];
  };

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # https://github.com/nix-community/home-manager/issues/4026
  users.users.pcasaretto.home = "/Users/pcasaretto";

  system.defaults = {
    # Finder preferences
    finder = {
      FXPreferredViewStyle = "Nlsv";
      AppleShowAllFiles = true;
      AppleShowAllExtensions = true;
    };
    NSGlobalDomain = {
      # do not use press and hold for special characters
      ApplePressAndHoldEnabled = false;
    };

    trackpad.Clicking = true;
    trackpad.TrackpadThreeFingerDrag = true;
  };

}

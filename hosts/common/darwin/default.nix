{ inputs, ... }:
{
  imports = [
  ];
  # Keyboard

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

  # use TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

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
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
    };

    trackpad.Clicking = true;
    trackpad.TrackpadThreeFingerDrag = true;

    dock = {
      autohide = true;
      show-recents = false;
    };
  };
}

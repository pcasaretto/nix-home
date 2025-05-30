{ inputs, ... }:
{
  imports = [
  ];
  # Keyboard

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

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

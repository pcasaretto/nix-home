{inputs, ...}: {
  imports = [
  ];

  services.macos-remap-keys = {
    enable = true;
    keyboard.Capslock = "Control";
  };

  targets.darwin.defaults = {
    # Finder preferences
    "com.apple.finder" = {
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

    "com.apple.AppleMultitouchTrackpad" = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };

    "com.apple.dock" = {
      autohide = true;
      show-recents = false;
    };
  };
}

# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });

    # Fix zsh SIGCHLD race on darwin with autoconf 2.73 / C23.
    # The K&R handler in the sigsuspend probe fails to compile under -std=gnu23,
    # causing zsh to use a racy pause() fallback that hangs on $(...) reaping.
    # https://github.com/NixOS/nixpkgs/issues/513543
    # Remove once nixpkgs-unstable includes PR #513971.
    zsh = prev.zsh.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        # Fix K&R handler prototype for C23 compatibility in sigsuspend probe
        sed -i '/void handler(sig)/{N;s/void handler(sig)\n    int sig;/void handler(int sig)/;}' configure.ac
      '';
    });

    pcasaretto = import inputs.nixpkgs-pcasaretto {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # Add access to x86 packages when system is running Apple Silicon
  apple-silicon = final: prev:
    inputs.nixpkgs.lib.optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
      pkgs-x86 = import inputs.nixpkgs-unstable {
        system = "x86_64-darwin";
      };
    };

}

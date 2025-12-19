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

    pcasaretto = import inputs.nixpkgs-pcasaretto {
<<<<<<< HEAD
      system = final.stdenv.hostPlatform.system;
=======
      inherit (final) system;
>>>>>>> f3374a3 (we have liftoff)
      config.allowUnfree = true;
    };
  };

  # Add nu_plugin_dns to nushellPlugins (built with unstable for Rust compatibility)
  nushell-plugins = final: prev: let
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
    };
  in {
    nushellPlugins =
      prev.nushellPlugins
      // {
        dns = unstable.callPackage ../pkgs/nu_plugin_dns {};
      };
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
<<<<<<< HEAD
      system = final.stdenv.hostPlatform.system;
=======
      inherit (final) system;
>>>>>>> f3374a3 (we have liftoff)
      config.allowUnfree = true;
    };
  };

  # Add access to x86 packages when system is running Apple Silicon
  apple-silicon = final: prev:
    inputs.nixpkgs-darwin.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
      pkgs-x86 = import inputs.nixpkgs-unstable {
        system = "x86_64-darwin";
      };
    };
<<<<<<< HEAD
=======

  # Add tmux-git-worktree plugin to tmuxPlugins
  tmux-git-worktree = final: prev: {
    tmuxPlugins =
      prev.tmuxPlugins
      // {
        git-worktree = inputs.tmux-git-worktree.packages.${final.system}.default;
      };
  };
>>>>>>> f3374a3 (we have liftoff)
}

# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {
    pkgs = final;
    inherit (final) callPackage;
  };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: _prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # Add access to x86 packages when system is running Apple Silicon
  apple-silicon = _final: prev:
    inputs.nixpkgs-darwin.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
      pkgs-x86 = import inputs.nixpkgs-unstable {
        system = "x86_64-darwin";
      };
    };

  # Spellbook D&D 5e spell reference SPA from external flake
  spellbook = final: _prev: {
    spellbook = inputs.spellbook.packages.${final.system}.default;
  };

  # 5etools 2014 static site from local flake input
  fiveetools = final: _prev: {
    fiveetools = inputs.fiveetools.packages.${final.system}.default;
  };

  # Add tmux-git-worktree plugin to tmuxPlugins
  tmux-git-worktree = final: prev: {
    tmuxPlugins =
      prev.tmuxPlugins
      // {
        git-worktree = inputs.tmux-git-worktree.packages.${final.system}.default;
      };
  };
}

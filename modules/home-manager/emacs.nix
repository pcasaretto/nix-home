{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.modules.editors.emacs;
  mkOpt = type: default:
    mkOption {inherit type default;};

  mkBoolOpt = default:
    mkOption {
      inherit default;
      type = types.bool;
      example = true;
    };
in {
  options.modules.editors.emacs = {
    enable = mkBoolOpt false;
    default = mkBoolOpt false;
    # TODO: auto install doom
    # doom = rec {
    #   enable = mkBoolOpt false;
    # };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [inputs.emacs-overlay.overlay];

    home.packages = with pkgs; [
      ## Emacs itself
      binutils # native-comp needs 'as', provided by this
      # 28.2 + native-comp
      ((emacsPackagesFor emacs-unstable).emacsWithPackages
        (epkgs: [epkgs.vterm]))

      ## Doom dependencies
      git
      (ripgrep.override {withPCRE2 = true;})
      gnutls # for TLS connectivity

      ## Optional dependencies
      fd # faster projectile indexing
      imagemagick # for image-dired
      zstd # for undo-fu-session/undo-tree compression

      ## Module dependencies
      # :checkers spell
      (aspellWithDicts (ds: with ds; [en en-computers en-science]))
      # :tools editorconfig
      editorconfig-core-c # per-project style config
      # :tools lookup & :lang org +roam
      sqlite
    ];

    home.sessionVariables = mkIf cfg.default rec {
      EDITOR = ''emacsclient -t -a \"\"'';
      VISUAL = EDITOR;
    };
  };
}

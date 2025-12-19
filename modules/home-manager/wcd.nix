{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.wcd;
in {
  options.programs.wcd = {
    enable = lib.mkEnableOption "wcd (world cd) directory navigation";

    enableCdAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to alias cd to wcd.";
    };

    enableZshIntegration = lib.hm.shell.mkZshIntegrationOption {inherit config;};

    enableBashIntegration = lib.hm.shell.mkBashIntegrationOption {inherit config;};
  };

  config = lib.mkIf cfg.enable {
    home.shellAliases.cd = lib.mkIf cfg.enableCdAlias "wcd";

    programs.zsh.initContent = lib.mkIf cfg.enableZshIntegration (lib.mkAfter ''
      eval "$(wcd --init zsh)"
    '');

    programs.bash.initExtra = lib.mkIf cfg.enableBashIntegration (lib.mkAfter ''
      eval "$(wcd --init bash)"
    '');
  };
}

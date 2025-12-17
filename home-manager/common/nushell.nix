{
  pkgs,
  ...
}: {
  programs.nushell = {
    enable = true;
    package = pkgs.unstable.nushell;
    plugins = [
      pkgs.nushellPlugins.dns
    ];
    settings = {
      show_banner = false;
      edit_mode = "vi";
    };
    shellAliases = {
      l = "ls -la";
    };
    extraConfig = ''
      def ngs [ ...args: any] {
        git status --porcelain ...$args | from ssv -n -m 1 | rename status path | update path { [(git rev-parse --show-toplevel) $in] | path join }
      }
    '';
  };

  programs.starship.enableNushellIntegration = true;
}

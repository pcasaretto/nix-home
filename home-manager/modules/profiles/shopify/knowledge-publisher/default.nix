# Always-on publisher for ~/knowledge: qmd update/embed + Quick static site deploy.
{
  config,
  lib,
  pkgs,
  ...
}: let
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/state/knowledge-publisher";
  cacheDir = "${home}/.cache/knowledge-publisher";
  qmdPath = "${home}/.nix-profile/bin/qmd";
  quickPath = "${home}/.local/state/tec/profiles/base/current/global/bin/quick";
in {
  home.packages = [
    pkgs.knowledge-publisher
  ];

  home.activation.knowledgePublisherDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${lib.escapeShellArg stateDir}/logs ${lib.escapeShellArg stateDir}/tmp ${lib.escapeShellArg cacheDir}
  '';

  launchd.agents."com.pcasaretto.knowledge-publisher" = {
    enable = true;
    config = {
      Label = "com.pcasaretto.knowledge-publisher";
      ProgramArguments = [
        "${pkgs.knowledge-publisher}/bin/knowledge-publisher"
        "--knowledge-root"
        "${home}/knowledge"
        "--cache-dir"
        cacheDir
        "--state-dir"
        stateDir
        "--qmd"
        qmdPath
        "--quick"
        quickPath
        "--site-name"
        "pcasaretto-knowledge"
        "watch"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = home;
      StandardOutPath = "${stateDir}/logs/launchd.stdout.log";
      StandardErrorPath = "${stateDir}/logs/launchd.stderr.log";
      EnvironmentVariables = {
        PATH = lib.concatStringsSep ":" [
          "${home}/.nix-profile/bin"
          "${home}/.local/state/tec/profiles/base/current/global/bin"
          "${pkgs.knowledge-publisher}/bin"
          "${pkgs.coreutils}/bin"
          "${pkgs.findutils}/bin"
          "${pkgs.gnugrep}/bin"
          "/opt/homebrew/bin"
          "/usr/local/bin"
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
        KNOWLEDGE_PUBLISHER_ROOT = "${home}/knowledge";
        KNOWLEDGE_PUBLISHER_CACHE_DIR = cacheDir;
        KNOWLEDGE_PUBLISHER_STATE_DIR = stateDir;
        KNOWLEDGE_PUBLISHER_QMD = qmdPath;
        KNOWLEDGE_PUBLISHER_QUICK = quickPath;
        KNOWLEDGE_PUBLISHER_SITE_NAME = "pcasaretto-knowledge";
      };
    };
  };
}

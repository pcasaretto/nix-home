{ config, pkgs, ... }:

{
  users.users.clawdbot = {
    isSystemUser = true;
    group = "clawdbot";
    description = "clawdbot Telegram bot service user";
    home = "/var/lib/clawdbot"; # needed for Pi session/state persistence
  };

  users.groups.clawdbot = {};

  systemd.services.clawdbot = {
    description = "Pi-powered Telegram bot (clawdbot)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      TELEGRAM_BOT_TOKEN_FILE = config.sops.secrets.clawdbot-ai-telegram-token.path;
      ANTHROPIC_API_KEY_FILE  = config.sops.secrets.clawdbot-anthropic-key.path;

      # Comma-separated list of Telegram user IDs allowed to use the bot.
      # Find yours by sending /chatid to the bot before locking this down.
      ALLOWED_USER_IDS = "7363474774";  # <-- fill in your Telegram user ID

      NODE_ENV = "production";

      # Inactivity timeout in minutes before the next message starts a new session.
      # Default: 60. Set to "0" to never auto-expire.
      SESSION_TIMEOUT_MINUTES = "60";

      # Optional: override the model (default: claude-sonnet-4-5)
      # CLAWDBOT_MODEL = "claude-opus-4-5";

      # Optional: set a specific project path for the agent to work in.
      # Defaults to STATE_DIRECTORY when unset.
      # WORKING_DIRECTORY = "/home/pcasaretto/src/github.com/pcasaretto/nix-home";
    };

    serviceConfig = {
      ExecStart = "${pkgs.clawdbot}/bin/clawdbot";
      User  = "clawdbot";
      Group = "clawdbot";
      Restart    = "on-failure";
      RestartSec = 10;

      # systemd sets $STATE_DIRECTORY automatically to /var/lib/clawdbot
      StateDirectory = "clawdbot";

      # Hardening — relaxed just enough for the agent's tools to work
      NoNewPrivileges         = true;
      ProtectSystem           = "full";   # less strict than "strict" — agent writes to STATE_DIRECTORY
      ProtectHome             = "read-only";
      PrivateTmp              = true;
      PrivateDevices          = true;
      ProtectKernelTunables   = true;
      ProtectKernelModules    = true;
      ProtectControlGroups    = true;
      RestrictSUIDSGID        = true;
    };
  };
}

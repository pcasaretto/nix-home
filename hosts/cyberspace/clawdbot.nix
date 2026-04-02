{ config, pkgs, ... }:

{
  # ── Shared group for nix-home repo access ──────────────────────────────────
  # Both pcasaretto and clawdbot can read/write /srv/nix-home.
  users.groups.nix-home = {};

  users.users.pcasaretto = {
    extraGroups = [ "nix-home" ];
  };

  users.users.clawdbot = {
    isSystemUser = true;
    group = "clawdbot";
    extraGroups = [ "nix-home" ];
    description = "clawdbot Telegram bot service user";
    home = "/var/lib/clawdbot"; # Pi session/state persistence
  };

  users.groups.clawdbot = {};

  # ── /srv/nix-home shared directory ────────────────────────────────────────
  # One-time setup after deploying:
  #   sudo mv ~/src/github.com/pcasaretto/nix-home /srv/nix-home
  #   sudo chown -R pcasaretto:nix-home /srv/nix-home
  #   sudo chmod -R g+w /srv/nix-home
  #   sudo find /srv/nix-home -type d -exec chmod g+s {} \;
  # tmpfiles ensures the directory exists with correct ownership on boot.
  systemd.tmpfiles.rules = [
    "d /srv/nix-home 2775 pcasaretto nix-home -"
  ];

  # ── Allow clawdbot to run nixos-rebuild switch ────────────────────────────
  security.sudo.extraRules = [
    {
      users = [ "clawdbot" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # ── systemd service ───────────────────────────────────────────────────────
  systemd.services.clawdbot = {
    description = "Pi-powered Telegram bot (clawdbot)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      TELEGRAM_BOT_TOKEN_FILE = config.sops.secrets.clawdbot-ai-telegram-token.path;
      ANTHROPIC_API_KEY_FILE  = config.sops.secrets.clawdbot-anthropic-key.path;

      # Comma-separated list of Telegram user IDs allowed to use the bot.
      ALLOWED_USER_IDS = "7363474774";

      NODE_ENV = "production";

      # Inactivity timeout in minutes before the next message starts a new session.
      SESSION_TIMEOUT_MINUTES = "60";

      # The agent works inside the shared nix-home repo.
      WORKING_DIRECTORY = "/srv/nix-home";

      # Optional: override the model (default: claude-sonnet-4-5)
      # CLAWDBOT_MODEL = "claude-opus-4-5";
    };

    serviceConfig = {
      ExecStart = "${pkgs.clawdbot}/bin/clawdbot";
      User  = "clawdbot";
      Group = "clawdbot";
      Restart    = "on-failure";
      RestartSec = 10;

      # Pi sessions/auth stored in /var/lib/clawdbot ($STATE_DIRECTORY)
      StateDirectory = "clawdbot";

      # /srv/nix-home must be writable for the agent's edit/write/bash tools.
      ReadWritePaths = [ "/srv/nix-home" ];

      # Hardening — relaxed for sudo + filesystem access
      NoNewPrivileges       = false;  # sudo requires privilege escalation
      ProtectSystem         = "full";
      ProtectHome           = false;  # allow reading home dirs if needed
      PrivateTmp            = true;
      PrivateDevices        = true;
      ProtectKernelTunables = true;
      ProtectKernelModules  = true;
      ProtectControlGroups  = true;
      RestrictSUIDSGID      = false;  # sudo is a SUID binary
    };
  };
}

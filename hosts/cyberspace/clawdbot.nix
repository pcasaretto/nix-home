{ config, pkgs, ... }:

{
  users.users.clawdbot = {
    isSystemUser = true;
    group = "clawdbot";
    description = "clawdbot Telegram bot service user";
  };

  users.groups.clawdbot = {};

  systemd.services.clawdbot = {
    description = "clawdbot Telegram bot";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      TELEGRAM_BOT_TOKEN_FILE = config.sops.secrets.clawdbot-telegram-token.path;
    };

    serviceConfig = {
      ExecStart = "${pkgs.clawdbot}/bin/clawdbot";
      User = "clawdbot";
      Group = "clawdbot";
      Restart = "on-failure";
      RestartSec = 10;

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
    };
  };
}

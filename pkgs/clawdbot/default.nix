{ python3Packages, ... }:

python3Packages.buildPythonApplication {
  pname = "clawdbot";
  version = "0.1.0";
  format = "other";

  src = ./.;

  propagatedBuildInputs = [
    python3Packages.python-telegram-bot
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp clawdbot.py $out/bin/clawdbot
    chmod +x $out/bin/clawdbot
  '';

  meta = {
    description = "Telegram bot for notifications and future AI interactions";
    mainProgram = "clawdbot";
  };
}

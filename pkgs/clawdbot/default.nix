{ buildNpmPackage, nodejs, ... }:

buildNpmPackage {
  pname = "clawdbot";
  version = "0.2.0";

  src = ./.;

  nodejs = nodejs;

  # Run `nix build` once with a wrong hash to get the correct one from the error message,
  # then replace this placeholder.
  npmDepsHash = "sha256-TClfZXZgWmWzw/4ABHkIGPNSAI7zR04Pg4d/JxSvMsQ=";

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    mkdir -p $out/bin $out/lib/clawdbot
    cp -r dist node_modules package.json $out/lib/clawdbot/
    cat > $out/bin/clawdbot << EOF
#!/bin/sh
exec ${nodejs}/bin/node $out/lib/clawdbot/dist/index.js "\$@"
EOF
    chmod +x $out/bin/clawdbot
  '';

  meta = {
    description = "Pi-powered Telegram bot for AI coding assistance";
    mainProgram = "clawdbot";
  };
}

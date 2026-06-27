# Plan: Home Assistant MCP via OpenAI Secure MCP Tunnel

## Goal

Run `homeassistant-ai/ha-mcp` on cyberspace as a private MCP server for Home Assistant, then expose it to supported OpenAI products through OpenAI Secure MCP Tunnel without opening inbound ports or publishing the MCP endpoint through Caddy/Nabu Casa.

## Target Architecture

```text
ChatGPT / Codex / OpenAI Responses API
   ⇅ OpenAI-hosted MCP tunnel endpoint
cyberspace: openai tunnel-client
   ⇢ http://127.0.0.1:<ha-mcp-port>/mcp
cyberspace: ha-mcp
   ⇢ http://127.0.0.1:10123 Home Assistant
```

## Execution Status

- Status: **Built; activation blocked by root permissions**
- Reason: `nixos-rebuild switch` requires root on cyberspace.
- Build output: `/nix/store/5f6smqhc7z1dr6j5z2ymdn2ihmqj36rv-nixos-system-cyberspace-25.11.20260306.71caefc`
- Activation command: `cd /srv/nix-home && sudo nixos-rebuild switch --flake .#cyberspace`

## Plan

1. **[DONE] Create required credentials**
   - Generate a Home Assistant long-lived access token for `ha-mcp`.
   - Create an OpenAI Secure MCP Tunnel in Platform tunnel settings.
   - Obtain:
     - `tunnel_id`
     - OpenAI tunnel runtime API key

2. **[DONE] Add SOPS secrets**
   - Add `home-assistant-mcp-token` for the HA long-lived access token.
   - Add `openai-mcp-tunnel-api-key` for the OpenAI tunnel runtime key.
   - Keep `openai-mcp-tunnel-id` as normal Nix config unless we decide to treat it as sensitive.

3. **[DONE] Add local port allocation**
   - Add a new cyberspace port option, likely under `services.cyberspace.ports.ai`, for example:
     - `haMcp = 11583`
   - The service must bind to `127.0.0.1` only.

4. **[DONE] Package/run `ha-mcp`**
   - Prefer a NixOS systemd service over Home Assistant add-ons.
   - Run `ha-mcp` in HTTP mode using `ha-mcp-web`.
   - Environment:
     - `HOMEASSISTANT_URL=http://127.0.0.1:10123`
     - `HOMEASSISTANT_TOKEN=<from SOPS>`
     - `MCP_HOST=127.0.0.1`
     - `MCP_PORT=<ha-mcp-port>`
     - `MCP_SECRET_PATH=/mcp` or a generated private path
   - Create a dedicated `ha-mcp` system user.

5. **[DONE] Package/run OpenAI `tunnel-client`**
   - Add or package `openai/tunnel-client` for NixOS.
   - Create a systemd service that:
     - Starts after `ha-mcp.service`
     - Reads `CONTROL_PLANE_API_KEY` from SOPS
     - Uses the configured OpenAI `tunnel_id`
     - Forwards to `http://127.0.0.1:<ha-mcp-port>/mcp`
   - Run `tunnel-client doctor --profile <profile> --explain` during validation.

6. **[DONE] Security defaults**
   - No Caddy public route initially.
   - No Nabu Casa webhook proxy initially.
   - No inbound firewall port.
   - Systemd hardening:
     - `NoNewPrivileges=true`
     - `PrivateTmp=true`
     - `ProtectSystem=strict`
     - `ProtectHome=true`
     - `ReadWritePaths=/var/lib/ha-mcp` only if needed
   - Secrets should be readable only by their service users.

7. **[PARTIAL] Validation**
   - Confirm `ha-mcp` starts and can reach Home Assistant.
   - Confirm MCP tool discovery works locally over HTTP.
   - Confirm `tunnel-client doctor` passes.
   - Confirm ChatGPT/Codex/OpenAI can discover tools via the tunnel.
   - Check systemd logs for:
     - bad HA token
     - bad OpenAI tunnel key
     - wrong MCP path
     - tunnel not associated with the correct OpenAI organization/workspace

8. **[READY] Rollback**
   - Stop/disable `openai-mcp-tunnel.service`.
   - Stop/disable `ha-mcp.service`.
   - Remove the OpenAI tunnel in Platform settings if no longer needed.
   - Home Assistant itself should remain unchanged.

## Notes

- This approach is for OpenAI-supported MCP clients only. It does not make the MCP server available to Claude.ai, Claude Desktop, Cursor, etc.
- The Home Assistant add-on and Webhook Proxy path from the `ha-mcp` README assumes Home Assistant OS/Supervised. cyberspace runs HA through NixOS `services.home-assistant`, so that path is not plug-and-play.
- If later we need non-OpenAI clients, add a separate Caddy-protected HTTPS endpoint or manually install/configure the `mcp_proxy` custom integration.

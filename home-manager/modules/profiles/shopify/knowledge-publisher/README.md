# Knowledge publisher operations

This module installs an always-on local publisher for `/Users/paulo.casaretto/knowledge`.

## Content contract

Published markdown is folder-based and blocklist-driven: markdown under any top-level folder publishes by default.

The site excludes:

- `tuple-calls/**`
- `work-journal-evidence/**`
- hidden paths
- `AGENTS.md`
- loose top-level markdown files
- non-markdown files and source assets

Drafts are published by default. Future markdown in any non-blocked top-level folder auto-publishes, and new top-level folders automatically become qmd collections.

## Rendering conventions

Document pages generate a table of contents automatically from markdown headings and assign stable heading IDs for in-page links.

Local references to published knowledge markdown are rewritten to Quick URLs during rendering. This applies to markdown links, normal prose, inline code, and rendered metadata values for paths such as `~/knowledge/research/example.md`, `/Users/paulo.casaretto/knowledge/research/example.md`, and `file:///Users/paulo.casaretto/knowledge/research/example.md`. References to blocked or unpublished markdown stay unchanged.

Index pages can show an explicit summary for each document. Add a short public summary near the top of a markdown file, then separate it from the full body with the Hugo-style marker:

```markdown
A concise public summary that is safe to show on collection and recent-document index pages.

<!--more-->

## Full document starts here
```

The summary renders as a lede on the document page and as teaser text on index pages. If the marker is absent, the document still publishes normally but has no explicit teaser.

## qmd collection map

The publisher reconciles qmd collections for every non-blocked top-level folder under `/Users/paulo.casaretto/knowledge`, using the folder name as the qmd collection name and `**/*.md` as the mask.

Existing qmd collections are left in place. New folders such as `intentions/` or `dashboards/` are added automatically on the next normal publisher run. Blocked folders and loose top-level markdown are not added.

## Paths

- Generated site: `~/.cache/knowledge-publisher/site`
- State: `~/.local/state/knowledge-publisher/status.json`
- Manifest: `~/.local/state/knowledge-publisher/publish-manifest.json` and `.md`
- Logs: `~/.local/state/knowledge-publisher/logs/publisher.log`
- Launchd stdout/stderr: `~/.local/state/knowledge-publisher/logs/launchd.stdout.log` and `.stderr.log`
- Local rendering warnings: `~/.local/state/knowledge-publisher/site-warnings.log`

Logs rotate at roughly 5 MiB with five retained rotations.

## Manual commands

```bash
knowledge-publisher preflight
knowledge-publisher reconcile-qmd
knowledge-publisher dry-run-manifest
knowledge-publisher generate-site
knowledge-publisher run-once
knowledge-publisher run-once --no-deploy
knowledge-publisher status
knowledge-publisher status --json
knowledge-publisher watch
```

The normal deploy target is:

```text
https://pcasaretto-knowledge.quick.shopify.io
```

The publisher refuses a different site name by default.

## Service management

Apply the Home Manager module:

```bash
cd /Users/paulo.casaretto/src/github.com/pcasaretto/nix-home
home-manager switch --flake .#paulo.casaretto
```

Stop the service:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.pcasaretto.knowledge-publisher.plist
```

Start the service:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pcasaretto.knowledge-publisher.plist
launchctl kickstart -k gui/$(id -u)/com.pcasaretto.knowledge-publisher
```

Disable rollback:

1. Remove `./shopify/knowledge-publisher` from `home-manager/modules/profiles/shopify.nix` imports.
2. Run `home-manager switch --flake .#paulo.casaretto`.
3. Optionally delete `~/.cache/knowledge-publisher` and `~/.local/state/knowledge-publisher`.

## Adding a new knowledge area

Create a new top-level folder under `/Users/paulo.casaretto/knowledge` and add markdown files. The next normal publisher run will create a matching qmd collection, regenerate the site, and deploy it.

To prevent a folder from publishing or becoming a qmd collection, add the folder name to `BLOCKED_DIRS` in `pkgs/knowledge-publisher/src/main.rs` before adding content.

## Future privacy markers

No privacy marker convention is active yet. Add one inside `publish_decision` in `pkgs/knowledge-publisher/src/main.rs`, then test it with the dry-run manifest before enabling auto-publish for marked content.

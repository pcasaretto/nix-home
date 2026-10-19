# Keyboards

This directory holds the canonical QMK keymaps. The repository root is the QMK External Userspace, as defined by `../qmk.json`.

Keep personal keymaps here, not in the QMK firmware checkout.

## Moonlander

`zsa/moonlander/keymaps/pcasaretto/` contains the Oryx source export for [Mac programmer: complex with a gentle learning curve](https://configure.zsa.io/moonlander/layouts/3Or4W/DzKKpq/0) (Moonlander Mk1, firmware v25.0). The export defines seven layers, tap dances, app-launch macros, and per-layer RGB colors. See the [downloadable Oryx source](https://oryx.zsa.io/source/DzKKpq).

When you update this layout, replace `keymap.c`, `keymap.json`, `config.h`, `i18n.h`, and `rules.mk` together from the Oryx source archive.

`../qmk.json` covers both Moonlander revisions because the hardware revision is not specified. `qmk userspace-compile` builds both targets and does not flash the keyboard. To build one revision, use `qmk compile -kb zsa/moonlander/reva -km pcasaretto` or replace `reva` with `revb`.

## Build setup

From the repository root, enter the Nix shell and set up ZSA's QMK firmware checkout once:

```sh
nix develop .#keyboards
qmk setup zsa/qmk_firmware -b firmware25
```

From the repository root, point QMK at this External Userspace and compile both targets:

```sh
qmk config user.overlay_dir="$(pwd)"
qmk userspace-compile
```

The QMK Nix package supplies the CLI, the ARM compiler, Make, and flashing tools. `git` is included for the firmware checkout.

QMK writes compiled `.bin` files to the repository root. `.gitignore` excludes these build outputs.

See [AGENTS.md](AGENTS.md) for keycode constraints and upstream references.

# QMK keymap rules

- Keep keymaps and shared keyboard code in this QMK External Userspace. Do not edit the separate QMK firmware checkout.
- Build Moonlander firmware with ZSA's `zsa/qmk_firmware` branch `firmware25`. The supported build targets are `zsa/moonlander/reva` and `zsa/moonlander/revb`.
- `MT(mod, key)` and `LT(layer, key)` accept only Basic Keycodes as `key`. Do not put `LCTL(...)`, `KC_TILD`, shifted aliases, or custom keycodes in that argument. Use a Basic Keycode, Tap Dance, or custom keymap code instead.
- The imported Oryx export uses `LT(4, KC_MEDIA_PLAY_PAUSE)`. Keep this generated binding unless you test a replacement on the firmware.
- Oryx exports can need both `zsa/oryx` and `zsa/defaults`; list every required module in the keymap's `keymap.json`. ZSA keycodes such as `LED_LEVEL` come from `zsa/defaults`. `TOGGLE_LAYER_COLOR` also needs `ORYX_CONFIGURATOR` in `config.h`.
- Keep firmware control codes such as `QK_BOOT` and `EE_CLR` off the base typing layer. Put them only on a deliberate service layer.

## References

- [QMK Mod-Tap restrictions](https://docs.qmk.fm/mod_tap#caveats)
- [QMK Layer-Tap restrictions](https://docs.qmk.fm/feature_layers#caveats)
- [QMK Basic Keycodes](https://docs.qmk.fm/keycodes_basic)
- [QMK External Userspace](https://docs.qmk.fm/newbs_external_userspace)
- [ZSA defaults module in `firmware25`](https://github.com/zsa/qmk_firmware/tree/firmware25/modules/zsa/defaults)
- [ZSA Moonlander documentation in `firmware25`](https://github.com/zsa/qmk_firmware/blob/firmware25/keyboards/zsa/moonlander/readme.md)
- [ZSA Moonlander default keymap](https://github.com/zsa/qmk_firmware/blob/firmware25/keyboards/zsa/moonlander/keymaps/default/keymap.c)

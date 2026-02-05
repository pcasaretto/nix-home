## CRITICAL: Verdict flag knowledge

- If you encounter Verdict flag related code, load up the shopify-verdict-flags skill
- DO NOT EVER STUB Verdict flags

## Default commands
- General: Prepend all shell commands other than find, rg, grep, sed, cp, ls with `shadowenv exec -- ` to ensure that environment variables are properly set.
- General: Read `dev.yml` to find commonly-used commands for testing, linting, and other development tasks. [Full documentation](https://vault.shopify.io/page/Syntax-of-devyml~dhb31bf.md)
- Test: `/opt/dev/bin/dev test path/to/file`

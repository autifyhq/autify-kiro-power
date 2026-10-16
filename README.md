# Autify powers for Kiro

Kiro powers that connect [Kiro](https://kiro.dev) to Autify products. Kiro installs one
power per directory, so this repository holds one directory per product.

| Power | Directory | Install URL | Status |
|---|---|---|---|
| Autify Aximo | [`aximo/`](aximo/) | `https://github.com/autifyhq/autify-kiro-power/tree/main/aximo` | Preview |
| Autify Genesis | not here yet | | Planned (GEN-3003) |

## Install a power

In Kiro IDE: Powers panel, **Add Custom Power**, **Import power from GitHub**, paste the
install URL from the table, **Install**. Importing from a local folder works too: clone
this repository and pick the power's directory.

The repository root holds no `plugin.json`, so pasting the bare repository URL imports
nothing. The URL has to point at the power's directory.

Each power's own README covers what it does, how to authenticate, and how to try it.

## Add a power

One directory per product. Inside it, `plugin.json` at the directory root, the rest of
the Agent Plugins 1.0 layout beside it, and a README written for the developer installing
it. Nothing at the repository root needs to change.

## Licence

Apache License 2.0. See [`LICENSE`](LICENSE).

## Privacy and support

- Privacy policy: https://autify.com/privacy
- Support: support@autify.com

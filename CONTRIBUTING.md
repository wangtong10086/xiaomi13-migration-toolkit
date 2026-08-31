# Contributing

[简体中文](CONTRIBUTING.zh-CN.md) | English

Contributions are welcome when they keep the toolkit explicit, reviewable, and fail-closed.

## Before opening a change

- Open an Issue for a new device, ROM, partition, or destructive workflow proposal.
- Keep hardware identity, ROM/firmware, root, framework hooks, apps/data, and settings as separate layers.
- Never add an implicit first-device fallback. Every write must require an explicit serial and expected product.
- Do not commit ROMs, backups, databases, account material, wallet/TSM data, keyboxes, keystores, tokens, serials, or unredacted logs.

## Pull requests

Include the tested device/ROM boundary, commands used, expected and observed result, rollback path, and privacy review. Add or update offline tests for changes to validation, manifests, downloads, or installation behavior. Documentation-only corrections still need source links for version-sensitive claims.

Run the repository `validate` workflow locally where possible. A PR must pass all required checks and resolve review conversations before merge.

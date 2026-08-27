# Xiaomi 13 migration toolkit

Reusable, fail-closed tooling and documentation for moving a customized Xiaomi 13 (`fuxi`) installation to another Xiaomi 13. The workflow deliberately treats the ROM, boot/root state, apps, user data, and post-boot configuration as separate layers.

This repository contains no device backup, account material, wallet data, signing key, ROM image, Magisk database, LSPosed/Vector database, or real device serial. Those remain outside Git and must be supplied locally.

## Workflow

1. Capture both devices with `scripts/Get-AndroidDeviceInventory.ps1`.
2. Compare the inventories and confirm the physical destination.
3. Follow `docs/runbook.md`; do not combine partition flashing and user-data restore into one opaque step.
4. Generate and verify SHA-256 manifests for every local artifact.
5. Apply post-boot customizations from the companion repositories only after the base system boots cleanly.

For servers that support byte ranges, `Download-VerifiedRangeFile.ps1` can resume parallel segments and only promotes the assembled file after its length and expected hash match.

The scripts require Android platform-tools on `PATH`. Any mutating command requires an explicit serial; there is intentionally no "first attached device" fallback.

## Companion repositories

- `xiaomi13-lineage-customization`: boot guards, launcher layout, and state audits.
- `xiaomi13-camera-kernel-compat`: camera/OIS kernel overlay and build recipe.
- `xiaomi13-lsposed-compat`: scoped Android 16 compatibility modules.

## Safety model

- Inventory and verification are read-only.
- Serial selection is mandatory before a write.
- Flashing commands are documented, not auto-run.
- Secrets and device images are ignored by default.
- Wallet and passkey credentials are re-provisioned through their issuers; copying private app data is not a portable backup strategy.

Use only on devices you own and can recover through fastboot.

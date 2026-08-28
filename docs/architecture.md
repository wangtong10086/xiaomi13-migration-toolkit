# Migration layers

Treating a complete Android migration as a file copy makes rollback and upgrades fragile. This toolkit uses six independently verifiable layers.

| Layer | Examples | Restore rule |
| --- | --- | --- |
| Hardware identity | product, SoC, storage size | Compare only; never clone identifiers |
| Firmware/ROM | boot chain, dynamic partitions, vendor firmware | Use a package built for `fuxi`; verify hashes and slot topology |
| Root runtime | patched boot/init_boot, Magisk modules | Install against the exact target build, then boot-test |
| Framework hooks | LSPosed/Vector modules and scopes | Restore module APKs first; apply scopes only after package presence is verified |
| Apps and user data | APKs, app databases, shared storage | Prefer supported migration/export; never restore Wallet/TSM data as a substitute for destination eSE provisioning |
| Settings and UI | secure/global/system settings, IME, launcher | Apply last, with before/after exports and a rollback copy |

## Upgrade rule

Keep base ROM updates independent from compatibility overlays. After every ROM update:

1. Re-capture inventory and partition fingerprints.
2. Rebuild boot/kernel artifacts against the new commit.
3. Boot without optional modules when the ABI or Android version changes.
4. Re-enable scoped modules one at a time and record validation evidence.

Never commit raw exports. Store only sanitized templates and artifact hashes.

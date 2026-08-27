# Reproducible migration runbook

## 1. Establish identity

Connect one phone at a time for the initial capture. Save the inventory outside the repository:

```powershell
./scripts/Get-AndroidDeviceInventory.ps1 -Serial '<source-serial>' -OutputPath './work/source.json'
./scripts/Get-AndroidDeviceInventory.ps1 -Serial '<target-serial>' -OutputPath './work/target.json'
```

Confirm `ro.product.device=fuxi`, storage expectations, bootloader state, active slot, Android version, and build fingerprint. Photograph or physically label the destination before any erase.

## 2. Freeze inputs

Put ROM and locally built artifacts under an ignored `artifacts/` directory. Create a SHA-256 manifest:

```powershell
./scripts/New-FileManifest.ps1 -Root './artifacts' -OutputPath './work/artifacts.sha256.json'
./scripts/Test-FileManifest.ps1 -ManifestPath './work/artifacts.sha256.json'
```

## 3. Restore in layers

1. Base firmware/ROM and required data wipe.
2. First clean boot, USB debugging, and build-fingerprint verification.
3. Root runtime and one boot cycle.
4. Framework manager and scoped compatibility modules.
5. Apps and supported app-data restores.
6. Settings, IME, and launcher layout.

Stop at the first unexpected black screen, boot loop, partition mismatch, or SELinux regression. Return to the last bootable artifact instead of stacking more changes.

## 4. Validate

Record:

- clean boot and `sys.boot_completed=1`;
- SELinux enforcing;
- camera capture, OIS behavior, and post-processing latency;
- Play services/passkey operation using supported account re-enrollment;
- Xiaomi Market download/update completion;
- NFC wallet launch and a non-payment reader check;
- launcher restart and database integrity;
- recent crash buffer and module-manager state.

## 5. Keep private material private

Do not publish serials, account identifiers, wallet/card data, app-private databases, attestation material, bootloader unlock tokens, keystores, or full UI/log dumps. GitHub Releases in companion repositories contain only reproducible binaries and checksums.

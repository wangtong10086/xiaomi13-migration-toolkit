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
5. Apps and supported app-data restores. Exclude Xiaomi Wallet/TSM private data and re-provision cards through the issuer UI.
6. Settings, IME, and launcher layout.

For push repair, treat MiPush/XMSF and Google FCM as independent stacks. Systemize a verified XMSF APK and apply only reviewed Xposed scopes; never copy an XMSF registration database across signing certificates. A non-empty XMSF registration ID is still insufficient when the target application must bind the vendor token to its own server; verify that application-specific callback separately. Feishu 7.75.15 requires the narrowly scoped `lark-mipush-token-bridge` documented in the `xiaomi13-lsposed-compat` repository when the external MiPush module's legacy ByteDance hook does not attach. For FCM, preserve GMS/Gmail data and diagnose the shared GMS connection before changing application policies or VPN routing.

For an unregistered MiPush application, use one bounded main-process registration window at a time. Preserve the original Vector scope and denylist state, do not disable the global hiding stack, and accept registration only when the app regId is non-empty, XMSF records `type=21/result=0`, and `registered_type=1`. Stop after one controlled XMSF reconnect; a repeated `type=2` without a result is a compatibility finding, not permission to edit XMSF tables or guess credentials.

Stop at the first unexpected black screen, boot loop, partition mismatch, or SELinux regression. Return to the last bootable artifact instead of stacking more changes.

## 4. Validate

Record:

- clean boot and `sys.boot_completed=1`;
- SELinux enforcing;
- camera capture, OIS behavior, and post-processing latency;
- Play services/passkey operation using supported account re-enrollment;
- Xiaomi Market download/update completion;
- NFC and Secure Element service health, a newly provisioned destination card, and acceptance by its real reader;
- launcher restart and database integrity;
- recent crash buffer and module-manager state.
- XMSF system-app flags, one real target-app registration, any required application-server token binding, and ten non-duplicated MiPush deliveries;
- the GMS-owned 443/5228-5230 connection, reconnect after network transitions, and ten numbered Gmail deliveries without permanent loss;
- for Gmail, record transport delivery separately from notification policy: successful `gmail-ls` sync, marker present in the inbox, Android channel enabled, and the reviewed per-account **All** or **High priority only** setting.

## 5. Keep private material private

Do not publish serials, account identifiers, wallet/card data, app-private databases, attestation material, bootloader unlock tokens, keystores, or full UI/log dumps. GitHub Releases in companion repositories contain only reproducible binaries and checksums.

If a copied Xiaomi door card is visible but unusable, or deletion fails with TSM error `1010022`, do not copy more private data or eSE material. Preserve the source phone, back up the destination privately, reset only the destination TSM state, and add the card again through Xiaomi Wallet. The detailed recovery and validation procedure is maintained in the companion customization repository.

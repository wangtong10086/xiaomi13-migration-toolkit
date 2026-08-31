# 可复现迁移手册

简体中文 | [English](runbook.md)

## 1. 确认设备身份

首次采集时每次只连接一台手机，清单保存在仓库之外：

```powershell
./scripts/Get-AndroidDeviceInventory.ps1 -Serial '<source-serial>' -OutputPath './work/source.json'
./scripts/Get-AndroidDeviceInventory.ps1 -Serial '<target-serial>' -OutputPath './work/target.json'
```

确认 `ro.product.device=fuxi`、存储容量、Bootloader 状态、当前槽位、Android 版本和构建指纹。擦除前给目标设备拍照或贴上物理标签。

## 2. 固定输入

把 ROM 和本地构建工件放在被忽略的 `artifacts/` 中，并生成 SHA-256 manifest：

```powershell
./scripts/New-FileManifest.ps1 -Root './artifacts' -OutputPath './work/artifacts.sha256.json'
./scripts/Test-FileManifest.ps1 -ManifestPath './work/artifacts.sha256.json'
```

## 3. 分层恢复

1. 基础固件/ROM 和必要的数据擦除。
2. 第一次干净启动、USB 调试和构建指纹验证。
3. Root 运行层和一次独立启动。
4. Framework 管理器及限定作用域的兼容模块。
5. 应用和受支持的应用数据；排除小米钱包/TSM 私有数据并通过发行方界面重新开卡。
6. 系统设置、输入法和启动器布局。

MiPush/XMSF 与 Google FCM 是两个独立推送栈。只允许经过验证的 XMSF APK 和已复核的 Xposed 作用域；不得跨签名复制 XMSF 注册数据库。非空 RegID 也不能替代应用服务器 token 绑定的验证。

每次只为一个未注册应用打开一次有限的主进程注册窗口。保留原 Vector 作用域和 denylist，接受结果必须同时满足：应用 RegID 非空、XMSF `type=21/result=0`、`registered_type=1`。重复 `type=2` 但没有结果是兼容性发现，不是编辑数据库或猜测凭据的许可。

遇到黑屏、Bootloop、分区不匹配或 SELinux 回退时立即停止，恢复到最后一个可启动工件，不叠加更多修改。

## 4. 验证

至少记录：

- 干净启动和 `sys.boot_completed=1`；
- SELinux enforcing；
- 相机拍摄、OIS 与后处理延迟；
- Play 服务/Passkey 的受支持重新配置；
- 小米应用商店下载和更新；
- NFC、安全元件、新开卡及真实读卡器验证；
- 启动器重启和数据库完整性；
- 最近崩溃缓冲和模块管理器状态；
- XMSF 系统应用标志、真实目标应用注册、必要的服务端 token 绑定和十条无重复 MiPush；
- GMS 443/5228–5230 连接、网络切换重连及十条编号 FCM/Gmail 测试。

## 5. 私有材料

不得公开序列号、账户标识、钱包/卡片数据、应用私有数据库、认证材料、Bootloader 解锁 token、keybox、签名库或完整界面/日志转储。Release 只包含可复现工件及校验值。

如果复制的门卡可见但不可用，或删除时报 TSM `1010022`，不要继续复制私有数据或 eSE 材料。保留源手机，私下备份目标手机，只重置目标 TSM 状态并通过小米钱包重新添加卡片。

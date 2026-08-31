# Xiaomi 13 迁移工具集

简体中文 | [English](README.md)

这是一个面向 Xiaomi 13（`fuxi`）的可复核、失败即停止的迁移工具与文档集合。它把 ROM/固件、启动与 root、应用、用户数据以及开机后的配置视为相互独立的迁移层，而不是把整机迁移简化为一次文件复制。

本仓库不包含设备备份、账户材料、钱包数据、签名密钥、ROM 镜像、Magisk 数据库、LSPosed/Vector 数据库或真实设备序列号。这些材料必须保存在 Git 之外并由使用者在本地显式提供。

## 工作流程

1. 使用 `scripts/Get-AndroidDeviceInventory.ps1` 分别采集两台设备。
2. 比较清单并人工确认物理目标设备。
3. 按照 [中文迁移手册](docs/runbook.zh-CN.md) 分层操作，不把分区刷写和用户数据恢复合并成不透明步骤。
4. 为所有本地工件生成并验证 SHA-256 manifest。
5. 仅在基础系统能够干净启动后，应用配套仓库中的开机后定制。

小米钱包和 NFC 应按照配套的[钱包/NFC 恢复说明](https://github.com/wangtong10086/xiaomi13-lineage-customization/blob/main/docs/xiaomi-wallet-nfc.md)重新配置。门卡 applet 和密钥必须在目标安全元件上重新下发；复制 TSM 私有数据不能替代正常开卡。

如果应用代码丢失但私有数据仍保留，`Restore-VerifiedAndroidApp.ps1` 可以从一个显式指定的源设备拉取经过验证的 base APK，或使用显式指定的本地厂商签名 APK，再安装到显式指定的目标设备。没有 `-Install` 时它只读。

对于支持 HTTP Range 的服务器，`Download-VerifiedRangeFile.ps1` 可以断点并行下载；只有长度和预期哈希均匹配时才会提升为最终文件。

所有会修改设备的命令都要求显式 serial，不存在“使用第一台连接设备”的回退逻辑。

## 配套仓库

- [xiaomi13-lineage-customization](https://github.com/wangtong10086/xiaomi13-lineage-customization)：开机保护、系统设置、启动器、root/framework 审计和推送修复。
- [xiaomi13-camera-kernel-compat](https://github.com/wangtong10086/xiaomi13-camera-kernel-compat)：相机/OIS 内核 overlay、构建和回滚说明。
- [xiaomi13-lsposed-compat](https://github.com/wangtong10086/xiaomi13-lsposed-compat)：限定版本和作用域的 Android 16 兼容模块。

## 兼容状态

| 层 | 仓库 | 已复核目标 | 状态 |
| --- | --- | --- | --- |
| 迁移与校验 | 本仓库 | Xiaomi 13 `fuxi`；ADB/Fastboot 必须显式选择 serial | 失败即停止的工具 |
| 相机/OIS 内核 | `xiaomi13-camera-kernel-compat` | 锁定的 LineageOS 23.2 / Android 16 内核 commit | 构建专用预发布 |
| 开机后定制 | `xiaomi13-lineage-customization` | 已复核的 Android 16 安装 | 分组件、阶段性验证 |
| Framework 兼容 | `xiaomi13-lsposed-compat` | 每个模块文档中的精确应用/ROM 版本 | 版本锁定预发布 |

公开仓库只表示代码可被审阅，不表示工件可以跨产品、ROM、ABI、槽位或分区布局通用。

## 安全模型

- 清单和校验命令默认只读。
- 写操作必须指定 serial。
- 刷写命令只在文档中示例，不自动执行。
- 密钥、设备镜像和私有数据默认被忽略。
- 钱包和 Passkey 通过服务提供方重新配置，不把私有应用数据当作可移植凭据。

仅在您拥有并能够通过 Fastboot 恢复的设备上使用。

贡献前请阅读 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。问题报告不得包含序列号、账户、token、keybox、钱包/TSM、私有数据库或未脱敏日志。安全漏洞请按照 [SECURITY.md](SECURITY.md) 使用 GitHub 私密漏洞报告。

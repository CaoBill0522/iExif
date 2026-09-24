# iExif

iOS / iPadOS 照片 EXIF 编辑器（SwiftUI，iOS 17+）。可以修改照片的机型、镜头、光圈、快门、ISO、拍摄时间和地点，内置 iPhone 4 到 iPhone 18 系列、全部带摄像头 iPad 的镜头参数。免费，无内购，不收集任何数据。

[在 App Store 下载](https://apps.apple.com/us/app/iexif/id6814786080)

需求见 [docs/需求文档.md](docs/需求文档.md)。

## 运行

用 Xcode 打开 `ExifEditor.xcodeproj`，选择 `ExifEditor` scheme 运行即可。

首次在真机运行前，在 Signing & Capabilities 里选择你的开发团队。

## 目录

```
ExifEditor/             App 源码
  App/                  入口
  Models/               PhotoMetadata（可编辑字段）、PhotoItem、设备预设、模板、设置
  Services/             MetadataService（ImageIO 读写）、相册、实况照片、格式转换、坐标转换
  Views/                各界面；Library/ 相册首页，Onboarding/ 功能介绍，Components/ 共用的字段编辑行
  Resources/            Devices.json、Localizable.xcstrings、InfoPlist.xcstrings、Assets、隐私清单
ExifEditor.xcodeproj/
web/                    官网（PHP，无数据库），说明见 docs/网站说明.md
deploy/                 官网部署说明和 Nginx 配置示例
store/                  App Store 文案和截图
tools/
  build_devices.py      生成 Resources/Devices.json
  dev-router.php        本地预览官网用的路由
  package-site.sh       生成官网部署包
docs/                   需求文档、网站说明
```

## 元数据写入

`MetadataService` 有两条写入路径：

- JPEG / HEIC：`CGImageDestinationCopyImageSource`，只替换元数据块，图像数据不重新编码（已验证写入前后像素哈希一致）。
- PNG：`CGImageDestinationAddImageFromSource` 重写属性字典，PNG 本身无损。

需要转格式（跟随机型默认：iPhone 7 及以后 HEIC，更早 JPEG）或匹配机型分辨率时，先由 `ImageTranscoder` 以 90% 质量重新编码，再走上面的元数据写入。实况照片的视频由 `LivePhotoVideo` 用 Passthrough 导出同步时间、地点和机型，配对编号（MakerApple 17 ↔ QuickTime content.identifier）保持不变。

几个 ImageIO 的坑，改动这部分代码时要注意：

- 有理数（光圈、焦距、快门、曝光补偿、海拔）写入 XMP 时必须用 `"n/d"` 字符串，否则会被截断成整数。
- HEIC 必须用“完整复制源元数据 + merge=false”，merge=true 时已有标签的新值会被忽略。
- ISO 要同时写 `exif:ISOSpeedRatings` 和 `exifEX:PhotographicSensitivity`；闪光灯在 XMP 中是结构体。
- MakerNote 不在 XMP 标签树里，清除方式是新建空元数据再复制全部标签。
- 无损路径下 MakerNote 只能整体保留或整体删除；重新编码时才能只保留实况配对编号（key 17）。

## 设备预设

`Resources/Devices.json` 由 `tools/build_devices.py` 生成，改数据后重新运行：

```bash
python3 tools/build_devices.py
```

数据来源（按优先级）：

1. **GSMArena 评测原图**：只读取文件头部的 EXIF（HTTP Range 请求），得到真机写入的 LensModel、焦距、光圈、等效焦距和像素尺寸。覆盖 iPhone 7 – 17 系列。
2. **ExploreCams**：按真机 EXIF 的 LensModel 建立的索引，主要用于老机型和 iPad 的镜头名。
3. **Wikimedia Commons**：“Taken with …”分类下真机照片的 EXIF 统计（焦距、光圈、等效焦距）。
4. Apple 官方技术规格：只用来旁证光圈和像素，不作为焦距来源。

规则：只有该机型本身有真机 EXIF 时才视为确认；同代同模组推断、按规格推算的一律标 `estimated`，App 里显示“估算”。
前置镜头名按现在 iOS 的写法：带面容 ID 的机型为 `front TrueDepth camera`（16e 例外），iPad Pro 同样处理（按 iPhone 规律推断）。

## 官网

本地预览：

```bash
php -S 127.0.0.1:8098 -t web tools/dev-router.php
```

打部署包：

```bash
tools/package-site.sh
```

部署步骤见 [deploy/部署说明.md](deploy/部署说明.md)，网站结构和内容维护见 [docs/网站说明.md](docs/网站说明.md)。

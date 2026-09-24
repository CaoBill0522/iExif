<?php
/** 全站文案。新增语言时复制一份并翻译即可。 */
return [

'zh' => [
    'locale' => 'zh-Hans',
    'nav_features' => '功能',
    'nav_shots' => '截图',
    'nav_support' => '技术支持',
    'nav_privacy' => '隐私政策',
    'download' => '在 App Store 下载',

    'hero_title' => '照片的拍摄信息，随你修改',
    'hero_sub' => '机型、镜头、光圈、快门、时间、地点，全部可改。内置 96 款苹果设备的镜头预设，无损写入，照片在本机处理，无需注册账号。',
    'hero_badges' => ['iPhone 与 iPad', 'iOS 17 及以上', '简体中文 / English', '无需注册'],

    'features_title' => '主要功能',
    'features_sub' => '为“把照片信息改对”这件事，做了完整的一套工具。',
    'features' => [
        ['device', '96 款设备镜头预设', '从 iPhone 4 到最新机型，iPad 从第二代到最新款，覆盖超广角、主摄、长焦和前置。选中即自动填好品牌、型号、镜头型号、光圈和焦距。'],
        ['shield', '无损修改', '只改写元数据，图像数据原样保留，画质分毫不变。支持 JPEG、HEIC 和 PNG。'],
        ['live', '实况照片不丢失', '保存后仍然是实况照片，视频一起保留，视频里的拍摄时间、地点和机型也会同步更新。'],
        ['map', '地图选点', '点选、搜地名、用当前位置，或直接输入经纬度。中国大陆自动处理地图与 GPS 的坐标偏差。'],
        ['batch', '批量修改', '一次最多 100 张。横向滑动快速多选，拍摄时间支持整体平移，保留照片原有的先后顺序。'],
        ['lock', '本机处理', '照片编辑在本机完成，无需账号。我们不运行照片上传服务，也不嵌入广告或第三方追踪工具。'],
    ],

    'more_title' => '还有这些细节',
    'more' => [
        ['长按预览', '长按任意照片放大查看，实况照片自动播放，并带有震动反馈。'],
        ['参数模板', '把常用的机型、镜头、版权信息存成模板，单张或批量一键套用。'],
        ['只改相册信息', '只修改“照片”App 显示的时间和地点，不生成新照片。'],
        ['自动转换格式', '按所选机型输出 HEIC 或 JPEG，也可以匹配该机型相机的分辨率。'],
        ['从“文件”导入', '除了相册，也能直接编辑 iCloud 云盘或其他位置里的图片。'],
        ['中英双语', '界面支持简体中文和英文，跟随系统语言。'],
    ],

    'shots_title' => '界面一览',
    'shots_sub' => '实际界面截图，支持浅色与深色模式。手机上左右滑动查看，点击可放大。',
    'shots' => [
        ['1_library', '浏览整个图库', '直接显示相册里的全部照片和相簿分类'],
        ['4_lens', '选择机型和镜头', '数据取自真机照片的 EXIF'],
        ['5_datetime', '改时间，也改地点', '精确到秒，地图上选择拍摄地点'],
        ['8_select', '横向滑动批量选择', '一次最多修改 100 张'],
        ['7_save', '保存选项清晰可见', '输出格式和分辨率一目了然'],
        ['2_editor', '完整的拍摄参数', '快门、ISO、曝光补偿、测光、闪光灯、白平衡'],
    ],
    'ipad_title' => 'iPad 同样适用',
    'ipad_sub' => '为大屏幕留出更多空间。用同一个 App，在 iPhone 和 iPad 上整理照片信息。',

    'detail_title' => '可以修改哪些信息',
    'details' => [
        ['设备', '品牌、型号、系统版本'],
        ['镜头', '镜头品牌、镜头型号、光圈、焦距、等效焦距'],
        ['拍摄参数', '快门速度、ISO、曝光补偿、测光模式、闪光灯、白平衡'],
        ['时间', '拍摄时间与时区，精确到秒'],
        ['位置', '经纬度、海拔、拍摄朝向'],
        ['版权', '作者、版权、图片描述'],
    ],

    'data_title' => '预设数据从哪来',
    'data_body' => '镜头预设里的焦距、光圈和镜头型号，优先取自真机照片的 EXIF 统计，包括镜头型号的完整写法。少数刚发布的机型和部分 iPad 前置镜头暂时找不到公开的真机原图，这些按官方规格推算，并在 App 中明确标注“估算”，不会让你误以为是实拍数据。',

    'cta_title' => '现在就去 App Store 下载',
    'cta_sub' => '适用于 iPhone 与 iPad。下载与价格以 App Store 为准。',

    'footer_note' => 'iExif 与 Apple Inc. 无隶属关系。Apple 和 Apple 标志是 Apple Inc. 在美国及其他国家和地区注册的商标。App Store 是 Apple Inc. 的服务商标。',
    'updated' => '最后更新',

    // 隐私政策
    'privacy_title' => '隐私政策',
    'privacy_lead' => '照片编辑在设备本机完成。我们不运行照片上传服务，不提供账号系统，也不嵌入广告或第三方分析工具。',
    'privacy_sections' => [
        ['我们不收集任何信息', '我们不会通过 App 的编辑功能收集或上传你的照片和元数据。App 没有账号系统，不含广告，不含任何第三方统计或分析工具。'],
        ['Apple 系统服务', '元数据编辑在本机完成。地图显示和地点搜索可能连接 Apple 的地图服务；下载 iCloud 照片、系统同步和你主动分享或导出照片，也可能通过相关系统服务传输数据。这些服务遵循其提供方的隐私政策。地图选定的坐标可用于填写照片位置。'],
        ['照片权限', '用于读取照片的拍摄信息，以及把修改后的照片保存到相册。选择“另存并删除原图”时，删除由系统弹窗确认，被删除的照片会进入“最近删除”，30 天内可恢复。拒绝该权限后，你仍可以从“文件”导入照片进行编辑。'],
        ['位置权限', '仅在你主动点击“使用当前位置”时获取一次当前位置，用于填写照片的拍摄地点。该位置只写入你选择的照片，不会被上传或记录。'],
        ['本机存储的内容', 'App 只在设备本机保存你的偏好设置（例如默认保存方式）和你创建的参数模板。删除 App 时一并删除。'],
        ['儿童隐私', 'iExif 不收集任何数据，因此也不会收集儿童的个人信息。'],
        ['网站与技术支持', '本网站仅使用语言偏好 Cookie（最长一年），没有统计或广告脚本。托管服务器可能保留 IP 地址、请求时间等访问日志用于运维与安全。你主动发来的支持邮件及附件用于回复和排查问题，仅在处理问题所需期间保留；可以通过支持渠道提出删除请求。'],
        ['政策变更', '若本政策有更新，将在本页面公布修改后的内容与更新日期。'],
    ],
    'privacy_contact' => '有任何疑问，请来信：',

    // 技术支持
    'support_title' => '技术支持',
    'support_lead' => '常见问题都在下面。没有找到答案的话，欢迎直接来信，我会尽快回复。',
    'faq' => [
        ['保存后在相册里找不到新照片？', '新照片会按它的“拍摄时间”排进相册。如果你把时间改到了过去，它就会出现在那一天的位置，而不是相册最底部。可以在“照片”App 里按日期找，或者打开“最近添加”相簿，它一定在最前面。'],
        ['App 里只显示了部分照片？', '说明你当时只允许访问部分照片。在图库顶部点“管理”可以追加，或者到“设置 → iExif → 照片”改成“完全访问”。拒绝访问时，也可以点左上角的文件夹图标，从“文件”App 导入照片。'],
        ['修改后原来的照片会被改掉吗？', '不会。保存时会生成一张新照片，原图默认保留。如果你在“保存方式”里选择“另存并删除原图”，系统会弹窗让你确认，删除的照片会进入“最近删除”，30 天内都能恢复。'],
        ['修改会让画质变差吗？', '默认不会。只改写元数据时，图像数据原样保留，画质分毫不变。只有当你更换输出格式（例如 JPEG 转 HEIC）或打开“匹配机型分辨率”时，图像才会以 90% 质量重新编码，界面上会提前说明。'],
        ['实况照片还能保持实况吗？', '可以。保存时视频部分一起保留，视频里的拍摄时间、地点和机型也会同步更新。需要注意：实况照片的配对信息保存在 MakerNote 中，因此在无损保存时即使勾选了“清除 MakerNote”，App 也会保留它，否则实况会失效。'],
        ['为什么有的镜头标着“估算”？', '预设中的焦距、光圈和镜头型号都来自真机照片的 EXIF。个别机型（主要是刚发布的新机型和部分 iPad 前置镜头）暂时找不到公开的真机原图，这些数据按官方规格推算，因此标注“估算”。等有了真机样片会在后续版本更新。'],
        ['“仅修改相册中的时间和位置”是什么意思？', '它只修改“照片”App 中显示的时间和地点，不生成新照片，文件内部的 EXIF 保持不变。适合只想让照片在相册里按正确时间排序的情况。之后把照片导出时，看到的仍是原来的信息。'],
        ['为什么在中国大陆选的位置和实际地点对得上？', '中国大陆地图使用 GCJ-02 坐标系，而照片里保存的是 GPS（WGS-84）坐标，直接使用会差几百米。iExif 会自动换算，所以你在地图上选的位置和写进照片的坐标是一致的。'],
        ['一次能修改多少张照片？', '最多 100 张。在图库中点“选择”后，横向滑过照片即可快速多选。批量修改时，每个字段可以单独决定改不改，拍摄时间还支持整体平移。'],
        ['支持哪些格式？', 'JPEG、HEIC 和 PNG。ProRAW（DNG）暂不支持。'],
        ['参数模板怎么用？', '在编辑页点右上角“更多 → 存为模板”，勾选想保存的字段即可。之后在单张编辑或批量修改里点“应用模板”一键套用，也可以在底栏“参数模板”里新建、修改和删除。'],
        ['怎么再看一遍功能介绍？', '打开“设置”页，点“功能介绍”即可随时重新查看。'],
        ['照片会被上传吗？', 'iExif 不会将照片上传到开发者服务器。编辑在本机完成；iCloud、地图和你主动分享的内容由对应系统服务处理。'],
    ],
    'support_contact_title' => '联系我们',
    'support_contact_body' => '问题反馈、功能建议，或者发现镜头数据有误，都欢迎来信。排查问题不需要原图；如果你愿意帮忙完善新机型的预设数据，可以用邮件附件发送一张不含个人信息的原图（不要经聊天软件转发，会丢失 EXIF）。',
    'support_mail' => '发送邮件',
],

'en' => [
    'locale' => 'en',
    'nav_features' => 'Features',
    'nav_shots' => 'Screenshots',
    'nav_support' => 'Support',
    'nav_privacy' => 'Privacy',
    'download' => 'Download on the App Store',

    'hero_title' => 'Your photo’s capture info, your way',
    'hero_sub' => 'Change the device, lens, aperture, shutter speed, date and place. Presets for 96 Apple devices, lossless metadata editing, with no account required.',
    'hero_badges' => ['iPhone & iPad', 'iOS 17 or later', 'English / 简体中文', 'No account required'],

    'features_title' => 'What it does',
    'features_sub' => 'Everything you need to get a photo’s metadata right.',
    'features' => [
        ['device', 'Presets for 96 devices', 'From iPhone 4 to the latest models, and iPad 2 to the newest iPads — every ultra wide, main, telephoto and front camera. Pick one and the make, model, lens model, aperture and focal length fill in for you.'],
        ['shield', 'Lossless editing', 'Only the metadata is rewritten. Image data is untouched, so quality is identical. JPEG, HEIC and PNG are supported.'],
        ['live', 'Live Photos stay live', 'The video is saved alongside the photo, and its date, location and device info are updated to match.'],
        ['map', 'Map picker', 'Tap the map, search a place, use your current location, or type coordinates. In mainland China the map/GPS coordinate offset is handled automatically.'],
        ['batch', 'Batch editing', 'Up to 100 photos at once. Swipe sideways to select quickly, and shift dates together so the original order is kept.'],
        ['lock', 'Runs on your device', 'Edit locally without an account. We operate no photo upload service and include no ads or third-party trackers.'],
    ],

    'more_title' => 'And the details',
    'more' => [
        ['Touch and hold to preview', 'See any photo larger with haptic feedback. Live Photos play.'],
        ['Templates', 'Save a device, lens or copyright setup and apply it to one photo or many.'],
        ['Photos-only edits', 'Change just the date and place Photos shows, without making a copy.'],
        ['Format conversion', 'Save as HEIC or JPEG to match the chosen device, and match its camera resolution if you like.'],
        ['Import from Files', 'Edit images from iCloud Drive or anywhere else, not just your library.'],
        ['Two languages', 'English and Simplified Chinese, following your system language.'],
    ],

    'shots_title' => 'A look inside',
    'shots_sub' => 'Real screenshots, in light and dark mode. Swipe on mobile to explore; tap to enlarge.',
    'shots' => [
        ['1_library', 'Browse your library', 'Your whole photo library and albums, right in the app'],
        ['4_lens', 'Pick a device and lens', 'Values taken from real photos’ EXIF'],
        ['5_datetime', 'Change date and place', 'Down to the second, with a map picker'],
        ['8_select', 'Swipe to select many', 'Edit up to 100 photos at once'],
        ['7_save', 'Clear save options', 'See the output format and size before saving'],
        ['2_editor', 'Full exposure settings', 'Shutter, ISO, compensation, metering, flash, white balance'],
    ],
    'ipad_title' => 'Made for iPad too',
    'ipad_sub' => 'More room for every detail. The same familiar tools, on iPhone and iPad.',

    'detail_title' => 'What you can change',
    'details' => [
        ['Device', 'Make, model, software version'],
        ['Lens', 'Lens make, lens model, aperture, focal length, 35mm equivalent'],
        ['Exposure', 'Shutter speed, ISO, exposure compensation, metering, flash, white balance'],
        ['Date', 'Date taken and time zone, to the second'],
        ['Location', 'Latitude, longitude, altitude, direction'],
        ['Rights', 'Artist, copyright, description'],
    ],

    'data_title' => 'Where the preset data comes from',
    'data_body' => 'Focal lengths, apertures and lens model strings are primarily sourced from the EXIF of real photos taken with those devices, including the exact wording of each lens model. A few brand-new models and some iPad front cameras have no public original sample yet; those values are derived from published specs and are clearly marked “Estimated” inside the app, so you always know what is measured and what is not.',

    'cta_title' => 'Get it on the App Store',
    'cta_sub' => 'For iPhone and iPad. See the App Store for current pricing.',

    'footer_note' => 'iExif is not affiliated with Apple Inc. Apple and the Apple logo are trademarks of Apple Inc., registered in the U.S. and other countries and regions. App Store is a service mark of Apple Inc.',
    'updated' => 'Last updated',

    'privacy_title' => 'Privacy Policy',
    'privacy_lead' => 'Photo editing happens on your device. We operate no photo upload service, account system, advertising or third-party analytics.',
    'privacy_sections' => [
        ['We collect nothing', 'We do not collect or upload your photos or metadata through the editing features. There is no account system, no advertising and no third-party analytics or tracking of any kind.'],
        ['Apple system services', 'Metadata editing is local. Maps and place searches may connect to Apple services. Downloading iCloud photos, system synchronization and sharing or exporting you initiate may transfer data through the relevant providers, under their privacy policies. Coordinates selected on the map can be used to fill in photo locations.'],
        ['Photo library access', 'Used to read a photo’s capture information and to save edited copies. If you choose “Save & Delete Original”, iOS asks you to confirm and the photo goes to Recently Deleted for 30 days. If you decline this permission, you can still import photos from the Files app.'],
        ['Location access', 'Used only when you tap “Current Location”, to fill in where a photo was taken. The coordinates are written only into the photo you chose; nothing is uploaded or logged.'],
        ['Stored on your device', 'The app stores only your preferences (such as the default save mode) and any templates you create, all locally. Deleting the app removes them.'],
        ['Children’s privacy', 'Since iExif collects no data at all, it collects no information from children.'],
        ['Website and support', 'This website uses a language preference cookie for up to one year and includes no analytics or advertising scripts. The hosting server may retain access logs such as IP addresses and request times for operations and security. Support emails and attachments you send are used to respond and troubleshoot, retained only as needed for that purpose. You may request deletion through the support channel.'],
        ['Changes to this policy', 'If this policy changes, the updated version and its date will be posted on this page.'],
    ],
    'privacy_contact' => 'Questions? Email:',

    'support_title' => 'Support',
    'support_lead' => 'Common questions are answered below. If yours isn’t here, just send an email and I’ll get back to you.',
    'faq' => [
        ['I can’t find my saved photo in the library.', 'The new photo is placed in your library by its date taken. If you moved the date into the past, it appears on that day rather than at the bottom. Look it up by date in Photos, or open the Recently Added album, where it will be first.'],
        ['The app shows only some of my photos.', 'You allowed access to selected photos only. Tap Manage at the top of the library to add more, or go to Settings › iExif › Photos and choose Full Access. Without access, you can still tap the folder icon to import from the Files app.'],
        ['Does editing change my original photo?', 'No. Saving creates a new photo and keeps the original. If you pick “Save & Delete Original”, iOS asks you to confirm, and the original goes to Recently Deleted where it stays for 30 days.'],
        ['Does editing reduce image quality?', 'Not by default. When only metadata changes, image data is untouched and quality is identical. The image is re-encoded at 90% quality only if you change the output format (say JPEG to HEIC) or turn on “Match Device Resolution” — and the app tells you beforehand.'],
        ['Do Live Photos stay live?', 'Yes. The video is saved alongside the photo, and its date, location and device info are updated to match. One note: the pairing ID lives inside MakerNote, so during a lossless save the app keeps MakerNote even if “Remove MakerNote” is on — otherwise the Live Photo would break.'],
        ['Why are some lenses marked “Estimated”?', 'Focal lengths, apertures and lens model strings come from the EXIF of real photos. For a few devices — mostly brand-new models and some iPad front cameras — no original sample is publicly available yet, so those values are derived from published specs and clearly marked. They are updated once real samples appear.'],
        ['What does “Edit Date & Location in Photos Only” do?', 'It changes only what the Photos app displays. No new photo is created and the EXIF inside the file stays the same, so exporting the file later still shows the original values.'],
        ['Why do map pins match the real place in mainland China?', 'Maps in mainland China use the GCJ-02 coordinate system while photos store GPS (WGS-84) coordinates, which differ by a few hundred metres. iExif converts between them automatically.'],
        ['How many photos can I edit at once?', 'Up to 100. Tap Select in the library, then swipe sideways across photos to select quickly. In batch editing each field can be turned on individually, and dates can be shifted together.'],
        ['Which formats are supported?', 'JPEG, HEIC and PNG. ProRAW (DNG) isn’t supported yet.'],
        ['How do templates work?', 'While editing, tap More › Save as Template and pick the fields to keep. Then use Apply Template in single or batch editing, or manage templates in the Templates tab.'],
        ['How do I see the feature tour again?', 'Open the Settings tab and tap Feature Tour.'],
        ['Are my photos uploaded anywhere?', 'iExif does not upload photos to developer servers. Editing is local; iCloud, Maps and sharing you initiate are handled by the relevant system services.'],
    ],
    'support_contact_title' => 'Contact',
    'support_contact_body' => 'Bug reports, feature requests, or corrections to the lens data are all welcome. Troubleshooting never needs your original photos. If you’d like to help improve the presets for a new device, you can attach one original photo with no personal content to an email — don’t forward it through a messaging app, which strips EXIF.',
    'support_mail' => 'Send an email',
],

];

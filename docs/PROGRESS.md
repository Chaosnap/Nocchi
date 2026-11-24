# 进度看板（实时更新）

> 最后更新：2026-11-24（3.0.0、3.1.0 已发；4.0.0：装饰台拖动跟手）· 分支 `main`（直接在 main 开发）
> 每次推送都会同步更新本页。构建产物见 [Actions](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml)。

## 一眼看懂

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 仓库与 CI | 🟢 已搭好 | 直接在 `main` 开发；NocchiKit 测试与 macOS 构建在 GitHub Actions 上跑；推送 `v*` 标签自动发行版本 |
| NocchiKit（共享暗房内核） | 🟢 CI 全绿 | 调色引擎 v2（曲线、HSL、肤色保护、高光软肩）+ 26 卷胶卷；相册检索 / 胶片条 / 挂历分组 |
| macOS App（刘海出片口） | 🟢 v4.0.0 已发布 | [Releases](https://github.com/Chaosnap/Nocchi/releases/latest)：`Nocchi-macOS-4.0.0.zip` + `SHA256SUMS.txt`（AGPL-3.0）。同一天发了 3.0.0（自拍闪退、大头贴机第一次进入卡）、3.1.0（软木板白天 / 黑夜灯光、挂历叠放、零警告）、4.0.0（装饰台拖动跟手、去掉窗格） |
| iOS App（灵动岛出片口） | 🔵 编写中 | 分层建模相机、灵动岛出片、Live Activity |
| 美术素材 | 🟢 第三版 | 复古机身、大头贴机、纹理（象牙白 + 炭黑 + 陶土橙）；**App 图标第三稿**：复古旁轴式即显相机 + 做旧毛边相纸（不出画框），胡桃木圆角瓷砖，CI 渲染各尺寸；80 年代方盒款机身已入库备用 |
| 照片卡片盒（2.5D） | 🟢 CI 全绿 | Blender 照参考图建模、Cycles 渲染（`CardBoxBase` / `CardBoxFront` + 热点），卡片从盒口升起、扇形摊开 |
| v0.2「复古冲印店」 | 🟢 全部完成，随 v1.0.0 发布 | 规范见 [DESIGN.md](DESIGN.md)；逐步进度见下面的「v0.2 改版进度」 |
| 产品文档站与截图 | 🟢 已上线 | <https://chaosnap.github.io/Nocchi/>（VitePress，英文 + `/zh/` 中文）；截图由 `screenshots.yml` 在 Actions 上从 App 渲染，提交到 `website/public/screenshots/` |
| 3.0 / 3.1 / 4.0 | 🟢 都已发布 | 见下面「交接 · 当前批次」 |
| 2.1 反馈（所有者 9 项 + 补充） | 🟢 全部做完，随 v2.1.0 发布 | 见下面「交接 · 上一批」：卡片空白、相机有不同效果、换相机按钮、图标阴影、卡片盒按年月日归档、中英文切换、关于页、自定义存储位置、「准备抽出来」动画、更精细的卡片和标签都已做并用截图验收；**相册「主程序被强制隐藏」是推断后修的，等所有者确认**；等所有者决定发不发 v2.1.0 |
| v2.0 打磨（所有者反馈） | 🟢 随 v2.0.0 发布 | 14 项（13 项已做）+ 文字框与自定义字体 + 自定义贴纸 + 不要滚动条；**正在做：剧院暗红布帘、机身整体建模、情人节相框**，见下面「交接」第 3 节 |
| 仓库与社区文件 | 🟢 已补齐 | GNU AGPL-3.0（与 Yohaku 一致）；英文的 README、行为准则（Contributor Covenant 3.0）、贡献指南、安全政策、隐私说明、Issue / PR 模板 |

图例：🟢 完成 · 🟡 进行中 / 待验证 · 🔵 编写中 · ⚪ 未开始 · 🔴 阻塞

## 交接 · 当前批次：3.0 与 2.5（2026-11-24 夜，下一位从这里接）

所有者原话（按先后）：
1. 「现在另外一个 ai 已经完成了 2.1，你能不能帮我完成 2.5 版本，就是对这个的光照系统添加更多的光照选择，可以选择白天和黑夜以及粒子度还有灯光位置，/Users/yuki/Desktop/Terminal，你可以参考我这个文件夹下的灯光引擎的实现，直接搬过来用，这个实现好了后作为 2.5 版本，其次这个 wall calender 的这个里面的相片摆放方式有点不好看啊，比如有多个的可以堆叠下，单个的想办法吧摆放方式弄好看点」（截图：软木板左下角的「Lighting」铜牌；挂历每天一张小方照片）。
2. 「其次优先解决为什么点击自拍有时程序会崩溃和点击大头贴时进入页面会很卡的问题，在不影响显示效果的情况下对进入大头贴页面优化性能，这个做完直接发布 3.0，再继续其他的」「这个点击自拍崩溃仅存在在这个里选择了大头贴机」「booth entry 只有第一次启动时会卡，能不能在进入软件后在后台准备」。

| # | 要什么 | 状态 | 文件 | 做法 / 说明 |
| --- | --- | --- | --- | --- |
| 1 | 点「自拍」偶尔闪退（装着大头贴机时） | 🟡 已改，等 CI；发 3.0.0 | `Capture/CameraService.swift`（`attachPreview`、`detachPreview`、`setPreviewMirroring`、`reapplyMirroring`、拍照前查视频连接）、`CameraPreview` / `PreviewView` | 本机 `~/Library/Logs/DiagnosticReports/Nocchi-*.ips` 四份崩溃报告都是：摄像头队列 `startRunning` →「Collection was mutated while being enumerated」，主线程同时在 `CameraPreview.makeNSView` 里 `addVideoPreviewLayer`。现在预览层的挂 / 摘 / 镜像都在摄像头队列上（决策 D40）。所有者猜的「刘海选了没同步到设置的相机柜」查过：三处都读写 `AppModel.bodyID`，是同步的，不是原因 |
| 2 | 第一次进大头贴机卡（不改画面） | 🟡 已改，等 CI；发 3.0.0 | 新 `Booth/BoothWarmup.swift`（`BoothWarmup`、`BoothArt`、`BoothArtCache`）、`Booth/CurtainScene.swift`（一个可复用的 `SCNView`、`prepare`、`suspend`、同一屏幕不重搭）、`Booth/PhotoBoothController.swift`（`prepareCurtain`、`prewarmPreviews`、离开时样张不丢、`curtainGap`）、`Booth/BoothMachine.swift`（图都走 `BoothArt.image`）、`App/TemplatePreviews.swift`（`prefetch` 可传优先级）、`App/NocchiMacApp.swift`（启动 2.5 秒后 `BoothWarmup.schedule()`） | 启动后在后台：SceneKit 编译布帘着色器 + 上传纹理、解码整机和零件大图、合成默认相框的一圈样张、合成声音；之后一直留着 |
| 3 | 发 3.0.0 | 🟢 CI 第 66 次运行绿，已推 `v3.0.0` 标签（`bce9336`），`release.yml` 出 Release | `macOS/project.yml`、`CHANGELOG.md`（`## [3.0.0]`）、README、文档站两个更新日志 | |
| 4 | 软木板灯光：白天 / 黑夜、粒子（光里的灰尘）、灯的位置，搬 Terminal 的灯光引擎 | 🟢 随 v3.1.0 发布（Screenshots 第 33、34 次验收）。原记录：等 CI 和 Screenshots（`album-corkboard.jpg` 白天、新的 `album-corkboard-night.jpg` 夜里台灯、`album-corkboard-lighting.jpg` 打开的卡片；英文在 `en/`）；看过图就发 3.1.0 | 新 `NocchiKit/Lighting/LightModel.swift` + `LightModelTests`；`Album/CorkLighting.swift`（`CorkLighting` 加 `time`、`source`、`lightX/Y`、`reach`、`particles`，2.x 的 `angle` 换算成位置；`CorkLightOverlay`、`CorkLightMaps`、`DustMotes`；两栏的 `LightingPanel`：`TimeSwitch`、`SourceChips`、`LightPad`）；`Album/CorkBoardView.swift`（光照盖在照片上面、`CorkShowcase`）；`Screenshots/ScreenshotStudio.swift`；决策 D41 | 参考 `/Users/yuki/Desktop/Terminal/app/nocturne/light-model.ts`（光源：台灯 / 月光窗；平方反比 + 朗伯余弦 + 软边光锥；窗格投影 `windowGobo`；曝光 `1 − e^(−E)`）、`lighting-math.ts`、`lib/nocturne/lighting/glow-layer.ts`（光池 + 泛光 + 110 粒灰尘，每粒按光模型点亮）、`paper-light.ts`（GLSL，乘法叠加）。Typewriter Nocturne 是 MIT（所有者自己的项目），搬过来要在文件头注明来源和许可 | 计划：NocchiKit 新增 `LightModel`（移植 light-model.ts，单元测试）；软木板上在 CPU 按低分辨率（约 240 列）算光照图（乘法层 = 环境光 + 灯光，屏幕层 = 光池 + 泛光），盖在照片上面（照片也被同一盏灯照着），灰尘用 `TimelineView` + `Canvas`（30 帧）；白天 = 窗光（暖白、窗格投影、环境亮），黑夜 = 台灯（钨丝暖光、光池外暗下去）或月光（冷蓝窗格）；「灯光」卡片加：白天 / 黑夜、光源、位置（小板子上拖铜钮）、范围、粒子；照片阴影方向跟着灯的位置。不用 Metal 着色器（CI 上 Xcode 26 的 Metal 工具链要单独下载，避开） |
| 5 | 挂历里的照片：多张叠成一小摞，单张摆得更好看 | 🟢 随 v3.1.0 发布（Screenshots 第 34 次：一天三张叠成一摞、「×3」） | `Album/CalendarWallView.swift`（`DayPhotos`、`MiniPrint`、`WashiTape`、`CountStamp`；删掉了 `CornerPhoto`、`PhotoCorners`） | 计划：一天多张时最多叠 3 张小相片（后面的错开、转不同角度），超过 3 张角上盖一个红色小章「×5」；单张做成带白边的小相片，用一小段和纸胶带贴在日期数字右边，按 seed 歪一点，柔和阴影 |

| 6 | 所有者贴了 CI 日志：「你之前的运行测试有这个问题」（`WindowClip` 存 `CGPath` 的 Sendable 警告） | 🟢 CI 第 68 次运行零警告（Node 20 的提示也没了），随 v3.1.0 发布 | `NocchiUI/Print/PrintSurface.swift`（`WindowClip` 存 `Path`）、`Notch/NotchController.swift`、`Notch/FilmCabinetPanel.swift`、`Booth/PhotoBoothController.swift`（按键 / 滚轮监听：`assumeIsolated` 只返回 Bool）、`Photo/PhotoWindowController.swift`（`menu(for:)` 直接返回）、`.github/workflows/*.yml`（checkout / upload-artifact / setup-node v7，configure-pages v6，upload-pages-artifact / deploy-pages v5） | CI 第 66、67 次运行的注解里就这几条（另有 Node 20 过时）；`swift test` 那一步的日志要登录才能下载，看不到全部，如果所有者还看到别的警告再补 |

| 7 | 装饰台：贴纸移动、旋转不顺；文字框缩放、旋转不顺，「修复下，作为 4.0 release」 | 🟢 CI 第 69 次运行绿（零警告），已发 v4.0.0（Release 第 8 次运行）；手感要所有者试 | `Editor/PaperStage.swift`（`StickerItem`、`TextItem` 用 `LiveTransform` + `HandleDrag`，松手 `commit()`；`TextImageCache` 按内容为键、缓存排版尺寸）、版本 4.0.0、`CHANGELOG.md`、README、两个更新日志、决策 D42 | 截图拍不到拖动的手感，要所有者试；按住 ⇧ 旋转每 15° 一格是新加的。所有者又说「这个窗户田字格删掉」：软木板的阳光 / 月光光斑不再画窗棂（`LightPlacement.windowBars` 默认关，`LightModel` 里的窗棂留作选项），一起进 4.0.0 |

**版本号**：灯光和挂历原本要作为「2.5」，但所有者又要先把闪退和卡顿发成 3.0，所以这一批发成 **3.1.0**（版本号不能往回走）。`macOS/project.yml`、`CHANGELOG.md`（`## [3.1.0]`）、README、两个更新日志已经写好；CI 绿、截图看过就推 `v3.1.0`。

## 交接 · 上一批：2.1 反馈（2026-11-24 晚，已随 v2.1.0 发布）

**先读**：根目录 `CLAUDE.md`（只在 GitHub Actions 上构建，本机不编译不测试）、[DESIGN.md](DESIGN.md)。审美：复古（不要手绘风）、精致、能建模的用 Blender、阴影连贯柔和。用量快不够时：先更新本节、提交并推送。

所有者原话：「有时这个取出来时会空白，其次这个选择相机这个可以在大头贴那产生不一样的效果，还有为什么现在一进灵动岛那个相册那主程序就会被强制隐藏，麻烦把换相机放到换胶卷右边，还有你看顶部的这个小的图标阴影也被强制截断了不好看，这个卡片盒那，能不能在+那右边添加一个齿轮设置按钮，可以切换不是按首字母，而是按年，月，日这种支持检索，卡片盒上的标签也会随设置变化，修改这个，并使这个应用支持中英文切换，默认中文，还有关于里去掉这句话，其次储存位置可以自定义要求」

| # | 要什么 | 状态 | 文件 | 做法 / 说明 |
| --- | --- | --- | --- | --- |
| 1 | 卡片盒抽出来的卡片有时是空白（中间一个转圈） | 🟢 CI 绿（偶发问题，截图里看不出来，等所有者用一阵确认） | `NocchiUI/CardBoxModel.swift` | 原因：卡片的图只在第一次露面时读；照片记录变了（成片刚印好、装饰过）图被清掉却不再读；读失败也不重试。修：按「版本」（`editedAt`、`printFile`、底片张数）读图，摊在桌上的卡片当场重读（旧图先留着，新图到了再换），读不到就退避重试（0.6 秒起，最多 5 次） |
| 2 | 选相机要有不同效果（大头贴机） | 🟢 CI 绿（实际拍出来的效果等所有者试） | `App/AppModel.swift`（`shootsBooth`、`cycleBody`、`boothSetup`、`cyclePaper`、`shootingStock`、`shootingFormat`）、`Darkroom/Darkroom.swift`（`boothScreenShutter`、`takeBoothSelfie`、`developImported` 分批、`developDroppedFiles`）、`Notch/NotchController.swift`（`boothShot`、拖放先收齐再冲印）、`Notch/NotchRootView.swift`（自拍取景器的标题）、`App/MenuContent.swift`、`Settings/SettingsView.swift`（相机柜下面的说明） | 装着大头贴机时：自拍在取景器里连拍四张（每张前倒数、白屏闪光）、屏幕快门框选四次、冲印照片和拖到刘海的图每四张拼一条（不够四张循环补满），用大头贴机的版式、相框、黑白设置；「大头贴」按钮仍是拉帘子的完整版；接管系统截图仍按即显冲印 |
| 3 | 从刘海进相册时「主程序被强制隐藏」 | 🟡 推断后修，**等所有者确认** | `Settings/WindowManager.swift`（`followActiveSpace`、`bringForward`）、`Editor/DecorateDesk.swift`、`Import/PhotoImport.swift` | 代码里没有任何隐藏窗口的调用。推断：2.0 起启动时就打开相册，窗口留在当时的桌面空间；之后在别的空间或全屏 App 里从刘海点「相册」，macOS 会切到那个空间，看起来就像正在用的 App 被藏起来了。修：相册、设置、装饰台、照片选择器窗口加 `.moveToActiveSpace` + `.fullScreenAuxiliary`（出现在当前空间、能浮在全屏 App 上），最小化的先还原，`orderFrontRegardless` 保证在最前。若所有者说的是别的现象，问清楚再改 |
| 4 | 「换相机」放到「换胶卷」右边 | 🟢 CI 绿，截图 `notch-panel.jpg` 已验收 | `Notch/NotchRootView.swift`（`CameraTileButton`、`CameraBodyArt`）、`Notch/NotchController.swift`（悬停面板宽 +84） | 机身小图 + 「换相机」+ 机身名，点一下换下一台；装着大头贴机时胶卷罐显示大头贴机用的胶卷，「相纸」小卡切换四格条 / 四宫格 |
| 5 | 相册顶部四个小图标的阴影被截断 | 🟢 CI 绿，截图里阴影完整、自然淡出 | `design/blender/icons/make_icons.py`（`PAD = 0.22`、`ANCHOR`、`fade_shadow_edges`）、`Album/AlbumHeader.swift`（`ModeIcon.overscan = 1.5`） | 原因：渲染时机位贴着物体（留边 8%），阴影跑出画布被截成直角。现在四周留足地方、阴影在画布边之前淡到透明；App 里放大 1.5 倍画、布局仍占原来的格子 |
| 6 | 卡片盒：「＋」右边加齿轮，按首字母 / 年 / 月 / 日归档，分隔卡标签跟着变，能按日期检索 | 🟢 CI 绿，Screenshots 第 25、27 次验收（标签上的字印在标签面上） | `NocchiKit/Library/CardIndex.swift`（+ 测试 `CardIndexTests`）、`NocchiKit/Support/UILanguage.swift`、`NocchiUI/CardBoxModel.swift`（`indexMode`、`index`、`pull(key:)`）、`NocchiUI/CardBox/CardBoxParts.swift`（`TabFace`、`TabLabels`、`TabHotspot`、`TabChip`、卡片小标签）、`CardBoxView.swift`、`CardBoxHotspots.swift`（重新生成）、`design/blender/cardbox/make_cardbox.py`（空白标签、导出标签面四角）、`Album/AlbumHeader.swift`（齿轮 `IndexModeButton`）、`Album/AlbumShared.swift`（卡片盒模型挪到 `AlbumRouter`）、`PhotoSearch`（英文月份）、`Screenshots/ScreenshotStudio.swift`（多拍一张按月归档） | 按「设计 6」做了，决策 D37。标签宽 2.8（原 2.3）、高 1.25 不变（试过 1.45：后一张标签的下沿被前一张挡住） |
| 7 | App 支持中英文切换，默认中文 | 🟢 CI 绿，英文截图逐张验收（Screenshots 第 27 次），第 53 次推送修了几处截断 | `App/AppLanguage.swift`（启动时写 `AppleLanguages`、设置里换语言 + 重新打开）、`Settings/SettingsView.swift`（通用 → 语言）、`Resources/en.lproj`（`Localizable.strings` 由脚本生成、`InfoPlist.strings`）、`Resources/zh-Hans.lproj`、`macOS/project.yml`（`CFBundleDevelopmentRegion` / `CFBundleLocalizations`）、`scripts/i18n/`（`strings.py`、`en.json` 563 条、`formats.json`、`extra.json`）、`NocchiKit/Support/UILanguage.swift`（`Localized.string`）、`FilmStock.localizedForEnglish`、`PhotoLibrary.monthTitle`、CI「Check translations」 | 按「设计 7」：中文原文就是键。`strings.py wrap` 把 417 处普通 String 里的中文包成 `String(localized:)`（跳过字典键、比较、case 模式、生成的文件、截图样片、搜索用的日期写法；故意不翻译的行标 `// i18n-ok`：贴纸图案上的字、标签规整、大头贴机热区的键）；SwiftUI 的 `Text("…")` 自己查表。`strings.py build` 生成英文表，`check`（CI）要求每个会查表的键都有英文、格式符一致。第 52 次推送：大头贴机英文版整机图 `BoothMachineEN`（`make_machine.py --english`：招牌 PHOTO BOOTH、刻字 STRIP / GRID、B&W / COLOUR、PRINTS、COIN，Futura 窄体粗体；零件和热区不变），`BoothMachine.baseImage` 按语言选；Screenshots 多拍一轮英文界面（`scripts/ci/render-screenshots.sh` 第二遍加 `-app.language en -AppleLanguages (en)`，图在 `website/public/screenshots/en/`）。第 53 次推送：逐张看英文截图验收，修了几处被截断的英文（设置里相机卡片的说明、胶卷柜的「Loaded」和张数、大头贴机橱窗的相框说明）、「摄像头」页英文叫 Webcam（不和相机柜 Cameras 混）、英文大头贴机的 COLOUR 等刻字挪到板边和拨杆头之间（`make_machine.py` 的 `english_labels`）；文档站英文页和 README 改用 `/screenshots/en/` 的图和英文界面上的叫法（`pages.yml` 的占位图也认 `en/` 子目录）。第 54 次推送：英文单复数（`Localizable.stringsdict`，见决策 D39） |
| 8 | 关于页删掉「机身、图标与纹理为原创设计（由 Codex 生成）……」 | 🟢 已改 | `Settings/SettingsView.swift`（`AboutTab`） | |
| 9 | 存储位置可以自定义 | 🟢 CI 绿（含 5 条单元测试） | `NocchiKit/Darkroom/PhotoLibrary.swift`（`printsRoot` 可变 + 锁、`relocatePrints(to:)`、`printFileCount()`，测试 `PrintsRelocationTests`）、`App/Services.swift`（`PrintsLocation`）、`Settings/StorageSettings.swift`（`StorageSection`）、`macOS/project.yml`（外接盘 / 网络盘的权限说明） | 按「设计 9」做：先改用新位置（之后的成片直接写过去）再按相对路径一个个搬，同名不覆盖（列出来），搬到一半出错就搬回来、改回原位置；搬空的月份文件夹删掉。选的文件夹叫 Nocchi 或是空的就直接用，否则在里面建「Nocchi」。启动时自定义位置所在的文件夹不存在（外接盘没插）就这次用默认位置、设置里提示，不在 /Volumes 下凭空建文件夹。决策 D38 |
| 11 | 所有者：参考站的卡片盒「建模更精细」——「不是说箱子不行，而是里面的书页和标签建模还不够精细」；可以把参考图下下来照着自己做一个 | 🟢 CI 绿，Screenshots 第 27 次验收（`album-cardbox.jpg`） | `design/blender/cardbox/make_cardbox.py`（`paper_sheet` 圆角卡纸、`paper_mat` 卡纸材质、`CARD_COLORS`、卡片更密更乱、回形针、白色塑料标签 2.0 cm）、`Packages/NocchiKit/Sources/NocchiUI/CardBox/CardBoxView.swift`（`SlotGeometry` 的标签位置比例跟着改）、`CardBoxHotspots.swift`（重新生成）、`CardBoxLift.swift`（`DividerPaper` 重新取色） | 参考图存在 `Ref_Image/shashage-archive/`（第三方作品，**不入库、不进 App**，只当参考）。木盒不动（所有者说箱子没问题）。卡片：圆角 + 厚度 + 细倒角、淡彩卡纸、在原来每两张之间再插一两张（单独的随机数，分隔卡和标签位置不变）、高低错落（分隔卡前面的卡按透视限高，不挡标签上印的字）、回形针。标签：2.0 × 1.25 cm 白色塑料插片（原来 2.8 cm 纸标签）。 |
| 12 | 所有者（发版前）：抽出来的卡片「中间这个照片是不是该直接放大到单个第二张图区域，再加上标签，感觉现在这个有点套娃」 | 🟡 已改，等 CI 和 Screenshots（看 `album-cardbox.jpg`：右边那一叠是成片本身、顶上插着白色塑料标签） | `NocchiUI/CardBox/CardBoxParts.swift`（`PhotoIndexCard`、`PrintTab`、`CardHitShape`）、`CardBoxView.swift`（传 `flatness`、`cardHelp`） | 卡片就是成片本身（`printFile`，白边、题字、贴纸都在上面），在卡片框（所有照片一样大，飞行和摊开的位置都按它算）里等比放到最大：立在格子里、被抽出来时贴着框的下沿（从格口里冒出来，不是悬在半空），摊开后居中（跟着 `flatness` 过渡）。标签换成和分隔卡同款的白色塑料插片（Futura），插在成片上沿后面 3 点；悬停、点击、拖动只认成片和标签（`contentShape`）。以前索引卡下半截的「日期 · 地点 · 胶卷」挪进悬停说明。 |
| 10 | 抽屉（卡片盒）取出来的效果参考 <https://shashage.de/what-we-borrow?entry=home> 的「准备取出来」动画 | 🟢 CI 绿，Screenshots 第 25、27 次验收（`album-cardbox-month.jpg`：第一格的分隔卡抬起一截） | `NocchiUI/CardBox/CardBoxLift.swift`（`DividerLift`、`FrontTabs`、`DividerPaper`）、`CardBoxView.swift`（`lift(_:)`、`peekSlot`）、`CardBoxParts.swift`（`TabHotspot.rise`、`TabLabels.occludedByFront`）、`design/blender/cardbox/sample_tab_paper.py` | 参考站的做法（`archive-interaction.js`）：悬停时那张分隔卡沿盒子竖直方向抬起约 4% 画高（0.19 秒），只画原来藏住的那截纸面 + 原图裁出的标签，前面的标签和盒子前半部分重新盖上；点击才把卡放到桌上。这里一样：沿标签面竖边抬 1.25 个标签高，纸面颜色取自渲染图（每张标签一个色），格口线以下用 `SlotMask` 挡住，前面的标签 `FrontTabs` 盖上；换一张时先放回再抬（代数计数防止动画回调打架）；热区补到抬满的位置。点击后沿用原来的抽卡动画（斜着抽出、转正、落到右边） |

**设计 6 · 卡片盒归档方式（已按此实现，留作说明）**
- NocchiKit 新增 `CardIndex`：`Mode`（首字母 / 年 / 月 / 日），把照片分进最多 27 格（盒子里有 27 张分隔卡）：首字母 = A–Z、#；年 = 有照片的年份，新的在前；月 = 有照片的年月，新的在前；日 = 有照片的日子，新的在前；放不下的进最后一格「更早」。每格有短标签（标签上印的：`2026`、`11月`、`11/24`）和完整标签（吊牌上的：`2026 年 11 月`）。单元测试。
- `CardBoxModel`：`indexMode`（UserDefaults 记住），`tabs`（每格的键、标签、张数），按格抽卡（现在是 `pull(letter:)`）。
- Blender：`design/blender/cardbox/make_cardbox.py` 重渲染 `CardBoxBase`，分隔卡标签不再烤进字母（空白标签），`hotspots.json` 加正确的标签正面四边形（现在的 `quad` 是错的：取的是底边前后四个点），重新生成 `CardBoxHotspots.swift`。
- `CardBoxView`：标签上的字由 SwiftUI 叠上去（沿分隔卡方向做仿射斜切，Futura 窄体），吊牌显示完整标签，卡片自己的小标签也显示所在格的短标签。
- `AlbumHeader`：「＋」右边一个黄铜齿轮钮，菜单里选归档方式（只影响卡片盒）。
- 检索：确认 `PhotoSearch` 能搜「2026」「2026-11」「11月」「11/24」这类日期。

**设计 7 · 中英文切换**
- 用 Apple 标准本地化：开发语言 zh-Hans，中文原文就是键；英文在 `macOS/Nocchi/Resources/en.lproj/Localizable.strings`（另放一个 `zh-Hans.lproj`，让简体中文算「可用语言」；`InfoPlist.strings` 翻译权限说明）。
- 切换：设置 → 通用 → 语言（简体中文 / English），写 `app.language` 和 Nocchi 自己域里的 `AppleLanguages`（与「系统设置 → 语言与地区 → App」同一个键），提示重新打开（一个小 shell 等本进程退出再 `open`）。默认中文：自定义 `@main` 入口在 NSApplication 启动前写好 `AppleLanguages`。
- 代码：SwiftUI 的字面量本来就是 `LocalizedStringKey`；String 类型的界面文字用 `String(localized:)`；NocchiKit 里显示给人看的名字（机身、相纸、模板、贴纸名、胶卷家族）返回本地化字符串；胶卷英文时显示 `englishName`，`FilmStocks.json` 加英文简介。
- 烤在渲染图里的中文：大头贴机招牌「大头贴机」和控制台「四格条 / 四宫格 / 黑白 / 彩色」→ `make_machine.py` 出英文版图（按语言选图）。
- 工具：`scripts/i18n/` 下写一个脚本列出所有中文字面量、检查每个键都有英文。验收：Screenshots 加一轮 `-AppleLanguages '(en)'` 的英文截图。

**设计 9 · 自定义存储位置**
- `PhotoLibrary.printsRoot` 改成可变（加锁），`relocatePrints(to:)` 把月份文件夹搬过去（成片记录里存的是相对路径，搬完照样能找到）；位置存在 UserDefaults `storage.printsRoot`，`Services` 启动时读。
- 设置 → 通用 → 存储：显示成片位置、「更改…」（选文件夹 → 确认搬过去）、「在访达中显示」、「恢复默认」；记录与底片仍在「应用程序支持」里。
- Info.plist 加 `NSRemovableVolumesUsageDescription`、`NSNetworkVolumesUsageDescription`（存到外接盘 / 网络盘时系统会问）。

## 交接 · 上一批（v2.0，已全部完成，留作记录）

仓库所有者的用量快用完了，要求把下面的事交给下一位 AI 接着做。**先读**：本页「交接须知」、[DESIGN.md](DESIGN.md)（视觉规范与跨模块接口）、根目录 `CLAUDE.md`（只在 GitHub Actions 上构建）。所有者的审美：复古（不要手绘风）、要精致高级、能用 Blender 建模的尽量建模、阴影一律连贯柔和（不能出现直角 / 割裂的阴影）。

现状：v1.0.0 已发布；文档站 <https://chaosnap.github.io/Nocchi/> 已上线（`website/`，`pages.yml`）；截图由 `screenshots.yml` 从 App 渲染并提交到 `website/public/screenshots/`——**改完界面就靠它验收**：推送后等 Screenshots 工作流提交新图，`git pull` 下来看图（见 [CI.md](CI.md#截图screenshots)）。

### 1. 🟢 已修（第 29 次推送）：冲印出来的照片偏暗、偏艳

**原因**：`applyHalation` 的光晕层 alpha = 1，`CIAdditionCompositing` 把 alpha 也加起来，照片从这一步出来 alpha = 2；之后的混合模式（颗粒的 `CISoftLightBlendMode` 等）按 Porter-Duff 公式多出一项 (1 − Da) = −1，在中性灰颗粒上约等于「原色 − 0.5」——中间调变黑、三通道同减一个数显得过艳；照相亭闪光（+0.5 EV，更亮）和没有光晕的黑白卷看起来没那么糟。**修复**：`FilmProcessor.flattened`（盖在不透明黑底上，rgb 不变、alpha 回到 1）用在光晕、柔焦之后和管线末尾；`XCTExpectFailure` 已删，新增 `FilmEffectsOpacityTests`（每个效果单独打开都保持不透明、不变暗）。以下是当时的排查记录。

- **现象**：截图里所有彩色胶卷的照片都偏暗、阴影压死、颜色过艳；离线预览 `scripts/film/preview_looks.py`（配方数学的 numpy 移植，用 Blender 自带的 Python 跑）是对的——明亮、奶油感。照相亭闪光 400（自带 +0.5 EV）和黑白看起来没那么糟。v1.0.0 冲出来的照片也受影响。
- **已排除：色调查表。** `FilmPipelineFidelityTests.testReportWhatTheOldColorCubeFilterDoes` 写出的 CI 注解：奶油 600 在 (153,140,128) 上，旧写法 `CIColorCubeWithColorSpace` = 170,158,143，现在的管线 = 170,158,143，配方 = 171,159,143。查表是对的（第 27 次推送把 `applyCube` 改成「显式转 sRGB → `CIColorCube` → 转回」，结果一样，留着无妨）。`testLUTStageMatchesTheRecipeOnFlatPatches`、`testNeutralStockLeavesTheImageAlone` 都通过。
- **线索：效果阶段。** `testFullPipelineKeepsTheBrightnessOfTheRecipe`：160 × 160 的平坦色块打开全部效果后，中间 40 × 40 的平均亮度是 **0.0**（奶油 600、人像 400、晚霞 200、薄荷 400、霓虹 800 全是），只查表时是对的。所以是 `FilmProcessor` 的效果之一（`applyHalation`、`applyBloom`、`applyEdgeSoftness`、`applyLightLeak`、`applyVignette`、`applyGrain`）把画面压黑或变透明。注意 `PixelBuffer` 读的是预乘 RGBA，alpha = 0 也会读成 0。这条测试现在用 `XCTExpectFailure` 标着（CI 保持绿），**修好后删掉那一行**。
- **下一步**：写一条诊断测试，一次只开一个效果、其余为 0，打印中心像素的 RGBA 和全图均值（`print("::notice title=…::…")` 会变成运行页面上的注解，同一步最多 10 条，合成一行），对比 160px 和 1200px，找出是哪一步；疑点：`CIAdditionCompositing` / `CISoftLightBlendMode` / `CIMultiplyCompositing` 在扩展线性工作空间里的行为、`CIRandomGenerator` 与渐变图像的 extent / alpha。修好后看 Screenshots 重拍的照片是否和离线预览一致。

### 2. v1.1 待办：仓库所有者 2026-11-24 的反馈

| # | 哪里 | 要什么 | 相关文件 | 建议做法 |
| --- | --- | --- | --- | --- |
| 1 🟢 | 装饰台 · 「格式文字」页 | 文字要看得清：系统深色模式下 `TextField`、`DatePicker`、分段 `Picker` 的字是白的，落在浅色纸面上几乎看不见（所有者截图）；分享页选中的胶囊、主按钮是白字（这个对） | `Editor/Inspector.swift`、`Editor/DecorateDesk.swift` | 装饰台窗口固定浅色外观（`window.appearance = NSAppearance(named: .aqua)`）或检查器 `.environment(\.colorScheme, .light)`；逐个控件检查对比度 |
| 2 🟢 | 装饰台 · 贴纸 | **自定义贴纸**：导入自己的图片（PNG / JPG / HEIC，可拖放）做成贴纸，并能管理（重命名、删除、排序，单独一类「我的贴纸」） | `NocchiKit/Decorate/StickerCatalog.swift`、`StickerArt.swift`、`Editor/Inspector.swift` | NocchiKit 加 `CustomStickerStore`（照片库目录下 `stickers/`，复制原图 + 缩略图，JSON 清单，单元测试）；`kindID` 用 `custom.<uuid>`；`StickerArt` 画自定义贴纸时读位图、可选白色模切边 + 投影；`PhotoComposer` 通过注入的位图提供者拿到图（NocchiKit 不直接依赖 App 目录）；缺图时有退路 |
| 3 🟢 | 大头贴机 | 布帘、整台机器、黄铜箭头、拨杆开关、发光的「开始」按钮都用 **Blender 建模**，要非常精细精美；整台大头贴机也要更精美（**已做**：机身面板、招牌、拨杆、箭头、开始按钮是 Blender 渲染，第 37 次推送；布帘要跟着拉动实时变形，改成 SceneKit 实时程序化建模，第 39 次推送，决策 D35） | `Booth/BoothFrameChooser.swift`、`Booth/CurtainScene.swift`、`design/blender/` | 照卡片盒的做法（决策 D22）：`design/blender/booth/*.py` 出分层 PNG（机身底图；拨杆左 / 右两态；按钮按下 / 抬起；开始按钮亮 / 暗；布帘几帧或分层），热区坐标导出 JSON；SwiftUI 只叠图和做动画 |
| 4 | 相框 · 情人节 | `booth-heart` 不够精美，要更精致 | `NocchiKit/Decorate/TemplateArt`（模板绘制）、`PhotoComposer.swift` | 给模板加「位图图层」：Blender 渲染烫金 / 压纹 / 丝带边框（四格条、四宫格各一套），合成时叠在相纸上；屏幕与导出同源 |
| 5 | 相框（全部） | 相框也可以用 Blender 建模，更精细 | 同上 | 同 4，先做大头贴主题和照相馆卡纸、胶片框 |
| 6 🟢 | 相册 · 卡片盒 | 阴影出现「直角」：`CardBoxBase` 渲染图的地面阴影在图片边界被截断，右边露出一块矩形的浅色底（所有者截图） | `design/blender/cardbox/`、`NocchiUI/CardBox/CardBoxView.swift` | 重渲染：透明背景 + 阴影捕捉器，阴影自然衰减到透明并留足画布；SwiftUI 再加一层连贯的柔和环境阴影 |
| 7 🟢 | 相册 · 卡片盒 | **抽卡要符合物理**：点哪个字母标签，照片就从那张分隔卡的位置斜着抽出来（沿卡片方向向上、带一点后仰，离开盒口后再转正），再飞到右边铺开 | `NocchiUI/CardBox/CardFlights.swift`、`CardBoxHotspots.swift` | 起点取被点标签的热点位置；第一段沿分隔卡的倾斜方向位移 + 3D 旋转（`rotation3DEffect`），第二段弧线飞到摊开位置 |
| 8 🟢 | 相册 · 卡片盒 | 右边摊开的区域支持**拖拽摆放、自定义堆叠**，位置要记住 | `NocchiUI/CardBoxModel.swift`、`CardBox/CardBoxView.swift` | 摊开的卡片可拖动，靠近时吸成一摞；布局存进 `CardBoxModel`（UserDefaults 或照片库里的 JSON） |
| 9 🟢 | 相册 · 胶卷光台 | 放大镜的阴影割裂：`Loupe` 图带一块方形投影 / 底，和光台不连贯（所有者截图） | `Album/FilmLightTable.swift`、`design/blender/`（Loupe） | Loupe 重渲染成透明背景、只要镜身；阴影在 SwiftUI 画圆形柔和阴影，跟着鼠标 |
| 10 🟢 | 相册 · 软木板 | 软木板背景太扎眼，要柔和、不突兀 | `Album/CorkBoardView.swift`、`Shared/Art.xcassets/CorkTexture` | 降低软木纹理的反差 / 饱和、颗粒更细，加一层暖色柔光和内阴影；或用 Blender 渲染一块柔和的软木板 |
| 11 🟢 | 相册 · 软木板 | 照片挂上去要有**拟物的高级动效** | `Album/CorkBoardView.swift` | 钉上去时轻微下坠回弹；悬停时绕图钉微微摆动（弹簧）；纸张卷曲的光影随角度变化 |
| 12 🟢 | 相册 · 软木板 | **可调光照**：板子左下角钉一枚贴纸 / 小标签，点开二级菜单调光照（台灯方向、色温、强度、暗角）和显示效果（纸张卷曲、阴影深浅、图钉样式），设置要记住 | `Album/CorkBoardView.swift`、`Album/AlbumShared.swift` | 光照用一层可调的径向渐变 + 阴影方向参数传给照片卡片；菜单做成复古的小卡片（打字机字），存 UserDefaults |
| 13 🟢 | 相册 · 软木板 | 图钉的阴影也割裂（方块状） | `Album/CorkBoardView.swift`、`PinBrass` 等图 | 图钉 PNG 透明、只要钉子本身；阴影在 SwiftUI 画成柔和椭圆，方向跟 12 的光照一致 |
| 14 🟢 | 刘海 · 胶卷柜 | 鼠标滚轮**上下滚动时左右切换**胶卷（现在横向 `ScrollView` 只认左右滑） | `Notch/FilmCabinetPanel.swift` | 用一个 `NSViewRepresentable` 监听 `scrollWheel`，把 `deltaY` 转成横向偏移；或者自己管偏移 + `ScrollViewReader` |

每做完一项：更新本页和 `CHANGELOG.md`，推送，等 CI 绿、Screenshots 重拍后看图验收（截图里没有的界面——比如自定义贴纸管理——可以在 `macOS/Nocchi/Screenshots/` 里加一个场景）。

### 3. 进行中：所有者 2026-11-24 对大头贴机的新反馈（下一位从这里接）

所有者看了第 39 次推送后 Screenshots 拍的 `booth.jpg`：「还是太丑了」。原话要点：
- **机身前面统一建模**：「能不能把机子的前面现实的那个统一建模」「中间大头贴机子实在是太廉价了，我要求复古，拟物，建模精美有质感」。
- **帷幕和帷幕顶上的盖**：「要像剧院那种优雅复古的暗红色，并且可以稍微摆动的动态效果」。
- **招牌要在帷幕盖前面**（招牌被帘头和流苏挡住了）。
- 用量快不够时：**先更新文档、提交并 push**，方便随时换另一个 AI 接手。

| # | 要做的 | 状态 | 文件 | 说明 |
| --- | --- | --- | --- | --- |
| A | 布帘与帘头改成剧院暗红丝绒，帘头做成带弧形褶的垂幔（festoon）+ 金色流苏 / 穗子，轻轻摆动 | 🟢 第 42 次推送后 Screenshots 第 17 次运行确认：暗红丝绒、褶有明暗、金色不过曝；标定条（代码与图）已删。**当时的标定记录**——灰卡（线性 0.18）上主光 ≈ 0.6 倍、侧光 ≈ 0.15、环境光 ≈ 0.1、环境图 ≈ 0.15，而中间那盏暖色点光源（离帘子 0.4）单独就把灰卡打成全白（≥ 5 倍，PBR 点光源的衰减），丝绒和金色也全白。改成很弱的正面平行光（150，≈ 0.14 倍）。等 Screenshots 看效果，好了就删掉标定条（`ScreenshotStudio` 里生成 `debug-curtain-lights` 的几行和那张图）。以下是之前的记录：第 40 次推送：形状对了（垂幔、穗子、招牌在前面），但丝绒的褶峰仍然**过曝发白**（纹理已经是暗红，说明 SceneKit PBR 的灯比预想亮得多）。第 41 次推送加了标定条 `website/public/screenshots/debug-curtain-lights.jpg`（8 格：全部灯 / 主光 / 侧光 / 暖光 / 环境光 / 环境图下的线性 0.18 灰平面、全部灯下的丝绒、金色），用 Blender 的 Python 读像素值算出每盏灯的实际倍数，再定灯光强度；**量完删掉这张图和 `ScreenshotStudio` 里生成它的几行** | `macOS/Nocchi/Booth/CurtainScene.swift` | **第 39 次推送的 3D 布帘渲染出来是曝光过度的黄色**：给几何加的顶点颜色（`SCNGeometrySource` `.color`，做褶谷遮蔽用）把丝绒纹理顶掉了（SceneKit 用顶点色当漫反射）。修法：去掉 `.color` 源，褶谷遮蔽改到表面着色器里（`_surface.position.z + 5` 就是世界 z：正交相机在 z = 5），丝绒纹理按亮度重新上成剧院暗红（#4D0810…#8F1721），灯光与环境图调低，金色件不再过曝。帘头改成弧形褶垂幔，垂幔交接处挂金色穗子（`SCNAction` 慢慢摆）。 |
| B | 机身整体建模（招牌、橱窗、铭牌、箭头、拨杆、开始按钮、投币口、出片口…一体），复古拟物、有质感 | 🟢 第 43 次推送：所有者要求铭牌上加「阳刻的鎏金字 Nocchi」——黑漆底 + Didot 粗体立体金字，建模的一部分；相框名挪到橱窗角落的说明卡。第 42 次推送：`make_machine.py` 渲染了整机 `BoothMachine`（720 × 960 点）+ 11 张零件图 + 生成的 `BoothMachineLayout.swift`；新的 `Booth/BoothMachine.swift` 把整机当外框：橱窗里选相框时挂样张、拍照时是摄像头画面，铭牌刻字、页码槽小灯、招牌跑马灯、零件按钮按坐标叠上去；`BoothInterior` 有渲染图时用它，没有时退回画的那版。等 Screenshots 看效果 | 新：`design/blender/booth/make_machine.py`；改：`Booth/BoothFrameChooser.swift`、`PhotoBoothController.swift`（`BoothInterior`、`BoothSign`、`CameraWindow`） | 方案：Blender 一张机身正面图（胡桃木 + 黄铜装饰艺术风：拱顶招牌、暗红搪瓷牌上立体金字「大头贴机」、一圈暖光灯泡、镀铬包边的大橱窗、黄铜铭牌、奶油色搪瓷控制台、出片口与投币口），按钮 / 拨杆 / 开始按钮在同一场景里单独渲染各状态（用渲染边框裁出小图），热区坐标导出 JSON → 生成 Swift。取景时摄像头画面也显示在这个橱窗里（不再换成另一个窗口）。 |
| C | 招牌在帘头前面 | 🟢 第 40 次推送 | `PhotoBoothController.swift` 的 `BoothCurtainView`、`Screenshots/StudioScenes.swift` 的 `BoothScene` | 把 `CurtainSceneView` 放到 `BoothInterior` **下面**（机身整个在布帘前面，机身两边盖住帘子的里缘） |
| D | 情人节相框（交接表第 4 项） | 🟢 第 43 次推送：跑通并渲染，CI 全绿 | `design/blender/frames/make_valentine.py` → `Resources/Frames/valentine-<strip|grid>-<base.jpg|overlay.png>`；`NocchiKit/Decorate/FrameLayers.swift` 读图（按尺寸缓存），`TemplateArt` 的 `.boothHeart` 分支优先用图层、没图时退回程序化画法；测试 `BoothChoiceTests.testValentineFrameUsesTheBlenderLayers`。脚本修了两个坑：`images.new` 生成的图进 Cycles 会被重画成全黑（蕾丝透明度变 0、看不见）→ 先存 EXR 再读；Cycles 的朗伯面亮度 = 阳光 × cosθ / π，阳光要乘 π，卡纸才是本色。 | 两层位图：`valentine-<strip|grid>-base.jpg`（照片下面：雾玫瑰卡纸 + 模切纸蕾丝边 + 四角蕾丝圆花）和 `-overlay.png`（照片上面：每个心形窗口的纸蕾丝心环 + 烫金内缘线、心口的缎带蝴蝶结、角上的烫金小心、题字上方的烫金花线；阴影用阴影捕捉器带出来），写到 `Packages/NocchiKit/Sources/NocchiKit/Resources/Frames/`。还要做：先 `-- strip --preview` 看预览、调好；再在 `TemplateArt.drawBase / drawForeground` 的 `.boothHeart` 分支里画这两层（`Bundle.module`，按目标宽度用 `ImageIOKit.load(maxPixel:)` 缩小并缓存，没有图时退回现在的程序化画法）。 |
| E | 发 v2.0.0 | 🟢 已发布（Release 第 4 次运行）。第 44 次推送：版本 2.0.0、`CHANGELOG` 整理出 `## [2.0.0]`、README 与文档站更新日志；CI 与 Screenshots 绿了、看过截图就推 `v2.0.0` 标签 | `macOS/project.yml`、`CHANGELOG.md` | 以上做完、CI 全绿后：版本改 2.0.0，`[未发布]` 整理成 `## [2.0.0]`，推 `v2.0.0` 标签 |

## v0.2「复古冲印店」改版进度（交接用）

规范与跨模块接口：[DESIGN.md](DESIGN.md)。每完成一步就推送一次，CI 全绿再做下一步；全部完成后直接发 `v1.0.0`（仓库所有者 2026-11-24 的决定，不再单独发 v0.2.0）。

| # | 步骤 | 状态 | 关键文件 |
| --- | --- | --- | --- |
| 1 | 自拍取景器、程序坞图标、灵动岛比例的刘海 | 🟢 | `macOS/Nocchi/Notch/*`、`App/NocchiMacApp.swift` |
| 2 | 数据契约：照片记录装饰字段、6 种相纸、相册搜索 / 胶片条 / 挂历分组、调色引擎 v2 | 🟢 | `NocchiKit/Darkroom/PhotoRecord.swift`、`Library/*`、`Film/ToneRecipe.swift` |
| 3 | 刘海胶卷柜、相纸选择、摄像头选择、从照片冲印 | 🟢 | `Notch/FilmCabinetPanel.swift`、`Capture/CameraService.swift`、`Import/PhotoImport.swift` |
| 4 | 26 卷胶卷重调 | 🟢 | `Resources/FilmStocks.json`、`scripts/film/make_stocks.py` |
| 5 | 相纸模板、复古贴纸、分层合成；修好 CI 测试卡住 | 🟢 | `NocchiKit/Decorate/*`、`Darkroom/PhotoComposer.swift`、`Support/FontBook.swift` |
| 6 | Blender 素材入库：卡片盒、27 个胶卷罐 / 相纸盒、相册视图图标、图钉 / 木夹 / 放大镜 | 🟢 | `design/blender/**`、`Shared/Art.xcassets`、[ASSETS.md](ASSETS.md) |
| 7 | 相册：透明标题栏顶栏、四种看法切换（⌘1–⌘4）、搜索（⌘F）、2.5D 卡片盒、软木板重做 | 🟢 | `macOS/Nocchi/Album/*`、`NocchiUI/CardBox/*` |
| 8 | 胶卷光台、复古挂历 | 🟢 | `Album/FilmLightTable.swift`、`Album/CalendarWallView.swift` |
| 9 | 装饰台：涂鸦、贴纸、模板、题字、分享海报 | 🟢 | `macOS/Nocchi/Editor/*`；入口在 `Photo/PhotoWindowController.swift`（右键、双击）与 `Album/AlbumShared.swift` |
| 10 | 大头贴先选相框；设置里的默认模板 / 题字字体 / 拍完自动打开装饰台 | 🟢 | `Booth/BoothFrameChooser.swift`、`Booth/PhotoBoothController.swift`、`App/TemplatePreviews.swift`、`Settings/SettingsView.swift`、`App/AppModel.swift`、`NocchiKit/Decorate/TemplatePreview.swift` |
| 11 | 文档收尾、CI 全绿、发 `v1.0.0` | 🟢 | `CHANGELOG.md`（`## [1.0.0]`）、`macOS/project.yml`（版本 1.0.0） |

### 交接须知

- **不在本机构建或测试**，只推送到 `main` 让 GitHub Actions 跑；读结果见 [CI.md](CI.md#读取失败原因)。每一步小步提交、推送，推送前更新本页与 `CHANGELOG.md`。
- **字体**：NocchiKit 里取字体一律走 `FontBook`（只用已安装的字体）。引用没下载的「可下载字体」（楷体、翩翩体、仿宋）会让 CI 的测试进程永远卡住。
- **读 CI 结果不要靠匿名 REST API**：这台机器所在网络的匿名额度（60 次 / 小时、共享 IP）很快就会用光。改读公开网页：`curl -sL https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml | grep -o 'aria-label="[^"]*"'` 能看到每次运行的状态；运行页面（`/actions/runs/<id>`）上能看到注解（编译错误、`annotate-failure.sh` 写的日志尾部、截图工作流的 `SHOT` 行）。日志和构建产物要登录才能看。
- **测试看门狗**：任何测试超过 90 秒会打印 `⏱ HANG: <测试名>` 并结束，见 `Tests/NocchiKitTests/HangWatchdog.swift`。
- **美术**：Blender 脚本在 `design/blender/`，渲染结果直接写进 `Shared/Art.xcassets`；卡片盒热点坐标在 `NocchiUI/CardBox/CardBoxHotspots.swift`（由 `hotspots.json` 生成，重渲后要同步）。
- 本机未跟踪的 `iOS/` 目录是进行中的 iOS App（灵动岛出片口 + Live Activity，v1.0.0 之后接着做），完成并接入 CI 之前先不提交；`Ref_Image/` 是第三方参考图，永远不提交。

## 里程碑

### NocchiKit
- [x] 15 卷原创胶卷配方（暖色、冷色、日系淡彩、黑白、褪色、棕褐、夜景、高反差）
- [x] 色调配方 → 33³ 3D LUT；`.cube` 导入（3D / 1D / 非标准定义域 / 大小与数值校验）与导出
- [x] Core Image 管线：智能裁剪、LUT、光晕、柔焦、柔边、漏光、暗角、颗粒、色块
- [x] 显影模型与显影视觉参数（完成时与成片严格一致）
- [x] 甩动检测（鼠标 / 加速度计）、照片堆排布
- [x] 相纸版式与成片合成（白边、题字、日期、手写）
- [x] 本地照片库、程序化音效
- [x] CI 单元测试通过

### macOS v0.1 · 即显相机
- [x] 刘海定位（硬件刘海 / 虚拟刘海）与悬停展开
- [x] 屏幕快门、可选接管系统截图
- [x] 自拍（镜头取景器、倒数、白屏补光）
- [x] 从刘海出片（马达声、触感、逐段吐出）
- [x] 显影动画、甩一甩加速、甩太猛出色块
- [x] 照片堆、吸附屏幕边缘、桌面层 / 浮动层、双击在 Finder 中显示
- [x] 菜单栏、设置、快捷键、安静模式
- [x] CI 编译通过
- [ ] 真机体验调参（出片节奏、显影时长、甩动阈值）

### macOS v0.2 · 大头贴机
- [x] 拉帘、请看镜头、倒数、白屏闪光、四连拍、四格条出片
- [x] 3D 丝绒布帘；权限预检；任何时候都能离开
- [x] 先选相框（11 款、四格条 / 四宫格、黑白 / 彩色），投币开始
- [ ] 60 秒限时装饰、贴纸、撕成两半分享

### macOS v0.3 · 装饰与相册
- [x] 白边手写（压感）、题字、日期
- [x] 软木板相册（按月份）
- [x] 3D 照片卡片盒（按首字母抽出 / 叠放 / 放回）
- [x] 刘海暂存架（Dropover 式）与拖图冲印
- [ ] 撕成两半生成分享图

### iOS v0.1 · 灵动岛
- [ ] 分层建模相机：镜头里的实时预览 + 玻璃反光、可按下的快门键、闪光灯光晕、随手机倾斜的视差
- [ ] 从灵动岛出片、显影、摇手机加速
- [ ] Live Activity：显影进度显示在灵动岛
- [ ] 桌面照片堆、软木板相册、题字与分享 / 存入相册

## 最近更新（新的在上）

- **2026-11-24 · 发行版 v4.0.0** CI 第 69 次运行绿（零警告）后推 `v4.0.0` 标签（`6f89069`），Release 第 8 次运行出 `Nocchi-macOS-4.0.0.zip` + `SHA256SUMS.txt`；v3.1.0 也已由 Release 第 7 次运行发布。
- **2026-11-24 · 第 60 次推送（4.0.0）** 装饰台拖贴纸 / 文字框、缩放、旋转跟手（拖动中只动这一个视图，松手才写回记录；文字渲染缓存只认内容；旋转过 180° 不跳，⇧ 吸附 15°）。版本 4.0.0。
- **2026-11-24 · 发行版 v3.1.0** CI 第 68 次运行（零警告）、Screenshots 第 34 次（灯光卡片的预览有光、挂历一天三张叠成一摞）看过后推了 `v3.1.0` 标签（`04a95cb`）。
- **2026-11-24 · 第 59 次推送** 所有者贴了 CI 日志里的警告：修掉全部 Swift 6 并发警告（`WindowClip`、四处 `NSEvent` / `NSMenu`），Actions 升级到 Node 24 的版本。
- **2026-11-24 · 第 58 次推送（3.1.0 准备）** 软木板灯光（移植 Typewriter Nocturne 的灯光模型，白天窗光 / 黑夜台灯或月光、挪灯、范围、灰尘），挂历照片用和纸胶带贴、同一天叠成一小摞；截图多拍软木板的夜里和打开的「灯光」卡片；版本 3.1.0。
- **2026-11-24 · 发行版 v3.0.0** CI 第 66 次运行绿后推了 `v3.0.0` 标签。
- **2026-11-24 · 第 57 次推送（3.0.0）** 自拍闪退：本机四份崩溃报告都是摄像头会话被两条线程同时改（摄像头队列 `startRunning`、主线程挂预览层），预览层的挂 / 摘 / 镜像改到摄像头队列上；拍照前查视频连接。大头贴机：启动后在后台准备（布帘着色器与纹理、整机大图、样张、声音），第一次进入不卡。版本 3.0.0。
- **2026-11-24 · 第 56 次推送（发版前所有者的反馈）** 卡片盒抽出来的卡片不再「套娃」：就是成片本身加一枚白色塑料标签（交接表第 12 行）；一起进 v2.1.0。第 55 次推送的 CI / Screenshots 被这次推送取代。
- **2026-11-24 · 第 55 次推送（发版准备）** 所有者同意发 v2.1.0：版本改为 2.1.0，`CHANGELOG` 整理出 `## [2.1.0]`（Release 说明就取这一节），README（版本徽章、「Where it stands」、功能列表里的换相机、卡片盒归档、成片位置）和文档站中英文更新日志加上 2.1.0。发版前把英文表 563 条通读一遍，改了几处用词（「冲印店」统一叫 Photo Lab、Desktop、Prints Folder、Pull out）。第 54 次推送（英文单复数）的 CI 与 Screenshots 见下一条。
- **2026-11-24 · 第 54 次推送** 英文单复数：`scripts/i18n/strings.py` 支持复数写法、生成 `en.lproj/Localizable.stringsdict`（15 个带数量的键：张、文件、字体、贴纸、卷），决策 D39 补了写法。
- **2026-11-24 · 第 53 次推送** 英文截图逐张验收后的修整（交接表第 7 行）：截断的英文、Webcam、COLOUR 刻字；文档站英文页和 README 用英文截图和英文界面上的叫法，设置页补「语言」「存储」，大头贴机页按剧院暗红布帘重写。CI 第 61 次、Screenshots 第 27 次（卡片和标签更精细、英文界面第一次截图）全绿。
- **2026-11-24 · 第 52 次推送** 英文版大头贴机整机图 `BoothMachineEN` 与英文截图（见交接表第 7 行）。
- **2026-11-24 · 第 51 次推送（2.1 反馈第五批）** 中英文切换（交接表第 7 项）：见交接表第 7 行。翻译流程：改了界面文字后跑 `python3 scripts/i18n/strings.py build`（新的中文键会列成 missing），在 `scripts/i18n/en.json` 补英文再 build；普通 String 里的中文用 `String(localized:)`（或者跑 `strings.py wrap <文件>`），模型里动态的中文用 `Localized.string`。CI 第 57 次（成片位置）全绿。
- **2026-11-24 · 第 50 次推送（2.1 反馈第四批）** 成片位置可以换（交接表第 9 项）：`PhotoLibrary.relocatePrints(to:)`（先切换再搬、同名不覆盖、出错回滚，5 条单元测试），`PrintsLocation`（UserDefaults `storage.printsRoot`，外接盘没插上时这次用默认位置），设置 → 通用 → 存储的 `StorageSection`（更改… / 在访达中显示 / 恢复默认，确认后在后台搬、转圈、报告搬了几个）。第 49 次推送（卡片盒「准备抽出来」）CI 第 56 次全绿。
- **2026-11-24 · 第 49 次推送（2.1 反馈第三批）** 所有者补充：卡片盒取出来的效果参考 shashage.de「What We Borrow」档案盒的「准备取出来」动画。读了它的 `archive-interaction.js`：悬停时分隔卡抬起一截、前面的卡照样挡着。照做：`DividerLift`（抬起的纸面 + 原图裁出的标签 + 跟着走的字）、`FrontTabs`（前面的标签盖上），悬停换卡时先放回再抬；截图工作室的按月归档那张让第一格抬起来（`peekSlot`）。第 48 次推送（卡片盒按年月日归档）上一位写完没提交，这次检查后推送，CI 第 55 次全绿。
- **2026-11-24 · 第 48 次推送（2.1 反馈第二批）** 卡片盒归档方式：「＋」右边的黄铜齿轮选按首字母 / 年 / 月 / 日；卡片盒重新渲染成空白标签，标签上的字由 App 按透视印上去；搜索认英文月份名；文档站「拍照」加「换相机」、「相册」加按日期归档。
- **2026-11-24 · 第 47 次推送（2.1 反馈第一批）** 卡片盒卡片空白（按版本重读图、读不到重试）；装着大头贴机时自拍 / 屏幕快门 / 冲印照片都拍成一条四格；刘海面板「换胶卷」右边加「换相机」；相册等窗口出现在当前桌面空间（推断的「主程序被强制隐藏」）；相册顶部小图标重渲染、阴影不再被截断；关于页删掉一句话。详见「交接 · 当前批次」。
- **2026-11-24 · 第 46 次推送** 所有者：README 和网页「不要用廉价的 emoji」。新增一套原创 SVG 图标（`design/icons/make_icons.py`）：文档站首页 9 张功能卡片换成搪瓷小砖图标；README 的导航、各节标题、下载表格换成浅陶土色线条图标。README 里两个显示成裂图的徽章换掉（CI 用 GitHub 自己的工作流徽章，版本用静态徽章，**发新版时记得改 `release-v…`**）。顺手修了首页「装饰台」卡片的说明被截断（YAML 里 ` #` 是注释开头，带 #标签 的文字要加引号）。
- **2026-11-24 · 发行版 v2.0.0** Release 工作流第 4 次运行全绿：`Nocchi-macOS-2.0.0.zip` + `SHA256SUMS.txt`。
- **2026-11-24 · 第 45 次推送** 所有者觉得 README 头图「不够有视觉冲击力」：`DeskScene` 重做成 1800 × 1000 的暗房桌面——深暖棕黑的桌面、从刘海往下的陶土色安全灯光、颗粒与暗角；刘海出片口更大，吐出来的相片还没显影完（乳白）；四周三层相片铺满画面（后层虚化、前层更大并被画框裁掉一角），桌上两只胶卷罐。
- **2026-11-24 · 第 44 次推送（发版准备）** 布帘标定完成（暗色丝绒、金色都不再过曝），删掉标定条；版本改为 2.0.0，`CHANGELOG` 整理出 `## [2.0.0]`，README「Where it stands」和文档站中英文更新日志加上 2.0.0。
- **2026-11-24 · 第 43 次推送** 情人节相框（Blender）跑通入库：雾玫瑰卡纸 + 镂空纸蕾丝边 + 四角蕾丝圆花、心形窗口的纸蕾丝心环 + 烫金线 + 缎带蝴蝶结 + 烫金小心 + 题字上方烫金花线；`FrameLayers` 读图、`TemplateArt` 优先用图层。大头贴机铭牌加上所有者要的阳刻鎏金字「Nocchi」（Didot 粗体、黑漆底），相框名挪到橱窗角落的说明卡，拍照进度在橱窗下沿。
- **2026-11-24 · 第 42 次推送** 大头贴机整机一体建模接入界面（`BoothMachine`）；布帘中间那盏点光源（实测比主光亮 5 倍以上）改成很弱的正面平行光。
- **2026-11-24 · 第 40 次推送** 所有者看了 `booth.jpg`：布帘「不复古不优雅」，要剧院那种优雅复古的暗红色、能轻轻摆，招牌要在帘头前面，机身要整体建模（见「交接」第 3 节）。布帘：第 39 次推送的几何带了顶点颜色（`.color` 源，本来做褶谷遮蔽），SceneKit 拿它顶替了丝绒纹理，所以渲出来是发黄过曝的条纹；去掉顶点颜色，褶谷遮蔽改在表面着色器里按世界 z 算；丝绒纹理按亮度重新上成剧院暗红（`theaterVelvet`），掠射角泛玫瑰色光泽；灯光与环境图调低、金色件更暗更粗糙。帘头改成剧院垂幔（`valance`：弧形横褶、中间前鼓、交接处收拢的竖褶，垂得更深），交接处挂金色穗子（`tassel`：吊绳、葫芦头、领子、条纹贴图的流苏裙，`SCNAction` 慢慢摆）；呼吸幅度稍大；褶的宽窄加了一层慢相位扭动。`BoothCurtainView` 与截图场景改成布帘在 `BoothInterior` 下面。
- **2026-11-24 · 第 39 次推送** 丝绒布帘重做（交接表第 3 项的布帘部分，所有者：「帷幕得有那种布料的高级感觉，可以有褶皱」「帷幕进入和拉开都要有好看现实的动态效果」）：`Booth/CurtainScene.swift` 重写。两幅 `CurtainPanel` 从屏幕外沿帘杆拉进来；褶型在初始化时由 4 组不同频率、往下斜走的波算好（帘环处是整齐小褶），每帧按「布就这么多」由展开量算褶深（收拢时深）；每行的展开量 = 帘杆 + 两个线性阻尼振子（整体摆 ω 10.5 / ζ 0.17 ∝ v^1.5，腰部 ω 24 / ζ 0.3 ∝ sin πv）的偏差，所以下摆落后、甩过头、再停，怎么拉都稳定（之前想过逐行弹簧链，串联的欠阻尼环节会在共振频率上把误差放大，放弃）。帘杆按「起步柔和、长长地慢下来」的曲线走（`CurtainScene.pull`）。丝绒材质：PBR + 表面着色器（正对压深、掠射角顺着主光泛暖色光泽）+ 顶点颜色里的褶谷遮蔽；拉上后的「呼吸」是几何着色器（`scn_frame.time`），停稳后计时器就停，不占 CPU。帘头：扇形垂边（`Hemline`）、三股金色绞绳（螺旋截面）、流苏（落地时被拽长再缩回，`bounce` 由 CPU 每帧给）；金属反射程序化的暖色环境图。拉开时帘杆多拉到 −0.06，0.85 秒内（窗口关掉之前）下摆也回到屏幕外。截图工作室的「选相框」改用 `CurtainScene.renderClosed` 离屏渲染的真 3D 布帘（没有 Metal 时退回平铺纹理，日志 `SHOT curtain=`）。
- **2026-11-24 · 第 38 次推送** 所有者：「这种都不要滚动条，这样很影响观感」（胶卷光台在接了鼠标时仍画出横向滚动条）。原因：`showsIndicators: false` 只等于 `.hidden`，macOS 在接了鼠标或「始终显示滚动条」时照样画传统滚动条。现在每个窗口的根视图（`WindowManager`、装饰台、照片图库选择器、刘海面板、大头贴机）和字体弹窗都加了 `.scrollIndicators(.never)`，各处 `ScrollView` 去掉 `showsIndicators:` 参数（它会在局部把 `.never` 覆盖成 `.hidden`）。规则写进 `docs/DESIGN.md` §0 第 6 条。
- **2026-11-24 · 第 37 次推送** 大头贴机的 Blender 零件（交接表第 3 项的机器与按键部分；布帘在下一步）：`design/blender/booth/make_booth.py` 渲染 `BoothPanel`（@2x 九宫格搪瓷面板）、`BoothMarquee`（灯泡招牌）、`BoothLeverLeft/Right`、`BoothArrow/Pressed`、`BoothStart/Lit/Pressed`；`BoothFrameChooser` 与 `BoothInterior` 改用这些图（`RenderedButtonStyle`、`StartButtonStyle`、`BoothSign`），缺图时退回原来画的版本。所有者要求相册里不要滚动条：软木板 / 光台 / 挂历的 `ScrollView` 都隐藏了滚动条。
- **2026-11-24 · 第 36 次推送** 所有者要求「软件一启动就默认显示卡片盒」：`AppModel.openAlbumOnLaunch`（默认开，设置 → 程序可关），启动 0.7 秒后 `AlbumRouter.shared.show(.cardBox)`。
- **2026-11-24 · 第 35 次推送** 出片动画重做（所有者 2026-11-24 新要求「从灵动岛出片的物理效果和动画更精细」）：`PhotoWindowController.presentEjecting` 逐帧模拟——滚轮每步「先快后慢 + 齿轮间隙回弹」、左右微抖、挂在出片口上的单摆（ω² ∝ 1/伸出长度，每步给冲量，`PhotoViewModel.ejectSway` 绕出片口转）、光泽扫过；`finishEjecting` 夹住余摆 0.14 秒后松开（出片口这时合上），重力 + 空气阻力下落、横向漂移、欠阻尼弹簧转到随手角度（落地后摩擦加大），落地弹一下、阴影收紧（`lifted`）、新音效 `paperLand`；出片口沿有一道渐隐的阴影。
- **2026-11-24 · 第 34 次推送** 自定义贴纸（交接表第 2 项）：NocchiKit `CustomStickerStore`（照片库 `stickers/`：导入图片 → 最长边 1600、裁透明边、存 PNG，`stickers.json` 清单；重命名、模切边、排序、删掉 = 隐藏，已贴的照样能画）与 `StickerArt.customProvider`（App 启动时注入，`custom.<UUID>` 用图片 + 16 向偏移的白色模切边 + 投影画出来，成片 / 桌面相纸 / 装饰台一致）；装饰台贴纸页「我的」：导入格、拖放、右键管理（`Editor/StickerShelf.swift`），图片拖到照片上直接贴在放下的位置。新增 `CustomStickerTests`。
- **2026-11-24 · 第 33 次推送** 照片上任意位置的文字框与自定义字体（所有者 2026-11-24 新要求）：NocchiKit 新增 `TextPlacement`（照片记录 `texts`，旧库照常读取）与 `TextArt`（Core Text 多行排版、对齐、字距、粗斜体，样式：无 / 白边 / 纸标签 / 投影），`PhotoComposer` 把文字框画在贴纸上面、笔画下面；`FontBook` 改成线程安全、可刷新，能注册导入的字体；`CustomFontStore` 管理照片库 `fonts/` 里导入的字体，App 启动时注册。装饰台：「T」文字工具、可拖动缩放旋转的文字框（`TextItem`，屏幕与导出同一个画法）、检查器「照片上的文字」编辑器与可搜索的字体选择器（导入 / 删除字体）。新增 `TextArtTests`。
- **2026-11-24 · 第 32 次推送** 软木板（交接表第 10–12 项）：`design/blender/textures/make_cork.py` 渲染柔和的无缝软木（4D 噪声映射到环面、@2x 资源 `CorkSoft`）；`Album/CorkLighting.swift`——灯光设置（方向、色温、亮度、暗角、阴影、纸张卷曲、固定方式，UserDefaults）、左下角「灯光」铜牌、打字机调节卡片（黄铜拨盘与滑杆）；照片、图钉、标签带、旧物的阴影方向和深浅都由灯光算出，照片上有顺着灯的卷曲明暗（柔光混合）；照片钉上去时下落回弹、图钉按进去，鼠标拂过按横向速度给一个摆动（欠阻尼弹簧，绕挂点转），胶带贴的不摆。所有者补充：这一轮主要改 macOS，iOS 之后再跟，能共用的部分（NocchiKit / NocchiUI）顺手一起做。
- **2026-11-24 · 第 31 次推送** 卡片盒（交接表第 7、8 项 + 所有者 2026-11-24 新要求「照片像参考图那样层次堆叠」「检索字母的标签要精致」）：`SlotGeometry` 由热点算出每个字母那一格（格口线、分隔卡方向），卡片先以斜切变换（`CardSkew`）立在格子里、被格口线以下的遮罩（`SlotMask`）挡住，沿分隔卡往上抽出、在盒口上方转正，再落到右边；放回时反过来。右边改成松散的一叠（`PileLayout`），可拖动摆放、靠近另一张会叠上去，位置存在 `CardBoxModel.spots`（UserDefaults），「重新叠好」清掉。卡片的字母标签改成模切纸标签（`IndexTabShape`），分隔卡悬停提示改成吊牌。
- **2026-11-24 · 第 30 次推送** 装饰台固定浅色外观（深色模式下检查器的字不再是白的），「文字」页图标换成引号；胶卷柜支持鼠标滚轮左右翻（`WheelToHorizontalScroll`）。阴影统一柔和：卡片盒在 2000 × 1500 的画布上重渲染、盒子靠左上，阴影捕捉器的像素在边缘 13% 内平滑淡到透明（`studio.fade_shadow_edges`，四边 alpha = 0）；热点由新脚本 `design/blender/cardbox/gen_swift_hotspots.py` 生成；图钉、木夹、放大镜改成不带地面阴影，阴影在界面里按轮廓画。
- **2026-11-24 · 第 29 次推送** 修好「照片偏暗、偏艳」：光晕的加法混合把 alpha 加成 2，之后的柔光颗粒按公式把中间调算成黑色；每个加法效果之后把照片压回不透明（`FilmProcessor.flattened`），删掉 `XCTExpectFailure`，新增逐个效果的不透明 / 亮度回归测试。所有者新的反馈（2026-11-24）把这一轮定为 **v2.0**：除了交接表里的 14 项，还要在装饰台的照片上任意位置加文字框并可自定义字体，布帘要有布料质感、褶皱和逼真的拉合动画，完成后发 `v2.0.0`；不准用子代理（subagent）。
- **2026-11-24 · 第 28 次推送（交接）** 第 27 次推送的诊断证明色调查表是对的（旧滤镜 170,158,143 ≈ 配方 171,159,143），照片偏暗出在效果阶段（平坦色块开全部效果后中间是 0）——问题未修，`testFullPipelineKeepsTheBrightnessOfTheRecipe` 先用 `XCTExpectFailure` 标住，CI 保持绿。截图第二轮（刘海截图已裁到岛的范围）已提交。仓库所有者的 14 条 v1.1 反馈整理成上面的「交接 · 下一位从这里开始」。
- **2026-11-24 · 第 27 次推送** 截图第一轮（Screenshots 第 1 次运行）全部 11 张都拍到了：相册四种看法、装饰台、设置、刘海悬停面板与胶卷柜是窗口服务器截的真实窗口（CI 屏幕只有 1024 × 768、1 倍），桌面 / 相纸一览 / 大头贴是 2 倍合成图。看图发现**真问题**：所有彩色胶卷冲出来都比配方暗一个 gamma、阴影压死、颜色过艳（离线预览 `scripts/film/preview_looks.py` 是对的）——Core Image 套色调立方体时没有可靠地在 sRGB 里查表。修复：`FilmProcessor.applyCube` 明确地「工作空间 → sRGB → `CIColorCube` → 工作空间」；新增 `FilmPipelineFidelityTests`（管线逐色对照 CPU 查表、中性配方不改图、整条管线不改变亮度，另有一条注解记录旧滤镜在 CI 上的输出）。刘海截图裁到岛的范围、去掉菜单栏时间；文档站中文页的搜索框翻译成中文、中文标题不再用斜体。文档站已上线：<https://chaosnap.github.io/Nocchi/>。
- **2026-11-24 · 第 26 次推送** 产品文档站与 CI 截图：`website/`（VitePress，英文默认、可切换中文，13 页指南 × 2 种语言，复古冲印店配色）+ `pages.yml` 发布到 GitHub Pages；App 新增隐藏的截图模式（`macOS/Nocchi/Screenshots/`），`screenshots.yml` 在 Actions 上用 11 张 Codex 生成的原创样片冲印 13 张照片，截下真实的相册四种看法、装饰台、设置、刘海悬停面板与胶卷柜，合成桌面、相纸一览和大头贴「选相框」，提交到 `website/public/screenshots/`；英文 README 加上截图与中英文文档入口。
- **2026-11-24 · 发行版 v1.0.0** 推送 `v1.0.0` 标签（e704e0a），Release 工作流第 3 次运行全绿，发布 `Nocchi-macOS-1.0.0.zip` 与 `SHA256SUMS.txt`；说明取自 `CHANGELOG` 的 `## [1.0.0]`。这一版起按 AGPL-3.0。
- **2026-11-24 · 第 25 次推送** 许可改为 GNU AGPL-3.0（与 Yohaku 一致，取代 CC BY-NC 4.0，见决策 D32）；README 按 Yohaku 的结构重写成英文；行为准则换成英文的 Contributor Covenant 3.0 改编版；贡献指南、安全政策、隐私说明、Issue / PR 模板改成英文；CLAUDE.md 的许可规则同步。v1.0.0 按 AGPL-3.0 发布。
- **2026-11-24 · 第 24 次推送** 文档收尾（第 11 步）：`CHANGELOG` 把 v0.2 改版的全部内容整理成 `## [1.0.0]`（新增 / 内核 / 修复 / 仓库），macOS 工程版本号改为 1.0.0；第 10 步 CI 全绿（第 26 次 CI 运行）。CI 绿了之后推送 `v1.0.0` 标签。
- **2026-11-24 · 第 23 次推送** 大头贴机先选相框（第 10 步）：拉上布帘后停在「选相框」——黄铜包边的橱窗里用小铜夹挂着这一款的样张（暖灰占位格和成片同一套合成），两边黄铜箭头换相框（先六款大头贴主题，再经典 / 炭黑 / 牛皮纸 / 胶片框 / 70 年代），两个镀铬拨杆开关切换四格条 / 四宫格与黑白 / 彩色，一行打字机字写着用哪卷胶卷，按下会呼吸发光的「开始」投币后才开摄像头、开始计时；← → 换相框、↑ ↓ 换版式、Return 开始、Esc 离开，选相框时看门狗不计时，下次从这次的选择开始。设置新增「相纸」页：即显默认模板、大头贴默认相框 / 版式 / 黑白（都是实时合成的小样）、题字字体、「显影完成后自动打开装饰台」（默认关）；新照片按这些默认值冲印。
- **2026-11-24 · 第 22 次推送** 装饰台（第 9 步）：皮革工具托盘（四种笔、橡皮、8 个珐琅颜料、粗细、撤销 / 重做）、相纸（后台合成的模板与题字层 + 笔画 + 可拖动缩放旋转的贴纸）、检查器四页（贴纸、模板缩略图、文字与标签、分享海报：8 种背景、3 种摆法、导出 / 拷贝 / 分享）；「完成」重新合成成片并刷新桌面、相册、卡片盒。桌面相片双击 / 右键「装饰…」与相册双击 / 右键「装饰…」都会打开。
- **2026-11-24 · 第 21 次推送** 相册的另外两种看法（第 8 步）：胶卷光台（铝边发光台、竖直的 35mm 正片条与齿孔、橙色片边字、大头贴整条、月份纸条、洗一洗、正片 / 负片、跟着鼠标的放大镜）与复古挂历（装订边与黄铜铆眼、大号月份、照片角小照片、「+2」红圆章、今天的红印章、点开当天的照片、本月统计；搜索时翻到命中照片的月份）。
- **2026-11-24 · 第 20 次推送** 相册改版（第 7 步）：透明标题栏 + 顶栏（字标、四种看法切换托盘、搜索框、「＋」冲印），红绿灯挪到顶栏中线；搜索对所有看法生效，没有结果时显示打字机纸条。卡片盒换成 Blender 渲染的 2.5D 版本（标签热区与气泡、卡片从盒口升起再飞到右边扇形摊开、拖动翻看、全部放回），去掉 SceneKit 版本与 A–Z 检索条。软木板重做（胡桃木框、凸字月份标签带、拼贴排布、图钉 / 地图针 / 胶带 / 木夹、旧物点缀）。胶卷、日历两种看法暂时显示「正在暗房里冲洗」，第 8 步接上。
- **2026-11-24 · 第 19 次推送** Blender 素材入库：照参考图复刻的山毛榉木索引卡盒（指接榫、把手孔里插着笔、A–Z 与 # 分隔卡、翘起的横线卡，分成底图与前挡板两层，附 27 个标签的热点坐标）；26 卷胶卷各自的 35mm 罐 / 即显相纸盒 / 照相亭相纸盒与自定义胶卷罐（标签按胶卷配色生成，四位数感光度收窄避开片舌）；相册四种看法的小图标（软木板、卡片盒、胶卷、挂历）；黄铜图钉、三色地图针、木夹、放大镜外圈。脚本与样张在 `design/blender/`，中间文件不入库。
- **2026-11-24 · 第 18 次推送** 继续修测试卡住：题字的中文后备字体引用了 macOS 没预装的「可下载字体」（楷体、翩翩体、仿宋），Core Text 会去请求系统字体服务激活它们，在 CI 的无界面测试进程里一直等；现在所有字体都先查「已安装字体」清单（`FontBook`），只用装了的。另加测试看门狗：任何测试超过 90 秒就报出测试名并结束，不再白等 12 分钟。
- **2026-11-24 · 第 17 次推送** 修复第 16 次推送后测试卡住：邮票模板和邮票贴纸的齿孔边改成在纸上直接「挖孔」，不再用几十个圆做路径布尔运算（那一步在 CI 上卡死）；`swift test` 单独限时 12 分钟，卡住时也会把日志尾部写成注解。
- **2026-11-24 · 第 16 次推送** 相纸模板与复古贴纸：16 款模板（经典、炭黑、牛皮纸、毛边、日期机、胶片框、邮票、70 年代条纹、老相册、照相馆卡纸，以及老照相亭、黑白照相亭、情人节心形窗口、金星、生日快乐、新年快乐六款大头贴主题）；60 多枚程序化绘制的复古贴纸（乙烯徽章、橡皮章、电影票 / 邮票 / 价签 / 行李牌 / 胶片等旧物、纸胶带、凸字标签、模切表情）；成片合成分成「照片下面 / 照片上面」两层，屏幕上的相纸直接用同一套渲染（模板、贴纸、地点 / 标签手帐式题字、四种笔触都和导出一致）。
- **2026-11-24 · 第 15 次推送** 滤镜重做：26 卷胶卷（重调原有 15 卷 + 新增人像 400、金黄 200、艳色 100、钨丝 800、薄荷 400、常青 400、日常 200、晶亮 800、粗粒 400、细腻 100、照相亭黑白 400），用新引擎的曲线、八色相带 HSL、肤色保护、高光软肩做出胶片影调；在本机测试照片上逐卷出样张对比调整；配方源 `scripts/film/make_stocks.py`；新增调色引擎与胶卷测试。
- **2026-11-24 · 第 14 次推送** 刘海里的胶卷柜：悬停面板改成「拍摄按钮 + 胶卷罐 + 相纸剪影」，点胶卷罐展开胶卷柜（按即显相纸 / 彩色负片 / 夜景与电影 / 黑白 / 大头贴分组，装着的那卷有暖光、悬停显示说明和推荐相纸）；点相纸在方形 / 迷你 / 宽幅 / 冲印小照之间切换；菜单栏菜单的胶卷带小图、新增相纸选择。设置新增「摄像头」页：实时预览、内建 / 外接与虚拟 / iPhone 摄像头列表、镜像开关，拔掉正在用的摄像头会自动换回默认。胶卷罐渲染图到位前用 SwiftUI 画的复古替身。
- **2026-11-24 · 第 13 次推送** 修复自拍取景器底部被裁掉（岛的高度改由内容推出来）；刘海提示改成灵动岛比例（短提示只在两侧伸出一小截，长提示向下长出一条），每次启动有 1.6 秒「营业中」问候；默认在程序坞显示图标（可在设置里关），点图标打开相册，程序坞右键菜单与主菜单（相机 / 相册）；从「文件」或「照片」图库冲印照片（逐张出片）；即显相机用所选相纸冲印；自拍镜像可设置。
- **2026-11-24 · 第 12 次推送** v0.2 第一批内核：照片记录的装饰字段（贴纸、涂鸦笔、模板、题字字体、地点、标签、拍摄时间，旧照片库照常读取）；6 种相纸规格（新增迷你即显、宽幅即显、四宫格）；胶卷分组；相册搜索（题字 / 标签 / 地点 / 胶卷 / 日期 / 拼音 / 首字母）、胶片条分组、挂历分组；调色引擎 v2（每通道曲线、八色相带 HSL、肤色保护、高光软肩、阴影雾化）与离线样张工具 `scripts/film/preview_looks.py`；复古配色与字体令牌。
- **2026-11-23 · 第 11 次推送** 许可统一为主流的 CC BY-NC 4.0（署名—非商业性使用 4.0 协议国际版），只覆盖 Chaosnap 自己创作的内容，第三方内容按各自的许可；`LICENSE-ASSETS.md` 合并进 `LICENSE`。
- **2026-11-23 · 第 10 次推送** 许可改为「非商用随便用，保留原始版权」：代码按 PolyForm Noncommercial 1.0.0，美术素材按 CC BY-NC 4.0，商用需书面许可；去掉 Apache 专用的 `NOTICE`，贡献指南加上贡献授权条款。
- **2026-11-23 · 第 9 次推送** 补齐仓库文件：代码采用 Apache-2.0（`LICENSE`、`NOTICE`），美术素材保留所有权利（`LICENSE-ASSETS.md`）；行为准则、贡献指南、安全政策、隐私说明、Issue / PR 模板、`.editorconfig`、Dependabot。写好 v0.2「复古冲印店」设计规范 [DESIGN.md](DESIGN.md) 与决策 D18–D29，改版代码正在并行开发。
- **2026-11-23 · 发行版 v0.1.1** 包含第 7、8 次推送的全部修复与新功能。
- **2026-11-23 · 第 8 次推送** 修复：大头贴机布帘挡住系统权限弹窗导致无法授权、无法退出——先请求权限、布帘降到菜单栏之下、离开按钮 / Esc / ⌘Q / 超时 / 看门狗。相纸精细化（纸面、内凹窗口、药包隆起、光面高光、三层阴影、新字体，导出同步）。3D 丝绒布帘。刘海暂存架（拖相片进刘海暂存、拖出成片）与拖图片到刘海冲印。Codex 生成 80 年代方盒机身、胡桃木与丝绒纹理。
- **2026-11-23 · 发行版 v0.1.0** 推送 `v0.1.0` 标签，Release 工作流构建并发布第一个 macOS 版本。
- **2026-11-23 · 第 7 次推送** 照片卡片盒（3D）：木质抽屉、立着的相片卡、A–Z 分隔标签、桌上的照片堆，PBR 材质 + 柔和阴影 + 环境光遮蔽 + 光面相纸涂层；Mac 相册新增「卡片盒」模式。
- **2026-11-23 · 第 6 次推送** App 图标第三稿：主体换成复古旁轴式即显相机（香槟金属 + 黑色颗粒皮革 + 陶土橙快门帽），做旧毛边相纸留在画框内。
- **2026-11-23 · 第 5 次推送** 改为直接在 `main` 开发；新增 Release 工作流（推送 `v*` 标签 → 测试、构建、打包、发布）；App 图标按 macOS 圆角瓷砖规格重画（主体是复古相机，相片冲出画框）；`CHANGELOG` 整理出 `0.1.0`。
- **2026-11-23 · 第 4 次推送** 修复 macOS 编译错误；App 图标换成有设计感的手写 SVG（暗房安全灯 + 刘海 + 正在显影的相片），CI 渲染各尺寸；新增首字母索引（中文按拼音首字母）。
- **2026-11-23 · 第 3 次推送** macOS App 第一版（刘海、屏幕快门、自拍、大头贴机、出片、显影、甩动、照片堆、手写、相册、设置）；美术换成象牙白 + 炭黑 + 陶土橙复古配色；参考「复古拍立得」玩法加入默认题字、照片堆和柔边。
- **2026-11-23 · 第 2 次推送** NocchiKit 第一版与单元测试 —— CI 一次通过（44 秒）。
- **2026-11-23 · 第 1 次推送** 建立仓库与 GitHub Actions-Only 工作流。

## 下一步

1. 等所有者试用后确认：装饰台拖贴纸 / 文字框是否顺了（4.0.0）；自拍是否不再闪退、第一次进大头贴机是否不卡（3.0.0）；2.1 交接表第 3 项（从刘海进相册时「主程序被强制隐藏」，推断是窗口留在别的桌面空间，已让窗口跟着当前空间走）。
2. 之后：完成 iOS App 与灵动岛 Live Activity（`iOS/` 下的草稿还没提交，iOS 用 80 年代方盒款机身外观），接入 CI（未签名 ipa）；iOS 也接上 `UILanguage` 和英文表。

## 已知问题 / 待你确认

- App 名称、收费方式、Bundle ID 见 [决策记录 · 待你决定](DECISIONS.md#待你决定)（许可已定：GNU AGPL-3.0，见决策 D32）。
- 英文界面里，贴纸图案上印的中文（「已显影」「珍藏」印章、小票上的字等）保留原样，是图案的一部分；贴纸名字是英文的。
- 请在仓库 **Settings → Code security → Private vulnerability reporting** 打开「私密漏洞报告」，`SECURITY.md` 里的举报入口才能用。
- CI 产物是 ad-hoc 签名，首次打开需要解除隔离（见 [CI.md](CI.md#macos-测试版)）。

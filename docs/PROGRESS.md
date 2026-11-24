# 进度看板（实时更新）

> 最后更新：2026-11-24 · 分支 `main`（直接在 main 开发）
> 每次推送都会同步更新本页。构建产物见 [Actions](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml)。

## 一眼看懂

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 仓库与 CI | 🟢 已搭好 | 直接在 `main` 开发；NocchiKit 测试与 macOS 构建在 GitHub Actions 上跑；推送 `v*` 标签自动发行版本 |
| NocchiKit（共享暗房内核） | 🟢 CI 全绿 | 调色引擎 v2（曲线、HSL、肤色保护、高光软肩）+ 26 卷胶卷；相册检索 / 胶片条 / 挂历分组 |
| macOS App（刘海出片口） | 🟢 v1.0.0 已发布 | [Releases](https://github.com/Chaosnap/Nocchi/releases/latest)：`Nocchi-macOS-1.0.0.zip` + `SHA256SUMS.txt`（AGPL-3.0） |
| iOS App（灵动岛出片口） | 🔵 编写中 | 分层建模相机、灵动岛出片、Live Activity |
| 美术素材 | 🟢 第三版 | 复古机身、大头贴机、纹理（象牙白 + 炭黑 + 陶土橙）；**App 图标第三稿**：复古旁轴式即显相机 + 做旧毛边相纸（不出画框），胡桃木圆角瓷砖，CI 渲染各尺寸；80 年代方盒款机身已入库备用 |
| 照片卡片盒（2.5D） | 🟢 CI 全绿 | Blender 照参考图建模、Cycles 渲染（`CardBoxBase` / `CardBoxFront` + 热点），卡片从盒口升起、扇形摊开 |
| v0.2「复古冲印店」 | 🟢 全部完成，随 v1.0.0 发布 | 规范见 [DESIGN.md](DESIGN.md)；逐步进度见下面的「v0.2 改版进度」 |
| 产品文档站与截图 | 🟢 已上线 | <https://chaosnap.github.io/Nocchi/>（VitePress，英文 + `/zh/` 中文）；截图由 `screenshots.yml` 在 Actions 上从 App 渲染，提交到 `website/public/screenshots/` |
| v2.0 打磨（所有者反馈） | 🟡 进行中 | 14 项 + 文字框与自定义字体 + 布帘动态，见下面「交接」；「照片偏暗」已修 |
| 仓库与社区文件 | 🟢 已补齐 | GNU AGPL-3.0（与 Yohaku 一致）；英文的 README、行为准则（Contributor Covenant 3.0）、贡献指南、安全政策、隐私说明、Issue / PR 模板 |

图例：🟢 完成 · 🟡 进行中 / 待验证 · 🔵 编写中 · ⚪ 未开始 · 🔴 阻塞

## 交接 · 下一位从这里开始（2026-11-24）

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

1. 交接表第 4–5 项：Blender 建模的相框（先把情人节 `booth-heart` 做精致，再做其余大头贴主题、照相馆卡纸、胶片框）——模板加「位图图层」，NocchiKit 资源里放渲染图，`PhotoComposer` 合成，屏幕与导出同源。
2. 全部做完、CI 全绿后：`macOS/project.yml` 版本改 2.0.0，`CHANGELOG` 的「未发布」整理成 `## [2.0.0]`，推 `v2.0.0` 标签（所有者：「完成后记得 push 成 2.0」）。
3. 看 Screenshots 工作流重拍的 `booth.jpg`（3D 布帘离屏渲染）对不对。
4. 之后：完成 iOS App 与灵动岛 Live Activity（`iOS/` 下的草稿还没提交，iOS 用 80 年代方盒款机身外观），接入 CI（未签名 ipa）。

## 已知问题 / 待你确认

- App 名称、收费方式、Bundle ID 见 [决策记录 · 待你决定](DECISIONS.md#待你决定)（许可已定：GNU AGPL-3.0，见决策 D32）。
- 照片偏暗（效果阶段），见「交接」第 1 节。
- 请在仓库 **Settings → Code security → Private vulnerability reporting** 打开「私密漏洞报告」，`SECURITY.md` 里的举报入口才能用。
- CI 产物是 ad-hoc 签名，首次打开需要解除隔离（见 [CI.md](CI.md#macos-测试版)）。

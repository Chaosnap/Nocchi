# 架构

```text
Nocchi/
├── Packages/NocchiKit      共享内核（Swift Package，两个 App 共用，CI 跑单元测试）
│   └── Sources/NocchiUI    共享的 2.5D 照片卡片盒、屏幕上的相纸（SwiftUI）
├── macOS/                  刘海出片口 App（XcodeGen：macOS/project.yml）
├── iOS/                    灵动岛出片口 App + Live Activity 扩展（XcodeGen：iOS/project.yml）
├── Shared/Art.xcassets     两个 App 共用的原创美术（机身、纹理）
├── design/                 美术源文件、部件坐标、截图样片
└── website/                产品文档站（VitePress，英文 + /zh/ 中文，GitHub Pages）
```

## NocchiKit

| 模块 | 文件 | 作用 |
| --- | --- | --- |
| 胶卷 | `Film/FilmStock.swift`、`Resources/FilmStocks.json` | 胶卷模型与 15 卷内置胶卷 |
| 色调 | `Film/ToneRecipe.swift`、`Film/ColorCube.swift` | 参数配方 → 33³ 3D LUT；`.cube` 导出 |
| LUT 导入 | `Film/CubeLUT.swift` | `.cube` 解析（3D / 1D / 定义域）、校验、重采样 |
| 冲印 | `Film/FilmProcessor.swift` | Core Image 管线：镜像 → 智能裁剪 → 缩放 → LUT → 光晕 → 柔焦 → 柔边 → 漏光 → 暗角 → 颗粒；色块单独一步 |
| 裁剪 | `Film/SmartCrop.swift` | Vision 显著性检测找画面重点 |
| 显影 | `Darkroom/DevelopmentModel.swift` | 显影进度（时间 + 甩动加速）；`DevelopmentVisual` 给界面画显影中的样子，进度 1 时严格等于成片 |
| 甩动 | `Darkroom/ShakeDetector.swift` | 统计快速方向反转；鼠标拖动 / 手机加速度两套参数 |
| 相纸 | `Darkroom/PaperLayout.swift`、`PhotoComposer.swift` | 方形即显 / 四格大头贴 / 横幅版式；合成带白边的成片（题字、日期、手写） |
| 模板预览 | `Decorate/TemplatePreview.swift` | 暖灰占位格合成的模板样张（大头贴选相框、设置）；大头贴相框顺序与黑白 / 彩色选卷规则 |
| 照片库 | `Darkroom/PhotoLibrary.swift`、`PhotoRecord.swift` | 本地记录、底片、成片、LUT，按月分组 |
| 机身 | `Darkroom/CameraBody.swift` | 相机柜：即显相机、大头贴机（其余在路线图） |
| 音效 | `Audio/SoundSynth.swift`、`SoundPlayer.swift` | 程序合成 + AVAudioEngine 播放 |
| 几何 | `Geometry/SlotGeometry.swift`、`PileLayout.swift` | 刘海矩形、灵动岛估算、照片堆排布 |

一张照片的一生：

```text
截图 / 自拍 / 大头贴 / 相册
      │  CGImage
      ▼
FilmProcessor（胶卷配方 + seed）──► 底片 negatives/*.jpg
      │
      ▼
出片动画（刘海 / 灵动岛）──► 显影动画（DevelopmentVisual，甩一甩加速，太猛出色块）
      │
      ▼
PhotoComposer（白边 + 题字 + 日期 + 手写）──► 成片 ~/Pictures/Nocchi/<年-月>/*.jpg
```

## NocchiUI · 照片卡片盒（2.5D）

| 文件 | 作用 |
| --- | --- |
| `CardBoxModel.swift` | 状态：哪些照片在盒子里、哪些摊在右边、谁在最上面；按字母抽卡、搜索（`applySearch`）、最近冲印、翻页、全部放回；每个字母的张数；读图（成片或用底片临时合成，`editedAt` 变了重新读） |
| `CardBox/CardBoxView.swift` | 舞台：背景 → `CardBoxBase` 渲染图 → 正在抽出的卡片 → `CardBoxFront` → 标签热区 → 右边那一叠；`CardBoxStage`（渲染图与摊开区的几何）、`SlotGeometry`（每个字母那一格的格口线与斜切）、`CardSkew`（斜切 ↔ 转正）、`SlotMask`、`PileLayout`（松散的一叠、拖动摆放与吸附成摞） |
| `CardBox/CardFlights.swift` | 飞行编排：抽卡 = 立在自己那一格（斜切、被格口线遮住）→ 沿分隔卡抽出 → 在盒口上方转正 → 落到右边那一叠；放回反过来。模型只管顺序，这里管阶段 |
| `CardBox/CardBoxHotspots.swift` | 渲染图上 27 个分隔卡标签、盒口、盒子外框的归一化坐标（由 `design/blender/cardbox/hotspots.json` 生成） |
| `CardBox/CardBoxParts.swift` | 照片索引卡（纸色、宋体标题、打字机副标题、字母小标签、横线）、标签热区与气泡、「全部放回」、空盒提示、渲染图缺失时的退路 |
| `Print/PrintSurface.swift` | 屏幕上的相纸：`PhotoComposer` 的底层 / 上层 + 显影中的照片 + 光泽 + 正在写的笔画 |

## macOS App

| 模块 | 作用 |
| --- | --- |
| `App/` | 菜单栏入口（MenuBarExtra）、全局设置 `AppModel`（含默认模板 / 相框 / 题字字体 / 自动打开装饰台）、配色 `Palette`、照片库与音效服务、`TemplatePreviews`（模板小样的后台合成与缓存） |
| `Notch/` | `NotchController`：找到刘海（无刘海屏幕用虚拟刘海），在菜单栏之上放一个透明面板；悬停展开操作面板、自拍取景器、出片口、提示条 |
| `Capture/` | 摄像头（AVFoundation）、屏幕快门（`screencapture -i`）、接管系统截图（NSMetadataQuery）、白屏闪光 |
| `Darkroom/` | 拍摄 → 冲印 → 存档 → 出片的编排 |
| `Photo/` | 桌面照片窗口：出片遮罩、显影计时、拖动与甩动、吸边、桌面层 / 浮动层、白边手写、右键菜单；照片堆 |
| `Booth/` | 大头贴机：`PhotoBoothController`（权限预检 → 3D 布帘 → 选相框 → 投币开始 → 请看镜头 → 倒数 → 白屏闪光 × 4 → 出片；离开按钮 / Esc / ⌘Q、按下「开始」后的看门狗）、`BoothFrameChooser`（黄铜橱窗里的样张、黄铜箭头、镀铬拨杆开关、发光的「开始」）、`CurtainScene`（SceneKit 丝绒布帘：两幅 `CurtainPanel` 每帧按帘杆位置和两个阻尼振子重算顶点与法线，褶型初始化时算好；丝绒是 PBR + 表面着色器光泽 + 顶点颜色遮蔽，拉上后的呼吸在几何着色器里；扇形帘头、金色绞绳、流苏；`renderClosed` 给截图工作室离屏渲染） |
| `Album/` | 相册窗口：`AlbumView`（四种看法 + 搜索）、`AlbumHeader`（字标、看法切换、搜索框、冲印按钮、红绿灯对齐）、`CorkBoardView`（胡桃木框软木板、月份标签带、拼贴排布、钉上去 / 摆动的动效）、`CorkLighting`（可调台灯：设置、左下角铜牌、调节卡片）、`FilmLightTable`（光台、35mm 胶片条、放大镜、洗一洗、正负片）、`CalendarWallView`（复古挂历）、`AlbumShared`（照片库、缩略图 / 贴纸缓存、右键菜单与操作、`AlbumRouter`） |
| `Editor/` | 装饰台（我的贴纸：`StickerShelf` 包着 NocchiKit 的 `CustomStickerStore`，图由 `StickerArt.customProvider` 注入；文字框：`PaperStage.TextItem`、检查器 `TextBoxEditor` 与 `FontPicker`；文字的画法在 NocchiKit 的 `TextArt`，导入的字体由 `CustomFontStore` 管理、启动时注册）：`DecorateDesk`（窗口与入口）、`DecorateSession`（记录的工作副本、工具、撤销 / 重做、后台合成的相纸层、保存）、`PaperStage`（相纸、笔画、可拖动缩放旋转的贴纸）、`Inspector`（贴纸 / 模板 / 文字 / 分享四页）、`PosterRenderer`（1080×1350 分享海报） |
| `Screenshots/` | 截图工作室（只在 GitHub Actions 上用）：`ScreenshotStudio`（`--render-screenshots` 启动、临时照片库、截真实窗口与刘海面板）、`StudioSpecs`（13 张样片的胶卷 / 相纸 / 模板 / 题字 / 贴纸）、`StudioScenes`（桌面、相纸一览、大头贴的合成场景） |
| `Settings/` | 相机柜、胶卷（导入 / 导出 `.cube`）、相纸（即显相纸与默认模板、大头贴默认相框 / 版式 / 黑白、题字字体、显影后自动打开装饰台）、摄像头、通用设置、关于；全局快捷键 |

窗口层级：刘海面板（菜单栏之上 +3）> 出片中的照片（+2）> 大头贴布帘（+1）> 普通浮动照片 > 桌面层照片。

## iOS App

见 `iOS/` 目录与 `docs/PROGRESS.md`（开发中）：灵动岛位置按安全区估算，岛「张开」成出片口；显影时启动 Live Activity，在灵动岛上显示进度。

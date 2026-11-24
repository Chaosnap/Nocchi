# 美术素材

所有素材都是原创。v0.1 的位图由 Codex（内置图像生成）生成；v0.2 起的立体道具改用本机 Blender 建模渲染（脚本入库，可重出）。参考图只用于对齐质感、光影和配色。要求：原创造型、不出现任何真实品牌名、logo 或标志性外观。

## Blender 渲染（v0.2）

全部由 `design/blender/` 下的脚本用 Blender 命令行渲染（Cycles + Metal、AgX 色彩、透明底 + 阴影接收面），直接写进 `Shared/Art.xcassets`。中间文件在各目录的 `out/`（不入库）；`contact.png` / `preview.png` 是入库的样张。

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/cardbox/make_cardbox.py
```

| 素材 | 脚本 | 资源名 | 用途 |
| --- | --- | --- | --- |
| **卡片盒** | `cardbox/make_cardbox.py`（渲染后运行 `cardbox/gen_swift_hotspots.py` 更新 `CardBoxHotspots.swift`） | `CardBoxBase`（盒子 + 卡片 + 分隔卡）、`CardBoxFront`（前挡板，叠在抽出的卡片上面） | 相册「卡片盒」视图：浅山毛榉木盒、指接榫、把手孔里插着笔、A–Z 与 # 分隔卡、带横线的索引卡；2000×1500，3/4 俯视，盒子靠左上、右下留出阴影的空间，阴影在画布边缘之前淡到全透明（`studio.fade_shadow_edges`） |
| 卡片盒热点 | `cardbox/hotspots.json` | （随代码使用） | 27 张分隔卡标签的中心与四角、盒口四边形、盒子外框（归一化，原点左上）：悬停提示、点字母抽卡、卡片从盒口飞出的位置 |
| **胶卷罐 / 相纸盒** | `canisters/make_canisters.py`（工具库 `canisters/studio.py`） | `FilmCanister-<胶卷 id>`（26 卷 + `custom`） | 刘海胶卷柜、菜单栏菜单、设置里的胶卷卡片：35mm 罐（标签按胶卷配色与感光度生成）、即显相纸盒、照相亭相纸盒；384×384 |
| **大头贴机零件** | `booth/make_booth.py` | `BoothPanel`（@2x，九宫格 56 点）、`BoothMarquee`、`BoothLeverLeft` / `BoothLeverRight`、`BoothArrow` / `BoothArrowPressed`、`BoothStart` / `BoothStartLit` / `BoothStartPressed` | 选相框面板、招牌、拨杆、箭头、开始按钮；都不带地面阴影 |
| **软木（柔和）** | `textures/make_cork.py` | `CorkSoft`（1024×1024，@2x） | 软木板的板面：Voronoi 颗粒 + 浅缝 + 细噪声 + 稀疏小深点，低反差暖色；UV 映射到四维环面取 4D 噪声，四边无缝 |
| 相册视图图标 | `icons/make_icons.py` | `ModeIconCork`、`ModeIconCardBox`、`ModeIconFilm`、`ModeIconCalendar` | 相册顶栏的四种看法：软木板、卡片盒、胶卷、挂历；160×160 |
| 图钉 | `props/make_props.py`（小道具一律不带地面阴影，阴影由界面按轮廓画） | `PinBrass`（黄铜平头钉）、`PinTerracotta` / `PinMustard` / `PinTeal`（彩色地图钉） | 软木板上钉照片；128×128 |
| 木夹 | 同上 | `Clothespin` | 胶片光台、软木板上夹照片；96×192 |
| 放大镜 | 同上 | `Loupe` | 胶片光台上的放大镜外圈（中间透明，放大的画面放在下面）；512×512 |

只重渲几卷胶卷：`... make_canisters.py -- --stock midnight-1600,neon-800`（联系表仍排全部胶卷，其余用 `out/` 里上次的图）。

## Codex 生成（v0.1）

| 素材 | 文件 | 用途 |
| --- | --- | --- |
| **App 图标（矢量源文件）** | `design/icon/nocchi-icon.svg`（手写 SVG） | CI 用 `scripts/ci/render-icons.sh` 渲染出 macOS 全尺寸（圆角方块 + 阴影）与 iOS 1024（满版、无透明通道）；PNG 不入库 |
| 旧版写实图标（备用） | `design/generated/app-icon-v3.png`、`app-icon-mac-1024.png` | 已不再使用 |
| 即显相机机身 | `design/generated/camera-instant-v3.png` → `Shared/Art.xcassets/CameraInstant` | iPhone 主界面（镜头里放实时取景）、相机柜 |
| 大头贴机 | `design/generated/camera-booth-v3.png` → `Shared/Art.xcassets/CameraBooth` | 相机柜 |
| 软木板纹理 | `design/generated/texture-cork.png` → `CorkTexture` | 相册背景 |
| 相纸纹理 | `design/generated/texture-paper.png` → `PaperTexture` | 相纸白边的纸感 |
| 陶土橙丝绒布帘 | `design/generated/texture-curtain-v2.png` → `CurtainTexture` | 旧版 2D 布帘（备用） |
| 陶土橙丝绒面料 | `design/generated/texture-velvet.png` → `VelvetTexture` | 3D 布帘的面料 |
| 胡桃木纹理 | `design/generated/texture-wood.png` → `WoodTexture` | 3D 卡片盒抽屉 |
| 80 年代方盒款机身 | `design/generated/camera-vintage.png` → `CameraVintage`（部件坐标 `design/camera-vintage-parts.json`） | 第二种机身外观 |

## 截图样片（Codex 生成，v1.0）

`design/screenshots/samples/` 里 11 张原创样片（1280px JPEG），只给截图工作室用：拿铁、窗台上的猫、雨夜小巷、海边日落、樱花、公园里的柯基、黄墙下的单车、仙女棒、郁金香、晨雾湖面，以及一张 2 × 2 的大头贴四连拍（虚构人物，截图时切成四格）。全部由 Codex 的图像生成按「普通手机随手拍、自然色彩、无文字无品牌」的要求生成，原图（PNG）不入库。截图里的胶卷效果、相纸和模板都是 App 实时冲印的。

## 网页与 README 的图标（SVG，原创）

`design/icons/make_icons.py` 生成，写到 `website/public/icons/`：
- `feature-<name>.svg`（9 个）：文档站首页功能卡片用的搪瓷小砖——macOS 圆角瓷砖式、DESIGN.md 配色的上下渐变（陶土、芥末、胡桃、石油绿、照相亭红、钴蓝、橄榄、石墨、黄铜）、顶上一道柔光，中间象牙白的线条图形。
- `glyph-<name>.svg`（23 个）：README 导航与各节标题用的单色线条图形（浅陶土色 #D9744F，GitHub 深浅两种主题都看得清）。
所有图形画在 24 × 24 的格子里、线宽 1.6、圆头圆角，一套笔法；改图形只改脚本里的 `GLYPHS`，再跑一遍。不用 emoji。

## App 图标设计

macOS 圆角瓷砖规格（1024 画布上 824px 圆角方块，圆角 184，带柔和投影），胡桃木色暗底。主体是一台原创的复古旁轴式即显相机：拉丝香槟金属顶板与底板、黑色颗粒皮革机身、带滚花的对焦环和刻度、上方的过片钮和陶土橙快门帽、蜂窝测光窗。一张做旧的毛边相纸（棕褐色调的草地、孤树、两只鸟）从机顶出片口升起，完整地留在画框里。光从左上方来，所有高光与阴影方向一致。

- 源文件：`design/icon/nocchi-icon.svg`，由 `design/icon/generate-icon.py` 生成（毛边、皮革颗粒、滚花等重复细节用代码画，保证精确，也方便调整）。
- CI 用 `scripts/ci/render-icons.sh` 渲染 macOS 全部尺寸；iOS 满版图标由同一文件裁出瓷砖范围、铺满底色得到。

## 配色

象牙白 `#ECE6DA` · 炭黑 `#1E1E1E` · 镜头黑 `#121212` · 陶土橙 `#C4593B` · 细铬 · 桌面浅灰 `#D9D7D3`。

## 部件坐标（分层建模）

`design/camera-instant-parts.json` 记录了机身图上镜头、快门键、闪光灯、取景器、出片口的位置（归一化到图片尺寸，原点左上）。iPhone 版据此把实时取景、玻璃反光、可按下的快门键和闪光灯光晕叠在机身上。换机身图时需要重新测量。

## 生成流程

1. 用参考图（只在本机）+ 文字要求让 Codex 生成透明底 PNG。
2. 允许 Codex 用本地图像工具做后处理：清除透明边缘杂点、把镜头中心填成纯黑圆、统一 1024×1024，并测量镜头位置。
3. macOS 图标由满版图标裁成 824px 圆角方块（圆角 185px）加柔和阴影，再缩放出 16–1024 各尺寸。

## 程序化绘制（不是位图）

- 相纸模板（16 款）与复古贴纸（60 多枚）由 `NocchiKit/Decorate` 用 Core Graphics 实时绘制，任意尺寸都清晰，导出与屏幕一致；不需要位图素材。

## 待生成

- 相机柜其余机身（一次性相机、日期机、半格、双反、针孔、摇摆 3D）。

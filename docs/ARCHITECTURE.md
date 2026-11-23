# 架构

```text
Nocchi/
├── Packages/NocchiKit      共享内核（Swift Package，两个 App 共用，CI 跑单元测试）
├── macOS/                  刘海出片口 App（XcodeGen：macOS/project.yml）
├── iOS/                    灵动岛出片口 App + Live Activity 扩展（XcodeGen：iOS/project.yml）
├── Shared/Art.xcassets     两个 App 共用的原创美术（机身、纹理）
└── design/                 美术源文件与部件坐标
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

## macOS App

| 模块 | 作用 |
| --- | --- |
| `App/` | 菜单栏入口（MenuBarExtra）、全局设置 `AppModel`、配色 `Palette`、照片库与音效服务 |
| `Notch/` | `NotchController`：找到刘海（无刘海屏幕用虚拟刘海），在菜单栏之上放一个透明面板；悬停展开操作面板、自拍取景器、出片口、提示条 |
| `Capture/` | 摄像头（AVFoundation）、屏幕快门（`screencapture -i`）、接管系统截图（NSMetadataQuery）、白屏闪光 |
| `Darkroom/` | 拍摄 → 冲印 → 存档 → 出片的编排 |
| `Photo/` | 桌面照片窗口：出片遮罩、显影计时、拖动与甩动、吸边、桌面层 / 浮动层、白边手写、右键菜单；照片堆 |
| `Booth/` | 大头贴机：布帘、请看镜头、倒数、白屏闪光、四连拍 |
| `Album/` | 软木板相册（按月份） |
| `Settings/` | 相机柜、胶卷（导入 / 导出 `.cube`）、通用设置、关于；全局快捷键 |

窗口层级：刘海面板（菜单栏之上 +3）> 出片中的照片（+2）> 大头贴布帘（+1）> 普通浮动照片 > 桌面层照片。

## iOS App

见 `iOS/` 目录与 `docs/PROGRESS.md`（开发中）：灵动岛位置按安全区估算，岛「张开」成出片口；显影时启动 Live Activity，在灵动岛上显示进度。

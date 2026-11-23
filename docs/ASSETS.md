# 美术素材

所有素材都是原创，由 Codex（内置图像生成）生成，参考图只用于对齐质感、光影和配色。生成时要求：原创造型、不出现任何品牌名、logo、文字、数字或水印。

| 素材 | 文件 | 用途 |
| --- | --- | --- |
| App 图标（iOS，满版） | `design/generated/app-icon-v3.png` → `iOS/Nocchi/Resources/Assets.xcassets/AppIcon` | iPhone 图标 |
| App 图标（macOS，圆角方块 + 阴影） | `design/generated/app-icon-mac-1024.png` → `macOS/Nocchi/Resources/Assets.xcassets/AppIcon`（16–1024 全尺寸） | Mac 图标 |
| 即显相机机身 | `design/generated/camera-instant-v3.png` → `Shared/Art.xcassets/CameraInstant` | iPhone 主界面（镜头里放实时取景）、相机柜 |
| 大头贴机 | `design/generated/camera-booth-v3.png` → `Shared/Art.xcassets/CameraBooth` | 相机柜 |
| 软木板纹理 | `design/generated/texture-cork.png` → `CorkTexture` | 相册背景 |
| 相纸纹理 | `design/generated/texture-paper.png` → `PaperTexture` | 相纸白边的纸感 |
| 陶土橙丝绒布帘 | `design/generated/texture-curtain-v2.png` → `CurtainTexture` | 大头贴机拉帘 |

## 配色

象牙白 `#ECE6DA` · 炭黑 `#1E1E1E` · 镜头黑 `#121212` · 陶土橙 `#C4593B` · 细铬 · 桌面浅灰 `#D9D7D3`。

## 部件坐标（分层建模）

`design/camera-instant-parts.json` 记录了机身图上镜头、快门键、闪光灯、取景器、出片口的位置（归一化到图片尺寸，原点左上）。iPhone 版据此把实时取景、玻璃反光、可按下的快门键和闪光灯光晕叠在机身上。换机身图时需要重新测量。

## 生成流程

1. 用参考图（只在本机）+ 文字要求让 Codex 生成透明底 PNG。
2. 允许 Codex 用本地图像工具做后处理：清除透明边缘杂点、把镜头中心填成纯黑圆、统一 1024×1024，并测量镜头位置。
3. macOS 图标由满版图标裁成 824px 圆角方块（圆角 185px）加柔和阴影，再缩放出 16–1024 各尺寸。

## 待生成

- 80 年代方盒款复古机身（黑色机身 + 香槟银面板，原创造型）——Codex 当日额度用完，额度恢复后补上。
- 相机柜其余机身（一次性相机、日期机、半格、双反、针孔、摇摆 3D）。
- 大头贴装饰贴纸。

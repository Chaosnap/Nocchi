# 美术素材

所有素材都是原创，由 Codex（内置图像生成）生成，参考图只用于对齐质感、光影和配色。生成时要求：原创造型、不出现任何品牌名、logo、文字、数字或水印。

| 素材 | 文件 | 用途 |
| --- | --- | --- |
| **App 图标（矢量源文件）** | `design/icon/nocchi-icon.svg`（手写 SVG） | CI 用 `scripts/ci/render-icons.sh` 渲染出 macOS 全尺寸（圆角方块 + 阴影）与 iOS 1024（满版、无透明通道）；PNG 不入库 |
| 旧版写实图标（备用） | `design/generated/app-icon-v3.png`、`app-icon-mac-1024.png` | 已不再使用 |
| 即显相机机身 | `design/generated/camera-instant-v3.png` → `Shared/Art.xcassets/CameraInstant` | iPhone 主界面（镜头里放实时取景）、相机柜 |
| 大头贴机 | `design/generated/camera-booth-v3.png` → `Shared/Art.xcassets/CameraBooth` | 相机柜 |
| 软木板纹理 | `design/generated/texture-cork.png` → `CorkTexture` | 相册背景 |
| 相纸纹理 | `design/generated/texture-paper.png` → `PaperTexture` | 相纸白边的纸感 |
| 陶土橙丝绒布帘 | `design/generated/texture-curtain-v2.png` → `CurtainTexture` | 大头贴机拉帘 |

## App 图标设计

暗房里亮着陶土橙安全灯；顶部是 MacBook 式的刘海，里面有摄像头和绿色的「营业中」指示灯；一张即显相片正从刘海里吐出来，下半部分还是乳白色（正在显影），白边上有一行手写；下方桌面上散着两张已经冲好的照片。全部是手写矢量（渐变、模糊滤镜、裁切），没有外部图片和字体。

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

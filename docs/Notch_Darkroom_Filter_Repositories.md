# Notch Darkroom｜滤镜、色调与胶片模拟开源项目参考

> 用途：为「刘海冲印店 / Notch Darkroom」建立可扩展的多色调胶卷系统。  
> 整理日期：2026-11-23  
> 重点技术：Swift / SwiftUI、Core Image、Metal、3D LUT (`.cube`)、胶片颗粒、Halation、漏光与显影动画。  
> **说明**：以下链接已核对项目主页可访问；「适合直接集成」不等于已验证与当前 App 的编译兼容性。引入代码或打包滤镜素材前，请核对各项目最新许可证及第三方资源授权。

## ⭐ 优先研究的 5 个仓库

| 优先级 | 项目 | 关键能力 | 在 Notch Darkroom 中的用途 | 链接 |
| --- | --- | --- | --- | --- |
| P0 | **SwiftCube** | `.cube` LUT → Core Image 滤镜 | 自定义胶卷色调的基础加载器 | [GitHub](https://github.com/ronan18/SwiftCube) |
| P0 | **Film Chef** | SwiftUI / Core Image、JSON 胶片配方、特效处理 | 设计可配置的 `FilmRecipe`、胶片效果链 | [GitHub](https://github.com/forjd/film-chef) |
| P0 | **GlassMeter Film Looks** | 30 种胶片模拟、Swift Package、`.cube` LUT | 参考现成胶卷预设及渲染流程 | [GitHub](https://github.com/TrondW/glassmeter-film-looks) |
| P1 | **OpenStill** | macOS 照片编辑、丰富 LUT / 色调组织 | 胶卷分类、预设预览与 UI 参考 | [GitHub](https://github.com/haon-v2/OpenStill) |
| P1 | **Spectral Film LUT** | 从胶片相关数据生成模拟 LUT | 生成自己的原创胶卷色调 | [GitHub](https://github.com/JanLohse/spectral_film_lut) |

## 1. 胶片模拟与多色调预设

### 1.1 [OpenStill](https://github.com/haon-v2/OpenStill)
- **定位**：原生 macOS 照片管理及非破坏性编辑器。
- **参考点**：不同滤镜 / LUT 的分类、预览、照片处理和编辑体验。
- **适用方式**：以**参考界面和预设组织设计**为主；复用具体 LUT 时逐项审查授权。
- **已确认仓库许可证**：MIT；素材可能具有独立授权。

### 1.2 [GlassMeter Film Looks](https://github.com/TrondW/glassmeter-film-looks)
- **定位**：30 种胶片模拟的数据、Swift Package、`.cube` LUT 与 Lightroom Profile。
- **参考点**：胶卷预设、渲染接口、多风格切换。
- **适用方式**：优先评估作为 Swift 滤镜模块或预设素材来源。
- **已确认许可证**：CC BY 4.0；分发和展示时需履行署名等条件。

### 1.3 [Film Chef](https://github.com/forjd/film-chef)
- **定位**：SwiftUI + Core Image 的 macOS 胶片模拟照片编辑器。
- **参考点**：JSON 配方、色彩曲线、颗粒、Halation 等效果的模块化组织。
- **适用方式**：参考 `FilmRecipe` 和渲染管线结构，实现「相机 × 胶卷」分离。
- **已确认许可证**：MIT。

### 1.4 [LIMO Editor](https://github.com/Day1Labs/LIMO-Editor)
- **定位**：基于物理胶片模拟理念的 iOS 照片编辑器。
- **参考点**：胶片成像、Bloom、Halation 和高级视觉处理思路。
- **适用方式**：研究算法和 UI；移植到 macOS 需要评估平台耦合。
- **已确认许可证**：MIT。

### 1.5 [Mareen 400](https://github.com/SMGStudiosLLC/Mareen-400)
- **定位**：Swift + Metal 的胶片模拟，包含多个 Metal 计算内核。
- **参考点**：不完全依赖 LUT 的 GPU 胶片模拟。
- **适用方式**：研究底层着色器和胶片效果，不建议未经许可证评估直接并入闭源应用。
- **已确认许可证**：GPL-3.0。

## 2. LUT 载入与 GPU 图像滤镜引擎

| 项目 | 技术 | 值得学习的部分 | 链接 |
| --- | --- | --- | --- |
| **SwiftCube** | Swift / Core Image | 解析 `.cube`、构建可应用的 Core Image 滤镜 | [GitHub](https://github.com/ronan18/SwiftCube) |
| **LUTzy** | SwiftUI / Core Image | LUT 导入、强度调整、预览及导出 | [GitHub](https://github.com/tsvb/lutzy) |
| **GPUImage3** | Swift / Metal | GPU 图像处理链、色温、色彩调整、查找表 | [GitHub](https://github.com/BradLarson/GPUImage3) |
| **MetalPetal** | Metal / Swift | 多阶段 GPU 滤镜组合与图像处理框架 | [GitHub](https://github.com/MetalPetal/MetalPetal) |
| **Harbeth** | Swift / Metal | 图像、视频、摄像头滤镜与效果参考 | [GitHub](https://github.com/yangKJ/Harbeth) |

**选择建议**：首版采用 **SwiftCube + Apple Core Image** 就能建立基础色调系统；只有在多层实时特效或性能瓶颈出现后，再考虑 GPUImage3 / MetalPetal / 自定义 Metal。不要同时引入多个功能重叠的渲染框架。

## 3. 高级胶片效果 / 原创 LUT 生成

| 项目 | 参考方向 | 特别说明 | 链接 |
| --- | --- | --- | --- |
| **SpektraMac** | Swift + Metal、基于物理的模拟胶片曝光 / 显影 / 印放 | GPL-3.0；底片和相纸数据还涉及 CC BY-SA 4.0 | [GitHub](https://github.com/nainajnahO/SpektraMac) |
| **OpenEmulsion** | 颗粒、Bloom、Halation、胶片响应 | 面向 DaVinci Resolve；主要用于研究算法 | [GitHub](https://github.com/technomancer702/openemulsion) |
| **Spectral Film LUT** | 由胶片数据生成 LUT | 适合批量制作原创色彩配方 | [GitHub](https://github.com/JanLohse/spectral_film_lut) |
| **lut-generator** | 参考图片色调迁移并导出 `.cube` | 适合建立新胶卷的色彩基准；仓库 MIT | [GitHub](https://github.com/skystmm/lut-generator) |

## 4. 可供试验的 LUT 素材库

| 项目 | 内容 | 注意事项 | 链接 |
| --- | --- | --- | --- |
| **Film Emulation LUTs** | 基于 RawTherapee 胶片模拟资料的彩色、黑白 LUT | 仓库标注 MPL-2.0；需核对上游数据授权 | [GitHub](https://github.com/MokshC/Film-Emulation-LUTs) |
| **OpenSourceLuts** | 多种胶片模拟 LUT / 色调资源 | Hugging Face；标注 CC BY-SA 4.0；检查格式和具体文件授权 | [Hugging Face](https://huggingface.co/Norton0924/OpenSourceLuts) |
| **GlassMeter Film Looks** | 30 款胶片模拟对应的 `.cube` 文件 | CC BY 4.0，使用时注意署名 | [GitHub](https://github.com/TrondW/glassmeter-film-looks) |

> **提醒**：LUT 主要改变 RGB 色彩映射，不会单独产生真实的胶片颗粒、漏光、高光光晕或「相纸逐渐显影」的时序动画。这些需要额外的图像处理阶段。

## 5. macOS 刘海交互参考（非滤镜项目）

### [OpenNook](https://github.com/twinkling-reality/opennook)
- **定位**：用于构建 macOS 刘海应用的开源框架。
- **参考点**：刘海区域的窗口行为、展开/收起及桌面层的交互。
- **在本项目的用途**：将滤镜处理后的照片从刘海区域「吐出」；照片下滑、显影、拖动、贴在桌面等动画仍需自己实现。
- **许可证**：仓库包含 Apache-2.0 和 MIT 许可文件，实际复用时核对对应模块。

## 6. 推荐实现组合（首个可交付版本）

```text
Camera / Screenshot
       │
       ▼
Image Input (CIImage)
       │
       ▼
FilmRecipe (JSON)
  ├─ lutFile: "warm-sun-400.cube"
  ├─ lutIntensity: 0.85
  ├─ grain: 0.25
  ├─ halation: 0.12
  ├─ vignette: 0.18
  └─ lightLeak: 0.08
       │
       ▼
SwiftCube + Core Image
       │
       ▼
Film Effects (Grain / Halation / Light Leak)
       │
       ▼
Development Animation (照片逐渐显影)
       │
       ▼
Notch Ejection (SwiftUI / AppKit)
       │
       ▼
Export + Album
```

**建议先做**：

1. 实现标准 `.cube` 加载、滤镜强度滑块与原图对比。
2. 建立统一的胶卷配方 JSON（名称、LUT、颗粒、暗角、漏光、Halation）。
3. 准备 12–20 个色调预设，至少覆盖暖色、冷色、日系淡彩、黑白、褪色、夜景和高反差风格。
4. 完成纯本地照片处理和导出；再加入渐进显影与刘海出片动画。
5. 支持用户导入自己的 `.cube`，并保存为自定义胶卷。

## 7. 建议首批胶卷风格

| 原创胶卷名 | 色调方向 | 附加效果 |
| --- | --- | --- |
| 暖阳 400 | 暖黄、肤色柔和、低对比 | 细颗粒、轻微褪色 |
| 夜航 800 | 冷蓝阴影、保留霓虹高光 | 中颗粒、暗角 |
| 樱雨 200 | 粉紫、低饱和、柔和高光 | 柔焦、细颗粒 |
| 旧报纸 100 | 黑白、高反差 | 明显颗粒 |
| 青苔 400 | 褪绿、低对比 | 轻微漏光 |
| 霓虹 800 | 高饱和、暖红高光 | Halation、夜景颗粒 |

上述名称和参数是**产品设计建议**，不是上述项目现成预设的名称或精确复现参数。

## 8. 许可证与工程落地检查清单

- [ ] 核查**代码**和**照片 / LUT / 预设数据**是否使用不同许可证。
- [ ] 核查 GPL、CC BY-SA 等共享或署名义务是否适用于目标分发方式。
- [ ] 确认所用资源可用于商业项目，并保留第三方许可与署名文本。
- [ ] 统一 LUT 所需输入色彩空间（如 sRGB），避免相同 LUT 在不同图片上明显偏色。
- [ ] 验证 `.cube` 格点大小、通道顺序、插值和滤镜强度混合。
- [ ] 大图导出使用高质量管线；预览使用低分辨率缓存，不阻塞 SwiftUI 动画。
- [ ] 相纸显影动画与实际最终导出结果保持一致。
- [ ] 用户导入 LUT 时检查文件大小、解析错误与异常数据。

---

**快速入口**：

- 首先看 **[Film Chef](https://github.com/forjd/film-chef)**：胶卷配方如何组织。
- 然后看 **[SwiftCube](https://github.com/ronan18/SwiftCube)**：如何加载 `.cube`。
- 再看 **[GlassMeter Film Looks](https://github.com/TrondW/glassmeter-film-looks)**：如何获得多种胶卷色调。
- 最后看 **[OpenNook](https://github.com/twinkling-reality/opennook)**：把「出片口」放到 macOS 刘海。

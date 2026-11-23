<p align="center">
  <img src="design/icon/nocchi-icon.svg" width="160" alt="Nocchi icon">
</p>

<h1 align="center">Nocchi · 刘海冲印店</h1>

<p align="center">
  把 MacBook 的刘海当成一台复古相机的出片口：截图或自拍之后，照片从刘海里「吐」出来，像真相纸一样慢慢显影。<br>
  iPhone 版用灵动岛当出片口。
</p>

<p align="center">
  <a href="https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml"><img src="https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-%E9%9D%9E%E5%95%86%E7%94%A8-C4593B" alt="License: noncommercial"></a>
  <a href="https://github.com/Chaosnap/Nocchi/releases"><img src="https://img.shields.io/github/v/release/Chaosnap/Nocchi?color=4A3021" alt="Release"></a>
</p>

## 现在做到哪了

👉 **[docs/PROGRESS.md](docs/PROGRESS.md)**：进度看板，每次推送都会更新。

## 怎么试用

本项目采用 **GitHub Actions-Only** 工作流：本地不编译、不测试，所有构建都在 CI 完成。

- **正式版本**：[Releases](https://github.com/Chaosnap/Nocchi/releases) 下载 `Nocchi-macOS-<版本>.zip`（首次打开见 [docs/CI.md](docs/CI.md#macos-测试版)）。
- **最新构建**：[Actions → CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml) 里最新的绿色运行 → Artifacts。

## 玩法速览（macOS）

| 操作 | 方式 |
| --- | --- |
| 打开操作面板 | 鼠标移到刘海上 |
| 屏幕快门（框选截图） | ⌃⌥⌘S |
| 自拍 | ⌃⌥⌘F（空格拍照，Esc 取消） |
| 大头贴机（四连拍） | ⌃⌥⌘B |
| 加速显影 | 按住照片来回甩（甩太猛会出现色块） |
| 贴在屏幕边缘 | 把照片拖到屏幕边上 |
| 在白边上写字 | 右键 → 在白边上写字 |
| 打开成片 | 双击照片（在 Finder 中显示） |

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `Packages/NocchiKit` | 共享暗房内核：胶卷配方、LUT、Core Image 管线、显影、甩动、相纸合成、照片库、音效 |
| `macOS/` | Mac App（刘海出片口），XcodeGen 描述 `project.yml` |
| `iOS/` | iPhone App（灵动岛出片口）与 Live Activity |
| `Shared/Art.xcassets` | 两端共用的原创美术 |
| `design/` | 美术源文件、部件坐标 |
| `docs/` | 构想、参考项目、架构、决策、胶卷、素材、CI |

## 文档

- [产品构想](docs/notch-camera-concept.md) · [滤镜与胶片模拟参考项目](docs/Notch_Darkroom_Filter_Repositories.md)
- [架构](docs/ARCHITECTURE.md) · [决策记录](docs/DECISIONS.md) · [胶卷](docs/FILM_STOCKS.md) · [美术素材](docs/ASSETS.md) · [CI](docs/CI.md)
- [更新日志](CHANGELOG.md) · [协作规则](CLAUDE.md)

## 参与

- [贡献指南](CONTRIBUTING.md) · [行为准则](CODE_OF_CONDUCT.md) · [安全政策](SECURITY.md) · [隐私说明](PRIVACY.md)
- 问题与建议请用 [Issue](https://github.com/Chaosnap/Nocchi/issues/new/choose)；安全问题请私下报告。

照片只保存在本机，不上传。

## 许可

© 2026 Chaosnap。**非商业用途随便用**——使用、修改、分享都可以，保留版权声明 / 注明出处即可；**商业用途需要书面许可**（请开 Issue 联系）。

- **代码**：[PolyForm Noncommercial License 1.0.0](LICENSE)。
- **美术素材**（App 图标、机身、纹理、3D 渲染等，位于 `Shared/Art.xcassets/`、`design/`）：[CC BY-NC 4.0](LICENSE-ASSETS.md)。
- 这是「源码公开、非商用」的许可，不属于 OSI 定义的开源许可证。
- 胶卷、机身和相纸模板的名字都是原创的，与任何相机或胶片厂商无关。

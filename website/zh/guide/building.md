# 云端构建

Nocchi 从不在任何人自己的电脑上构建或测试。编译、测试、打包、发布全部由 GitHub Actions 完成，每一个下载都来自公开、可重复的构建。

| 工作流 | 什么时候 | 做什么 |
| --- | --- | --- |
| [CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml) | 每次推送 | 跑 `NocchiKit` 单元测试，用 XcodeGen 生成 Xcode 工程，构建 macOS App（Release、ad-hoc 签名）并作为构建产物上传 |
| [Release](https://github.com/Chaosnap/Nocchi/actions/workflows/release.yml) | 推送 `vX.Y.Z` 标签 | 测试，从 SVG 源文件渲染图标，用标签里的版本号构建，发布 `Nocchi-macOS-<版本>.zip` 和 `SHA256SUMS.txt`，说明取自更新日志 |
| [Screenshots](https://github.com/Chaosnap/Nocchi/actions/workflows/screenshots.yml) | App 有改动时 | 构建 App 并运行截图模式：用真实的胶卷和模板冲印原创样片，App 截下自己的窗口和面板，图片提交到 `website/public/screenshots` |
| [Pages](https://github.com/Chaosnap/Nocchi/actions/workflows/pages.yml) | 网站或截图有改动时 | 用 VitePress 构建这个网站，发布到 GitHub Pages |

## 拿到构建

- **正式版本**：[最新的 Release](https://github.com/Chaosnap/Nocchi/releases/latest)。
- **最新的提交**：打开 [CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml) 里一次绿色的运行，下载 `Nocchi-macOS` 构建产物（需要登录 GitHub）。

## 仓库里有什么

| 路径 | 内容 |
| --- | --- |
| `Packages/NocchiKit` | 两个 App 共用的暗房内核：胶卷配方与 3D LUT、Core Image 管线、显影与甩动检测、相纸合成、模板、贴纸、照片库、程序合成的音效 |
| `macOS/` | Mac App，刘海就是出片口 |
| `iOS/` | iPhone App 与 Live Activity（正在做） |
| `Shared/Art.xcassets` | 原创美术：机身、纹理、Blender 渲染图 |
| `design/` | 图标的 SVG 源文件、Blender 脚本、截图用的样片 |
| `website/` | 这个网站 |

开发文档（[进度看板](https://github.com/Chaosnap/Nocchi/blob/main/docs/PROGRESS.md)、设计规范、架构、决策记录）都是中文的。

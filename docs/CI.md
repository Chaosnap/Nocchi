# GitHub Actions-Only CI

本项目**不在本地构建或测试**。所有编译、单元测试和打包都由 `.github/workflows/ci.yml` 在 GitHub 托管的 macOS 机器上完成。

## 触发

| 事件 | 分支 |
| --- | --- |
| push | `main`（日常开发分支）以及 `feat/**`、`fix/**` |
| pull_request | 目标为 `main` |
| 手动 | Actions 页面 → CI → Run workflow |

同一分支的新推送会取消旧的运行（`concurrency`）。

## 任务

| 任务 | 做什么 | 产物 |
| --- | --- | --- |
| `NocchiKit · swift test` | 在 `Packages/NocchiKit` 运行 `swift test` | — |
| `macOS app · build` | `xcodegen` 生成工程 → Release 构建（通用二进制，ad-hoc 签名）→ zip | `Nocchi-macOS`（保留 14 天） |
| `iOS app · build` | `xcodegen` 生成工程 → Release 构建（通用 iOS 设备，未签名）→ ipa | `Nocchi-iOS-unsigned`（保留 14 天） |

运行环境：`macos-15`，Xcode 选 `latest-stable`（`maxim-lobanov/setup-xcode`）。XcodeGen、xcbeautify 用 Homebrew 安装。

## 发行版（Release）

`.github/workflows/release.yml`：

1. 推送标签 `vX.Y.Z`（或在 Actions 页面手动运行 Release 并填写版本号）。
2. 工作流跑 NocchiKit 测试 → 从 SVG 渲染图标 → Release 构建 macOS App（版本号取自标签，构建号取自运行序号）→ 打包 zip 与 `SHA256SUMS.txt`。
3. 从 `CHANGELOG.md` 取对应版本的一节作为发布说明，创建 GitHub Release 并上传附件。

## 截图（Screenshots）

`.github/workflows/screenshots.yml`：`macOS/**`、`Packages/**`、`Shared/**`、`design/screenshots/**` 有改动推到 `main` 时运行。

1. 和 CI 一样构建 macOS App（Release、ad-hoc 签名）。
2. `scripts/ci/render-screenshots.sh` 用隐藏的截图模式启动 App：`Nocchi --render-screenshots <目录>`，照片库放在临时目录（`NOCCHI_LIBRARY_ROOT`），样片来自 `design/screenshots/samples`（`NOCCHI_SCREENSHOT_SAMPLES`）。App 不开刘海、不注册快捷键，用真实的胶卷和模板冲印 13 张样片，然后：
   - 打开真实的相册（四种看法）、装饰台、设置窗口和刘海面板（悬停面板、胶卷柜），向窗口服务器要自己窗口的画面（自己的窗口不需要屏幕录制权限），拿不到时退回 `cacheDisplay`，再放到桌面壁纸上；
   - 用 `ImageRenderer` 以 2 倍像素合成「刘海出片 + 照片堆」的桌面、相纸一览和大头贴「选相框」。
   代码在 `macOS/Nocchi/Screenshots/`，8 分钟看门狗。每张图的尺寸、拍法和灰度标准差会写成运行页面上的注解（`SHOT …`）。
   同一个 App 再用英文界面拍一遍（`-app.language en -AppleLanguages (en)`，照片库另放一个临时目录），顺便验收翻译。
3. JPEG 提交到 `website/public/screenshots/`（中文界面）和 `website/public/screenshots/en/`（英文界面），github-actions[bot] 提交，图没变就不提交。文档站中文页（`/zh/`）用前者，英文页和 README 用后者；文档站构建时缺的图（包括 `en/` 下的）先放纸色占位图。

## 文档站（Pages）

`.github/workflows/pages.yml`：`website/**` 有改动、截图工作流跑完、或手动运行时，用 VitePress 构建 `website/`（英文在根目录，中文在 `/zh/`）并发布到 GitHub Pages：<https://chaosnap.github.io/Nocchi/>。还没渲染出来的截图会先放纸色占位图，构建不会因为缺图失败。第一次需要在仓库 **Settings → Pages → Build and deployment → Source** 选「GitHub Actions」。

## 读取失败原因

- 编译错误由 `xcbeautify --renderer github-actions` 转成带文件和行号的注解。
- 任何任务失败时，`scripts/ci/annotate-failure.sh` 会把日志里的错误行和日志尾部写成一条注解。
- `swift test` 这一步单独限时 12 分钟（平时不到 2 分钟）。测试进程的 stdout 在 CI 上是整块缓冲的，被杀掉时最后一段输出会丢，所以测试里还有一只看门狗（`Tests/NocchiKitTests/HangWatchdog.swift`）：任何测试超过 90 秒，就先把缓冲写出去、在 stderr 打出 `⏱ HANG: <测试名>` 再结束进程，注解里能直接看到是哪个测试卡住。
- 仓库是公开的，注解可以不登录直接通过 REST API 读取：

```bash
curl -s "https://api.github.com/repos/Chaosnap/Nocchi/actions/runs?branch=main&per_page=1"
```

```bash
curl -s "https://api.github.com/repos/Chaosnap/Nocchi/check-runs/<job_id>/annotations"
```

## 下载构建产物

- **正式版本**：[Releases](https://github.com/Chaosnap/Nocchi/releases) 页面直接下载（不需要登录）。
- **每次推送的构建**：打开 [Actions → CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml)，点进最新的绿色运行，页面底部 **Artifacts** 里下载（需要登录 GitHub）。

### macOS 测试版

CI 产物是 ad-hoc 签名、未公证的 App。解压后第一次打开：

```bash
xattr -dr com.apple.quarantine ~/Downloads/Nocchi.app
```

然后把 `Nocchi.app` 拖进「应用程序」再打开。也可以在「系统设置 → 隐私与安全性」里点「仍要打开」。

首次使用会请求：摄像头（自拍、大头贴）、屏幕录制（屏幕快门）、桌面文件夹（接管系统截图时）。ad-hoc 签名每次构建都不同，所以换新构建后系统可能会再问一次。

### iOS 测试版

`Nocchi-iOS-unsigned.ipa` 没有签名，需要用你自己的开发者证书重签后安装（例如 Xcode、Sideloadly、AltStore）。正式分发需要在 CI 中配置签名证书与描述文件，见 `docs/DECISIONS.md` 的后续计划。

## 本地只做什么

- 编辑代码与文档、生成美术素材。
- 不在本地运行 `xcodegen`、`xcodebuild`、`swift build`、`swift test`；工程文件只在 CI 里由 `project.yml` 生成。

# GitHub Actions-Only CI

本项目**不在本地构建或测试**。所有编译、单元测试和打包都由 `.github/workflows/ci.yml` 在 GitHub 托管的 macOS 机器上完成。

## 触发

| 事件 | 分支 |
| --- | --- |
| push | `main`、`develop`、`feat/**`、`fix/**` |
| pull_request | 目标为 `main` 或 `develop` |
| 手动 | Actions 页面 → CI → Run workflow |

同一分支的新推送会取消旧的运行（`concurrency`）。

## 任务

| 任务 | 做什么 | 产物 |
| --- | --- | --- |
| `NocchiKit · swift test` | 在 `Packages/NocchiKit` 运行 `swift test` | — |
| `macOS app · build` | `xcodegen` 生成工程 → Release 构建（通用二进制，ad-hoc 签名）→ zip | `Nocchi-macOS`（保留 14 天） |
| `iOS app · build` | `xcodegen` 生成工程 → Release 构建（通用 iOS 设备，未签名）→ ipa | `Nocchi-iOS-unsigned`（保留 14 天） |

运行环境：`macos-15`，Xcode 选 `latest-stable`（`maxim-lobanov/setup-xcode`）。XcodeGen、xcbeautify 用 Homebrew 安装。

## 读取失败原因

- 编译错误由 `xcbeautify --renderer github-actions` 转成带文件和行号的注解。
- 任何任务失败时，`scripts/ci/annotate-failure.sh` 会把日志里的错误行和日志尾部写成一条注解。
- 仓库是公开的，注解可以不登录直接通过 REST API 读取：

```bash
curl -s "https://api.github.com/repos/Chaosnap/Nocchi/actions/runs?branch=develop&per_page=1"
```

```bash
curl -s "https://api.github.com/repos/Chaosnap/Nocchi/check-runs/<job_id>/annotations"
```

## 下载构建产物

1. 打开 [Actions → CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml)，点进最新的绿色运行。
2. 页面底部 **Artifacts** 里下载 `Nocchi-macOS` 或 `Nocchi-iOS-unsigned`（需要登录 GitHub）。

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

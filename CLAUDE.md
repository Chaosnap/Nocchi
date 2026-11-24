# Nocchi · 代理工作守则

本文件给参与本仓库开发的 AI 代理（Claude Code、Codex 等）和人类协作者阅读。

## 1. 开发流程：GitHub Actions-Only CI

- **严格禁止本地构建与测试。** 不在本机运行 `xcodebuild`、`swift build`、`swift test`、`xcodegen`，也不启动模拟器或真机调试。
- 所有编译、单元测试、打包都由 `.github/workflows/ci.yml` 在 GitHub Actions 上完成。
- 直接在 `main` 上开发并推送（仓库所有者 2026-11-23 的决定），每次推送 CI 自动运行；`develop` 分支已停用。
- 发行版：CI 全绿后推送 `vX.Y.Z` 标签，`.github/workflows/release.yml` 会构建并发布 GitHub Release（附 macOS zip 与 SHA-256）。发版前在 `CHANGELOG.md` 写好 `## [X.Y.Z]` 一节。
- 读取 CI 结果：仓库是公开的，可以用 GitHub REST API 读取运行状态和 Check Run 注解。失败时 `scripts/ci/annotate-failure.sh` 会把日志尾部写成注解，便于在没有登录的情况下读取错误。
- 每次 CI 失败都要修到绿色再继续堆功能。

## 2. 文档必须实时更新

每次推送前同步更新：

- `docs/PROGRESS.md`：进度看板（状态、里程碑、最近更新、下一步、已知问题）。
- `CHANGELOG.md`：用户可感知的变化。
- 受影响的设计/架构文档：`docs/ARCHITECTURE.md`、`docs/DECISIONS.md`、`docs/FILM_STOCKS.md`、`docs/ASSETS.md`、`docs/CI.md`。

目标：仓库所有者随时打开仓库，都能看懂现在做到哪、怎么拿到构建产物、下一步做什么。

## 3. 仓库结构

| 路径 | 内容 |
| --- | --- |
| `Packages/NocchiKit` | 共享 Swift Package：胶卷引擎、`.cube` 解析、显影模型、甩动检测、声音合成、相纸排版、照片库 |
| `macOS/` | macOS App（刘海出片口），XcodeGen 工程描述 `project.yml` |
| `iOS/` | iPhone App（灵动岛出片口）与 Live Activity 小组件扩展 |
| `design/` | 原创美术素材的源文件（Codex 生成）、截图样片 |
| `docs/` | 产品构想、参考项目、架构、进度、决策记录 |
| `website/` | 产品文档站（VitePress，默认英文、`/zh/` 中文；截图由 `screenshots.yml` 从 App 渲染） |

## 4. 内容与版权

- `Ref_Image/` 是第三方参考图，**不提交**到公开仓库。
- 机身、相纸、图标等素材必须原创；不得使用真实相机或胶片品牌的名称、logo 和标志性外观。
- 胶卷色调由参数配方在运行时生成 3D LUT，不打包第三方 LUT 文件；引入第三方代码前先核对许可证，必须与 AGPL-3.0 兼容。
- 许可：本仓库采用 GNU AGPL-3.0（`LICENSE`，与仓库所有者的 Yohaku 仓库一致）。贡献按同一许可授权（见 `CONTRIBUTING.md`）；引入第三方内容时注明其原始许可。
- 面向仓库访客的文件（`README.md`、`CODE_OF_CONDUCT.md`、`CONTRIBUTING.md`、`SECURITY.md`、`PRIVACY.md`、`.github/` 模板）用英文；开发文档（`docs/`、`CHANGELOG.md`、本文件）和 App 界面仍用简体中文。
- 视觉方向是「复古」，不是手绘风格；设计规范与跨模块接口见 `docs/DESIGN.md`。

## 5. 代码约定

- Swift 5 语言模式，macOS 14+ / iOS 17+。
- 可测试的逻辑放进 `NocchiKit`，App 层尽量薄。
- UI 文案用简体中文。

# 参与贡献

谢谢你愿意帮 Nocchi 变得更好。开始之前请先看：

- [README](README.md)：项目是什么、怎么试用；
- [进度看板](docs/PROGRESS.md)：现在做到哪、下一步做什么；
- [设计规范](docs/DESIGN.md)：视觉语言与跨模块接口（复古，不要手绘风格）；
- [行为准则](CODE_OF_CONDUCT.md)。

## 开发流程：只在 GitHub Actions 上构建

本项目**不在本地构建或测试**（不运行 `xcodebuild`、`swift build`、`swift test`、`xcodegen`，也不启动模拟器）。编译、单元测试、打包全部由 [`.github/workflows/ci.yml`](.github/workflows/ci.yml) 完成，详见 [docs/CI.md](docs/CI.md)。

1. Fork 本仓库，在你的 fork 里新建分支（例如 `feat/sticker-pack`、`fix/notch-size`）。
2. 修改代码与文档，推送到你的 fork，确认 CI 全绿。
3. 向 `main` 发起 Pull Request，按模板填写。维护者会在 CI 全绿后合并。

仓库所有者本人直接在 `main` 上开发；发行版在 CI 全绿后由所有者推送 `vX.Y.Z` 标签生成。

## 每次提交都要更新文档

- `docs/PROGRESS.md`：状态、最近更新、下一步、已知问题；
- `CHANGELOG.md`：用户能感知到的变化（写在「未发布」下面）；
- 受影响的设计 / 架构文档：`docs/ARCHITECTURE.md`、`docs/DECISIONS.md`、`docs/DESIGN.md`、`docs/FILM_STOCKS.md`、`docs/ASSETS.md`、`docs/CI.md`。

## 代码约定

- Swift 5 语言模式，macOS 14+ / iOS 17+。
- 能测试的逻辑放进 `Packages/NocchiKit`，并配单元测试；App 层尽量薄。
- 界面文案用简体中文。
- 跨模块接口写在 `docs/DESIGN.md` §15，改接口时同步更新。
- 提交信息参考已有风格：`feat(mac): …`、`fix(kit): …`、`design(icon): …`、`docs: …`、`chore(ci): …`。

## 美术与版权

- 所有素材必须是**原创**：不使用真实相机或胶片品牌的名称、logo 和标志性外观；胶卷色调用参数配方生成，不打包第三方 LUT。
- 第三方参考图只留在本地的 `Ref_Image/`，**不要提交**。
- 引用开源代码前先核对许可证；GPL、CC BY-SA 等「传染性」许可的代码不直接并入。
- 美术素材不在 Apache-2.0 范围内，保留所有权利，见 [LICENSE-ASSETS.md](LICENSE-ASSETS.md)。

## 许可

- 你提交的代码按 [Apache License 2.0](LICENSE) 第 5 条授权给本项目。
- 你提交的美术素材按 [LICENSE-ASSETS.md](LICENSE-ASSETS.md) 的条款授权给本项目。

## 报告问题

- Bug 与功能建议：用 [Issue 模板](https://github.com/Chaosnap/Nocchi/issues/new/choose)。
- 安全问题：**不要开公开 Issue**，请按 [SECURITY.md](SECURITY.md) 私下报告。

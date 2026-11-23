# 安全政策

## 支持的版本

只有 [Releases](https://github.com/Chaosnap/Nocchi/releases) 里的**最新版本**会收到安全修复。

## 报告漏洞

请**不要**在公开的 Issue、讨论或 PR 里披露安全问题。

用 GitHub 的私密漏洞报告：打开本仓库的 **Security → Report a vulnerability**（[直达链接](https://github.com/Chaosnap/Nocchi/security/advisories/new)），写清楚：

- 受影响的版本与系统版本；
- 复现步骤或概念验证；
- 可能造成的影响。

我们会尽量在 7 天内回复，确认问题后尽快修复，并在修复发布后（征得你同意时）致谢。

## 适用范围

Nocchi 完全在本机运行，不联网、不上传照片（见 [PRIVACY.md](PRIVACY.md)）。特别欢迎以下方面的报告：

- 读取外部文件时的问题（拖到刘海上的图片、导入的 `.cube` LUT、照片库记录）；
- 权限相关的问题（摄像头、屏幕录制、文件夹访问）；
- 覆盖层（自拍、大头贴机、白屏闪光）导致无法退出或无法操作系统的问题。

CI 构建产物是 ad-hoc 签名、未经公证的测试版本，这一点是已知的，不算漏洞。

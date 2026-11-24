# 常见问题

## 我的 Mac 一定要有刘海吗？

不用。在没有刘海的 Mac 和显示器上，Nocchi 会在屏幕顶部正中画一个小小的虚拟刘海，用法完全一样。

## 照片在哪里？

成片是 `~/Pictures/Nocchi/<年-月>/` 里的 JPEG。记录、底片和装饰在 `~/Library/Application Support/Nocchi/`。什么都不会离开你的 Mac。

## 为什么 macOS 说无法检查这个 App？

现在的版本是 ad-hoc 签名，还没有公证。运行 `xattr -dr com.apple.quarantine /Applications/Nocchi.app`，或者在「系统设置 → 隐私与安全性」里点「仍要打开」。打开之前先用同一个版本里的 `SHA256SUMS.txt` 核对一下 zip。

## 怎么退出？

Nocchi 在前台时按 <kbd>⌘Q</kbd>，或者点菜单栏里的光圈图标 →「退出 Nocchi」。每个覆盖层（自拍、大头贴机、闪光）也都认 <kbd>Esc</kbd> 和 <kbd>⌘Q</kbd>。

## 能用自己的 LUT 吗？

能：「设置 → 胶卷 → 导入 .cube 胶卷…」把 `.cube` 文件变成一卷自定义胶卷。Nocchi 自带的胶卷是配方而不是 LUT 文件，每一卷都能导出成 `.cube`。

## 相片做好了还能改吗？

能。装饰都和照片一起存着，在装饰台上随时可以换模板、改题字、挪贴纸、擦笔迹，成片会从底片重新合成。只有甩太猛出现的色块会一直留着。

## 为什么界面是中文？

Nocchi 先做的是中文版。这份文档有 [English](/) 和中文。

## 有 iPhone 版吗？

正在做：在 iPhone 上，灵动岛就是出片口，Live Activity 会显示显影进度。

## 免费吗？

Nocchi 是自由软件，采用 GNU AGPL-3.0 许可。源代码在 [GitHub](https://github.com/Chaosnap/Nocchi) 上。

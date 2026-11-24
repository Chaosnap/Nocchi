# Nocchi 设计规范 · v0.2「复古冲印店」

> 这是 v0.2 改版的设计与接口约定。写代码、做美术之前先读这份文档；设计改了要同步改这里。
> 仓库所有者的硬性要求：**复古，不要手绘风格**；审美要到资深美术指导的水准；所有构建与测试只在 GitHub Actions 上跑。

## 0. 总原则

1. **复古，不是手绘。** 视觉语言来自真实的老物件：胶片、相纸、黄铜、胡桃木、软木、牛皮纸、凸版印刷、打字机、日期机的橙色数字、70 年代配色、网点与颗粒。**不要**线稿涂鸦、草图插画、手写体界面文字。（相纸白边上的「手写题字」和用户自己的「涂鸦」是功能，保留。）
2. **物件感。** 能做成「东西」的都做成东西：Blender 渲染的 3D 物件或分层 2.5D。全局统一 **左上方暖光**，阴影落向右下；每个物件两层阴影：贴地的接触阴影（半径 1–2、不透明度 0.25–0.35）+ 柔和投影（半径 10–24、y 偏移 6–14、不透明度 0.2–0.3）。
3. **克制。** 一屏一个主角；装饰服务于照片。动效一律弹簧（`response` 0.35–0.6，`dampingFraction` 0.75–0.85），出现 / 消失配合 opacity + scale(0.96…1)。
4. **原创。** 不出现任何真实相机 / 胶片品牌名、logo 与标志性外观（不用宝丽来彩虹条、不用柯达黄红、不用富士绿）。参考网站只借鉴功能。
5. **简体中文文案**，语气温和简短（「装上了 奶油 600」「没有找到『咖啡』」）。

## 1. 设计令牌

### 1.1 颜色（`macOS/Nocchi/App/Palette.swift`，NocchiKit 里用十六进制字符串）

| 令牌 | 值 | 用途 |
| --- | --- | --- |
| `ivory` / `ivoryLight` / `ivoryShade` | #ECE6DA / #F2EEE6 / #D9D1C2 | 机身、按钮、托盘 |
| `paper` / `paperDeep` | #F4EEE1 / #EAE2D2 | 相册、装饰台检查器、挂历纸 |
| `ink` / `inkSoft` | #2E2924 / #7A6F64 | 正文 / 次要文字 |
| `hairline` | #D8CFBF | 发丝线 |
| `charcoal` / `lensBlack` | #1E1E1E / #121212 | 刘海、镜头 |
| `terracotta` / `terracottaLight` | #C4593B / #E8896B | 唯一的强调色：选中、主按钮、快门 |
| `mustard` `petrol` `olive` `cobalt` | #D9A441 #2F5F5C #6F6A3A #2F4C8A | 70 年代辅助色（贴纸、模板、颜料） |
| `printRed` | #B23A2A | 挂历周末、印章红 |
| `dateOrange` | #E8892F | 日期机数码字、胶片片边字 |
| `walnut` / `walnutLight` / `walnutDeep` | #4A3021 / #7A5236 / #2A1C14 | 木框、桌面 |
| `brass` / `brassLight` | #B8955A / #E3C98F | 金属件、导航小按钮 |
| `leather` | #2A211B | 装饰台工具托盘 |
| `lightbox` / `lightboxEdge` | #FFF8EA / #F0E4CB | 光台 |

### 1.2 字体（`RetroFont`）

| 角色 | 字体 | 例子 |
| --- | --- | --- |
| 大号数字 / 拉丁标题 | Didot | 挂历的「11」、相册字标 NOCCHI |
| 中文标题 | Songti SC | 「卡片盒」「十一月」 |
| 日期、编号、片边字、标签 | American Typewriter | 2026/11/23、No. 0427 |
| 计数 / 规格 | Courier New | 7/10 |
| 凸字标签带 | Futura Condensed ExtraBold（白字） | 软木板的月份标签 |
| 界面控件 | 系统字体 `.rounded` | 按钮、开关 |

相纸题字字体（`CaptionFont`）：`手写`（Bradley Hand，中文回落到系统手写 / 楷体）、`打字机`（American Typewriter，中文回落宋体）、`铅字`（Baskerville，中文宋体）。

### 1.3 质感

- 纸：底色 + 极细颗粒（不透明度 3–5%）+ 四周 2–4% 做旧暗角。
- 木：`WoodTexture`（胡桃木）+ 内外倒角高光 / 阴影。
- 金属：线性渐变 + 一道细高光；黄铜偏暖，铬偏冷。
- 印刷品（贴纸、模板图样）：平涂复古色 + 轻微套色错位（0.5–1.5px）+ 网点或纸纹 + 白色模切边（贴纸）。

## 2. 刘海：灵动岛的比例

问题：启动提示是一条横贯屏幕顶部的黑条（约 520pt 宽），不像灵动岛。规则：

- `idle`：等于硬件刘海（`NotchMetrics.rect`），不画任何东西。
- **紧凑提示**（短文字，≤ 8 个汉字左右）：高度 = 刘海高度；宽度 = 刘海宽 + 2 × 翼宽，翼宽 = clamp(文字宽 + 22, 44, 96)。左翼图标，右翼文字。
- **横幅提示**（长文字）：岛向下长出一条：宽 = max(刘海宽 + 180, 340)，高 = 刘海高 + 38，底部圆角 22；下方一行居中「图标 + 文字」。
- **启动问候**：每次启动 0.6 秒后，紧凑岛弹出 1.6 秒：左翼当前机身小图标（陶土橙），右翼绿色小圆点 +「营业中」；然后弹簧收回到刘海大小。首次启动额外用横幅显示「把鼠标移到刘海上试试」。
- 所有状态之间用同一个弹簧（response 0.38，damping 0.82），形状始终是带「耳朵」的 `NotchShape`。

## 3. 刘海里的胶卷柜（胶卷选择要有图）

- 悬停面板（`hover`）：左侧机身用 `CameraInstant` / `CameraBooth` 小图（44pt）+ 名字；右侧当前胶卷用 **3D 胶卷罐渲染图**（40pt）+ 名字 + 打字机字计数「7/10」。点胶卷罐 → 展开胶卷柜。
- 新模式 `films`（胶卷柜）：岛尺寸 = (max(刘海宽 + 420, 680), 刘海高 + 172)。
  - 第一行（刘海高）：左「胶卷柜」，右「挑一卷装上」（暗一点），最左一个「‹」回到悬停面板。
  - 下面横向滚动一排胶卷罐卡片（宽 86）：罐子图 64×64，名字 12pt 半粗，「ISO 400 · 24 张」10pt 打字机字（55% 白）；当前装着的卡片背后一团暖色聚光（径向渐变）+ 陶土橙小胶囊「已装」。
  - 悬停卡片：上浮 4pt，底部一行显示这卷的 `summary`。
  - 点击：装上（`model.stockID`），`gearClick` 音效 + 触感，收回并提示「装上了 奶油 600」。
  - 自定义 `.cube` 胶卷：用通用罐子 `FilmCanister-custom` + 名字。
- 菜单栏菜单里的胶卷选择也带 16pt 胶卷罐小图。
- 胶卷罐图片名：`FilmCanister-<stock.id>`；找不到图片时退回 `FilmSwatch` 色条，不能崩溃。统一用 `FilmCanisterImage(stock:size:)` 视图（`macOS/Nocchi/App/FilmArt.swift`）。

## 4. 自拍取景器

- 修复：底部快门一排被裁掉。岛的高度必须由内容推出来，不能写死：刘海高 + 10（间距）+ 236（镜头）+ 16 + 58（按钮行）+ 20（底边距）= 刘海高 + 340；宽 max(刘海宽 + 190, 440)。面板 `panelSize` 要能容下所有模式（必要时加高）。
- 按钮行：关闭（34）· 快门（58，象牙白外圈 + 陶土橙内钮）· 倒数开关（34，和关闭按钮同款圆形），三者等距居中。
- 镜头外圈保持「象牙白机身 + 细铬圈 + 黑色多圈纹」。

## 5. 程序坞与菜单

- 默认在程序坞显示图标（去掉 `LSUIElement`，`NSApp.setActivationPolicy(.regular)`）；设置 → 通用里可以关掉（关掉后用 `.accessory`）。
- 点程序坞图标（`applicationShouldHandleReopen`）且没有可见窗口 → 打开相册。
- 程序坞右键菜单（`applicationDockMenu`）：屏幕快门 / 自拍 / 大头贴机 / 冲印照片… / 打开相册。
- 主菜单（`.commands`）：文件 →「冲印照片…」⌘O、「从『照片』图库冲印…」⇧⌘O；相机 → 屏幕快门 ⌃⌥⌘S、自拍 ⌃⌥⌘F、大头贴机 ⌃⌥⌘B；窗口 →「相册」⌘0；App 菜单「设置…」⌘, 打开 Nocchi 自己的设置窗口。最后一个窗口关闭时**不要**退出。

## 6. 摄像头选择（含虚拟摄像头）

- 设置新增「摄像头」页：列出 `AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified)` 的全部设备。每行：名字 + 类型徽标（内建 / 外接或虚拟 / iPhone 连续互通）+ 选中勾。顶部一个圆角实时预览（所选设备），下方「自拍画面镜像」开关（默认开）。
- 虚拟摄像头（OBS、Camo 等以 Camera Extension 形式出现的 `.external` 设备）要能选中并正常拍照。
- 监听 `AVCaptureDevice.wasConnectedNotification` / `wasDisconnectedNotification` 刷新列表；所选设备不见了就回落到默认摄像头并提示。
- `CameraService` 按所选设备的 `uniqueID` 配置会话；切换设备时（会话已配置）重新配置输入。自拍、大头贴机都用它。

## 7. 从照片冲印

- 入口：刘海悬停面板「冲印照片」按钮、菜单栏菜单、主菜单 ⌘O / ⇧⌘O、程序坞菜单、相册右上角「＋」。
- 「从文件…」用 `NSOpenPanel`（多选、只允许图片）；「从『照片』图库…」用 SwiftUI `PhotosPicker`（一个小窗口，最多 20 张）。
- 每张图都用当前胶卷、当前默认模板冲印成一张即显相片，从刘海逐张出片（间隔约 2.6 秒，不重叠）。来源记为 `.library`。

## 7½. 相纸规格（可以选）

仓库所有者要求「相纸的比例也可以选」，并且要有「富士即显那种相纸」和「大头贴那种」。实现为 `FilmFormat` 的 6 种规格（`PaperLayout` 里有精确几何，名字全部原创，不出现品牌）：

| `FilmFormat` | 名称 | 相纸 / 画面（mm） | 用途 |
| --- | --- | --- | --- |
| `instantSquare` | 方形即显 | 88×107 / 79×79 | 现有默认 |
| `instantMini` | 迷你即显 | 54×86 / 46×62（竖） | 卡片大小的即显相纸（参考市面上最常见的迷你即显比例） |
| `instantWide` | 宽幅即显 | 108×86 / 99×62（横） | 宽幅即显 |
| `landscape` | 冲印小照 | 102×76 / 94×63（3:2） | 老相馆的白边冲印小照，配彩色负片最好看 |
| `boothStrip` | 四格条 | 52×160 / 4×（44×33） | 大头贴竖条 |
| `boothGrid` | 四宫格 | 102×152 / 4×（45×60） | 2×2 四宫格大头贴 |

- 即显相机（自拍、屏幕快门、冲印照片）用 `AppModel.instantFormat`（默认 `instantSquare`，只能是 `FilmFormat.instantChoices`）；大头贴机在「选相框」那一步选四格条或四宫格（模板分属不同规格）。
- 刘海悬停面板的胶卷罐旁边有一个「相纸」小卡：画出当前相纸的小剪影（按真实比例的白色圆角矩形 + 灰色画面区），点一下在 4 种即显相纸之间循环，悬停显示 `note`。设置里也能选。
- 胶卷有推荐相纸（`FilmStock.recommendedFormat`）：胶卷柜里在胶卷卡片上用一行小字提示「推荐 迷你即显」，装上胶卷时**不**自动改相纸。
- 冲印裁切用所选相纸的 `windowAspect`；记录里写 `record.format`。

## 8. 相纸模板（预设模板）

模板只改外观，不改几何（`PaperLayout` 不变），任何时候都能换模板重新合成。所有图样用 Core Graphics 程序化绘制（原创），屏幕与导出同一套渲染（见 §15 `PhotoComposer` 分层接口）。

拍立得（`instantSquare`）至少 8 款，大头贴条（`boothStrip`）至少 8 款，横幅（`landscape`）至少 3 款。建议清单（ID 一旦发布不能改）：

| ID | 名称 | 画幅 | 设计 |
| --- | --- | --- | --- |
| `classic` | 经典 | 全部 | 胶卷自带相纸（现有外观） |
| `noir` | 炭黑 | 全部 | 炭黑相纸、象牙白字，窗口发丝边改成暖灰 |
| `kraft` | 牛皮纸 | 全部 | 牛皮纸色 + 纤维纹 + 深棕墨 |
| `deckle` | 毛边相纸 | 拍立得、横幅 | 50 年代照片的波浪毛边（扇贝形外轮廓）+ 奶油色 + 细压纹边框 |
| `datebook` | 日期机 | 拍立得、横幅 | 照片右下角橙色七段数码日期 「'26 11 23」（发光、轻微晕开）|
| `filmframe` | 胶片框 | 全部 | 黑色片基 + 上下齿孔 + 橙色片边字「NOCCHI ▸ 12A」 |
| `postage` | 邮票 | 拍立得 | 齿孔邮票外缘 + 面值「8分」+ 「NOCCHI POST」+ 邮戳半圈 |
| `seventies` | 70 年代条纹 | 全部 | 底边三道横条（芥末黄 / 陶土橙 / 胡桃棕），复古字体 |
| `album` | 老相册 | 拍立得、横幅 | 黑卡纸相册页 + 四个黑色照片角 + 白色铅字说明 |
| `cabinet` | 照相馆卡纸 | 拍立得 | 维多利亚照相馆卡纸：深棕卡、金色细框、底部烫金「NOCCHI STUDIO」 |
| `booth-classic` | 老照相亭 | 大头贴条 | 奶油白纸 + 底部编号「No. 0427」+ 日期 |
| `booth-noir` | 黑白照相亭 | 大头贴条 | 黑纸 + 白发丝边 |
| `booth-heart` | 情人节 | 大头贴条 | 奶油粉纸 + 心形窗口（`windowPath` 为心形）+ 复古蕾丝花边（几何花纹，不是手绘） |
| `booth-stars` | 金星 | 大头贴条 | 墨蓝纸 + 烫金小星（规则的五角 / 四角星，带金属渐变） |
| `booth-birthday` | 生日快乐 | 大头贴条 | 每格上方一条复古横幅字「HAPPY BIRTHDAY · 生日快乐」+ 三角彩旗（平涂色块） |
| `booth-newyear` | 新年快乐 | 大头贴条 | 朱红纸 + 金色字「新年快乐」+ 回纹边 |

模板元数据：`PrintTemplate`（`id` / `name` / `note` / `formats` / `style` / `paper`），目录 `TemplateCatalog`。

## 9. 贴纸（复古印刷品，不是线稿）

全部程序化绘制（Core Graphics），每枚贴纸都像真实印刷品：平涂复古色、轻微套色错位、网点或纸纹，乙烯贴纸带 3–5% 宽的白色模切边和一点点投影。分类（`StickerCategory`）与建议清单：

- **徽章 `badge`**：太阳光芒（芥末黄放射线 + 圆心）、复古柠檬、樱桃、雏菊、星芒「NEW!」、彩虹弧（三色平涂，不用宝丽来配色顺序）、相机徽章、胶卷罐、爱心珐琅章（金属描边）、音符、月亮、闪电、咖啡杯、小狗头像、小猫头像（几何简化的印刷图形，不是线稿）。
- **印章 `stamp`**：圆形邮戳「NOCCHI · 2026.11.23」（日期可编辑）、「OK!」、「LOVE」、「已显影」、「珍藏」、「好天气」、星形「★ BEST ★」、方形「冲印店」。墨色斑驳、压印不均、可换色。
- **旧物 `ephemera`**：电影票根「ADMIT ONE」、邮票（齿孔边）、价签（打孔 + 棉线）、行李牌、35mm 胶片片段、照片角（四个一套里的一个）、收据小条、火柴盒标。
- **胶带 `tape`**：牛皮纸胶带、米色和纸胶带、条纹（陶土 / 奶油）、格纹（芥末）、网点（墨蓝）——半透明、两端撕口。
- **标签 `label`**：凸字标签带（黑 / 红 / 墨蓝带 + 白色凸字，可以自己打字）、打字机纸条（可以自己打字）。
- **表情 `emoji`**：一组系统表情，做成带白色模切边的乙烯贴纸。

标签 → 自动贴纸（`StickerCatalog.kindID(forTag:)`）：阳光→太阳徽章、雨天→雨伞 / 云徽章、闪光→闪电、咖啡→咖啡杯、小狗→小狗、猫咪→小猫、旅行→行李牌、朋友→爱心珐琅章、生日→蛋糕 / 彩旗、夜晚→月亮。开启「标签贴纸」时，在白边书写区右下角放一枚小号的。

## 10. 装饰台（拍完之后：涂鸦、贴纸、模板、题字）

窗口 1180×800（最小 980×700），透明标题栏、全尺寸内容。

- **背景**：深色胡桃木桌面（`WoodTexture` 压暗）+ 一团暖色台灯光（径向渐变，中心在相纸上）。
- **左：工具托盘**（宽 64，皮革色 `leather`，细缝线描边）：选择 / 钢笔 / 马克笔 / 油性蜡笔 / 漆笔 / 橡皮（点哪条笔画删哪条）｜颜料（8 个珐琅色点：墨黑 #2B2A28、陶土 #C4593B、钴蓝 #2F4C8A、石油绿 #2F5F5C、芥末 #D9A441、印刷红 #B23A2A、象牙白 #F4F1EA、金 #B8955A）｜粗细｜撤销 / 重做。
- **中：相纸**：按窗口大小适配（拍立得最大约 560pt 宽），带真实阴影；层次 = 底图（`renderBase`）→ 显影好的底片（按 `windowPath` 裁切）→ 叠加层（不含贴纸和笔画）→ 笔画 → 贴纸（可拖动；选中时虚线框 + 角上的缩放 / 旋转手柄 + 删除按钮）→ 正在画的笔画。笔画只在选中画笔时可画，可以画在照片和白边上。
- **右：检查器**（宽 330，纸色 `paper`，顶部四个带图标的标签）：
  1. **贴纸**：分类胶囊 + 三列网格（`StickerArt.image` 缩略图放在小纸卡上）；点一下贴到相纸中央；能写字的贴纸选中后显示文字框；能换色的显示色点。
  2. **模板**：两列网格，缩略图用这张照片自己的底片实时合成（后台线程、缓存），选中的描陶土橙边。
  3. **文字**：题字 / 心情（两行）；字体（手写 / 打字机 / 铅字）；日期与时间（可改 + 「印日期」开关）；地点；标签（建议标签胶囊 + 自定义输入）；显示设置（印标签 / 印地点 / 标签贴纸）。
  4. **分享**：海报背景（亚麻、胡桃木、牛皮纸、丝绒、软木、70 年代条纹、晴空、暗房红光）+ 摆法（居中 / 微斜 / 两张叠放）→「导出图片…」（JPG / PNG，1080×1350）、「拷贝」、「分享…」（系统分享菜单）。
- **底部**：「取消」「完成」。快捷键：⌘Z / ⇧⌘Z、⌫ 删贴纸、Esc 取消选中、⌘S 完成。
- **保存**：所有装饰写进 `PhotoRecord`（非破坏性），用 `PhotoComposer.render` 重新合成成片覆盖原文件，`editedAt = Date()`，刷新桌面上的这张照片、相册、卡片盒。
- **入口**：桌面相片右键「装饰…」与双击；相册各视图右键「装饰…」与双击；设置里「拍完后自动打开装饰台」（默认关）开启时，相片显影完成后自动打开。

## 11. 相册窗口

窗口：透明标题栏 + 全尺寸内容 + 隐藏标题文字；默认 1220×820，最小 980×700；背景 `paper`。

### 11.1 顶栏（高 56，左侧给红绿灯让出 84pt；红绿灯挪到顶栏的垂直中线上，见 `TrafficLights`）

- 左：字标「NOCCHI」（Didot，字距 3）+「相册」（宋体）。
- 中：**模式切换**：象牙白内凹托盘，4 段，每段 = Blender 渲染的小图标（30×30）+ 文字（软木板 / 卡片盒 / 胶卷 / 日历）。选中段是一块凸起的白色小卡（阴影 + 顶部高光），用 `matchedGeometryEffect` 滑动；⌘1–⌘4 切换。图标：`ModeIconCork` / `ModeIconCardBox` / `ModeIconFilm` / `ModeIconCalendar`，缺图时退回 SF Symbol。
- 右：**搜索框**（宽 260，象牙白胶囊、内阴影、放大镜，占位「搜索题字、标签、地点、胶卷…」，⌘F 聚焦，Esc 清空）+「＋」按钮（菜单：从文件… / 从「照片」图库…）。
- 搜索对四种模式都生效（`PhotoSearch`）。没有结果时显示一张打字机纸条：「没有找到『xxx』」。

### 11.2 软木板（复古、有设计感）

- 一块装在**胡桃木框**里的软木板（框宽 22，外暗线 + 内高光 + 软木边缘内阴影），软木用 `CorkTexture` 平铺 + 左上暖光渐变 + 右下压暗。
- 每个月一组。月份标题是**凸字标签带**（黑 / 酒红带，白色凸字「2026 · 十一月」，带细竖纹与高光，倾斜 −2°），旁边一张打字机小纸条「3 张」。
- 照片拼贴：自定义 `Layout` 的松散排布——宽度按画幅（拍立得 170、四格条 96、横幅 220），按 seed 随机倾斜 ±5°、上下错落 ±10、间距 34±8。固定方式按 seed 选：黄铜图钉（`PinBrass`）、复古彩色地图针（`PinTerracotta` / `PinMustard` / `PinTeal`）、两条牛皮纸胶带贴上角、木夹（`Clothespin`）。
- 每月（≥3 张时）点缀一件旧物：电影票根、邮票、胶片片段（程序化绘制，印刷质感）。
- 悬停：照片上浮（scale 1.04、阴影加深），图钉不动。双击 → 装饰台；右键：装饰… / 放回桌面 / 在 Finder 中显示 / 用「预览」打开 / 移到废纸篓。
- 空状态：一张用图钉钉住的打字机卡片：「软木板还空着 · 把鼠标移到刘海，按『屏幕快门』或『自拍』拍第一张。」

### 11.3 卡片盒（立体复刻参考图）

参考：浅色山毛榉木索引卡盒（指接榫、前板椭圆拉手孔里斜插一支黄色圆珠笔），盒里塞满彩色索引卡和 A–Z 分隔卡（白色标签、黑色字母、错落排布），最前面一张有横线的白卡斜着翘起、右上角折了一角；右边是带字母标签的照片卡片散开叠放。

- **2.5D 分层**（Blender Cycles 渲染，背景透明）：`CardBoxBase`（整盒 + 卡片 + 分隔卡 + 笔 + 地面阴影）与 `CardBoxFront`（只有前板和面向镜头的侧板，用来遮住从盒里升起的卡片），两张图同一机位、同一画布（1600×1200）。分隔卡标签的位置（归一化坐标）、盒口区域写在 `design/blender/cardbox/hotspots.json`，代码里固化成常量。
- 背景：暖米色无缝背景（与渲染地面一致，约 #E8E4DC，中心略亮），左侧放盒子（约占宽 44%），右侧是照片「摊开区」。
- **抽卡**（v2.0）：照片从被点字母的那一格里沿分隔卡斜面抽出（格口线以下被前面的卡片挡住），离开盒口时转正，再落到右边；放回时回到自己那一格。右边是**松散的一叠**（最上面一张完整可见，其余错落露出），卡片可拖动摆放，靠近另一张会叠成一小摞，位置记住，「重新叠好」复原。卡片上的字母标签是上窄下宽、上角圆的模切纸标签（Didot 字母、发丝描边）。
- 标签热区：悬停时在标签上方出现小气泡「W · 3 张」（没有照片的是「W · 空」）；有照片的字母标签旁有一颗小小的陶土橙圆点。点击：这一组照片从盒口一张张升起（先在 `CardBoxFront` 后面上升，再飞到右侧），错开 0.08 秒，配 `cardSlide` 音效。
- **照片卡片**（像参考图右侧）：纸色 #F4F0E6 圆角 3，照片在上，下方标题（宋体 14，墨色）与副标题（打字机 11，`inkSoft`：「2026/11/23 · 上海 · 奶油 600」），左上方伸出一个字母小标签（打字机 13）。最多同时摊开 9 张，按 seed 扇形错落（倾斜 ±6°），最上面的完整可见。单击置顶，双击打开装饰台，横向滚动 / 拖动翻页，「全部放回」让卡片飞回盒子。
- 默认打开时摊开最近的照片（最多 9 张）；搜索时摊开搜索结果。
- 删除底部的 A–Z 检索条。

### 11.4 胶卷（光台上的胶片条，参考照相亭的「精选照片条」橱窗）

- 深色胡桃木桌面上一块**光台**：圆角 14，铝边（银色线性渐变 4pt），发光面（中心 `lightbox` → 边缘 `lightboxEdge`，每 24pt 一条 4% 的网格线），向桌面溢出一圈暖光。
- 照片排成**竖直的胶片条**：普通照片按 `FilmStrips` 每 4 张一条，35mm 正片样式——片基 #1A1512、两侧圆角齿孔（透出光台的光）、橙色片边字（打字机 7pt「NOCCHI · CREAM 600」与帧号「12 ▸ 12A」）。大头贴直接显示整条成片。
- 横向滚动，条与条间距 34，按 seed 倾斜 ±3°、上下错落；月份之间夹一张打字机小纸条「2026 · 十一月」。
- 「洗一洗」按钮（底部居中，复古按键）：重新打乱顺序与角度（弹簧动画）。
- 「正片 / 负片」切换：负片 = 反色 + 橙色片基色罩，放大镜里永远是正片。
- **放大镜**：悬停在某一格上时出现（`Loupe` 图，直径 ~160pt），里面是 2.2 倍放大的正片，跟随鼠标。
- 双击某一格 → 装饰台；右键同软木板。

### 11.5 日历（复古挂历）

- 一页复古挂历：纸色 #F3EBDD + 纸纹，顶部一条装订边和两个黄铜铆眼；印刷红 + 墨黑两色。
- 头部：大号月份数字「11」（Didot 96）+「NOVEMBER · 十一月」（宋体 16，字距）+ 年份「2026」（打字机）；黄铜小按钮 ‹ ›、「今天」。
- 星期行「一 二 三 四 五 六 日」，周六日印刷红。
- 日期格：发丝线网格；日期数字左上（Didot 15，周末红）；今天用一个红色圆形印章圈出来；有照片的格子里放一张带白边、四个黑色照片角的小照片（轻微倾斜），多于 1 张时角上一个红色小圆章「+2」。
- 点某天 → 弹出这一天的照片一排（140pt）+ 题字；双击照片 → 装饰台。
- 页脚统计（打字机）：「本月 12 张 · 用了 3 卷胶卷 · 最常写 #阳光」。

## 12. 大头贴机：先选相框

参考照相亭网站的流程（只借鉴流程，外观复古）：布帘拉上之后、「请看镜头」之前，多一步「选相框」（`Booth/BoothFrameChooser.swift`，已实现）：

- 象牙白搪瓷面板（四角黄铜螺丝）。中央是黄铜包边的橱窗：深色绒布底、顶上一盏暖灯、玻璃斜反光，样张用小铜夹挂着、微微倾斜，带接触阴影 + 柔和投影。样张用 `TemplatePreview.render`（暖灰占位格 + 柔和半身剪影，和成片同一套 `PhotoComposer`）合成，后台线程，按「模板 + 规格 + 胶卷 + 宽度 + 题字」缓存（`TemplatePreviewStore`）。
- 两侧黄铜箭头切换相框，样张从切换的方向滑进来；下方打字机字模板名 + 一句说明 + 页码圆点（可点）。顺序 `TemplateCatalog.boothTemplates(for:)`：先六款大头贴主题，再其余适用于这个规格的模板。
- 两个镀铬拨杆开关（底座螺母 + 斜拨杆，左右刻字）：「四格条 / 四宫格」（同一款相框两种版式都有，切换时留在这一款）与「黑白 / 彩色」。选卷规则 `FilmCatalog.boothStockID`：黑白用 `booth-silver-400`（装着黑白卷时用它），彩色用 `booth-flash-400`（装着自己挑的彩色卷时用它）。面板上一行打字机字「胶卷 · 闪光 400」。
- 一颗会呼吸发光的陶土橙「开始」（镀铬外圈）：按下有投币音效，**这时才打开摄像头**，然后「请看镜头」→ 倒数。取景框按版式的格子比例（四格条 4:3、四宫格 3:4）。
- 键盘：← → 换相框，↑ ↓ 换版式，Return 开始，Esc 离开（⌘Q 退出）。
- 看门狗只在按下「开始」之后计时，选相框时不会把会话杀掉；任何时候都能离开（D17）。
- 这次的相框、版式、黑白写回 `AppModel`（`defaultBoothTemplateID`、`boothFormat`、`boothMonochrome`），下次从这里开始；设置 →「相纸」里也能改。矮屏幕上布帘里的内容整体缩小。

## 13. 分享海报

见 §10「分享」。背景全部程序化或用现有纹理（`PaperTexture` `VelvetTexture` `CorkTexture` `WoodTexture` `CurtainTexture`），相片带真实阴影，右下角可选一行小字「Nocchi · 2026/11/23」。

## 14. 美术素材清单（Blender 渲染，放在 `Shared/Art.xcassets`）

统一：Blender 命令行（`/Applications/Blender.app/Contents/MacOS/Blender -b -P script.py`），Cycles + 降噪，AgX 色彩，左上方柔光主灯 + 暖色补光，透明背景（地面用阴影捕捉器），PNG RGBA。脚本放在 `design/blender/`，可以重复生成。

| 图片名 | 尺寸（px） | 内容 |
| --- | --- | --- |
| `CardBoxBase` | 1600×1200 | 卡片盒整体（复刻参考图），含地面柔和阴影 |
| `CardBoxFront` | 1600×1200 | 同机位，只有前板 + 面向镜头的侧板 |
| `FilmCanister-<stock.id>`（现有 15 + 新增 11 = 26 个） | 384×384 | 原创包装：彩色负片 / 黑白 / 电影卷是 35mm 胶卷罐（象牙白或该卷配色的标签 + 色带 + ISO 大字 + 英文名 + NOCCHI 小字标）；即显与大头贴相纸是扁平的相纸盒（按相纸比例）；黑白卷标签用黑白配色 |
| `FilmCanister-custom` | 384×384 | 通用罐子（素色标签「CUSTOM LUT」） |
| `ModeIconCork` `ModeIconCardBox` `ModeIconFilm` `ModeIconCalendar` | 160×160 | 模式切换图标：小软木板 / 小卡片盒 / 胶卷罐 + 片段 / 复古翻页台历，同一光照与角度 |
| `PinBrass` `PinTerracotta` `PinMustard` `PinTeal` | 128×128 | 黄铜图钉、复古地图针（俯视略斜，针尖朝下） |
| `Clothespin` | 96×192 | 木夹（竖直） |
| `Loupe` | 512×512 | 放大镜外圈（黑色 + 铬边，镜片区域透明） |

热区数据：`design/blender/cardbox/hotspots.json`。

## 14½. 滤镜（胶卷色调）要好看

仓库所有者：「滤镜要好看，可以选富士那种相纸和色调……也要支持科达胶卷那种影调」。品牌名不能出现（CLAUDE.md §4），但**影调要像**。

### 引擎升级（`Film/ToneRecipe.swift`，全部新字段可缺省，旧 JSON 照常读）

- `curves`：每通道曲线（`master` / `r` / `g` / `b`，各是若干 `[x, y]` 控制点，单调三次插值），用来做真正的胶片 S 曲线、趾部 / 肩部、通道交叉（负片扫描那种阴影偏青、高光偏暖）。
- `hsl`：八个色相带（红、橙、黄、绿、青、蓝、紫、品红）各自的色相偏移（度）、饱和度、明度——像 Lightroom 的色彩混合器（例如绿色往青 / 黄偏、肤色橙带提亮降饱和）。权重用平滑的色相窗，不能出现色带断层。
- `fade`（阴影雾化）与 `highlightRolloff`（高光柔和过渡），`skinProtect`（橙色肤色带不跟随整体饱和）。
- 处理顺序：线性空间（曝光、白平衡、串色）→ gamma 空间（曲线 → HSL → 饱和度 / 肤色保护 → 分离色调 → 褪色）。
- 效果（`FilmProcessor`）同步打磨：颗粒随亮度分布（中间调最明显）、按 ISO 调大小；光晕只在高光边缘、偏橙红；暗角柔和。

### 胶卷清单（保留现有 15 卷并重调；新增 11 卷，ID 与名字固定如下）

| ID | 名称 / English | ISO · 张 | 影调参考（只在文档里写，界面不出现品牌） | 色卡 swatch | tags |
| --- | --- | --- | --- | --- | --- |
| `portrait-400` | 人像 400 / Portrait 400 | 400 · 36 | 柯达人像负片：暖中性、低反差、奶油肤色、柔和绿色、细颗粒 | #F3D7BE #C9A48A #5E6B5A | color, warm, portrait, print |
| `gold-200` | 金黄 200 / Golden 200 | 200 · 36 | 柯达金：金黄偏暖、黄红饱和、黑位微抬、怀旧 | #FFD36E #E5893F #6B4A2E | color, warm, print |
| `vivid-100` | 艳色 100 / Vivid 100 | 100 · 36 | 柯达风光负片：高饱和、深蓝天空、红色浓郁、极细颗粒 | #E8463A #2D6FB5 #F2C14E | color, vivid, print |
| `tungsten-800` | 钨丝 800 / Tungsten 800 | 800 · 36 | 电影卷改的夜景卷：钨丝平衡偏冷、青色阴影、灯光周围红色光晕 | #2B5B7A #E0553A #10202C | cine, night |
| `mint-400` | 薄荷 400 / Mint 400 | 400 · 36 | 富士 400H：通透淡彩、薄荷绿、青蓝天空、过曝感 | #DDEFE4 #9CCBC0 #4E7F86 | color, pastel, airy |
| `evergreen-400` | 常青 400 / Evergreen 400 | 400 · 36 | 富士 Superia：偏冷、浓郁绿色、清脆反差 | #BFD9A0 #4E8C6A #2A3F4F | color, green, print |
| `everyday-200` | 日常 200 / Everyday 200 | 200 · 36 | 富士 C200：中性略偏青绿、平和、日常感 | #F1E7D2 #9DB7A8 #3F5866 | color, print |
| `crisp-800` | 晶亮 800 / Crisp 800 | 800 · 10 | 富士即显：明亮、通透白、饱和、反差利落、阴影微青 | #FFFFFF #7FC4E0 #E26D8C | instant, mini, bright |
| `grit-400` | 粗粒 400 / Grit 400 | 400 · 36 | 柯达 Tri-X：高反差、粗颗粒、深黑 | #F2F2F2 #7A7A7A #0E0E0E | bw, contrast |
| `fine-100` | 细腻 100 / Fine 100 | 100 · 36 | 富士 Acros：灰阶细腻、极细颗粒、中间调丰富 | #F5F3EE #A3A09A #232220 | bw, soft |
| `booth-silver-400` | 照相亭黑白 400 / Booth Silver 400 | 400 · 16 | 老式照相亭黑白：闪光直打、高反差、略暖的银盐纸 | #F4F1EA #9A948A #1C1A18 | booth, bw |

- `cream-600` 保持第一（默认胶卷），影调对标宝丽来 600 型即显（奶油高光、微绿阴影）。
- 即显类相纸颜色：`crisp-800` 用冷白相纸 #FAFAF7；`cream-600` 用奶油白。
- 分组（`FilmStock.family`，由 tags 推出）：即显相纸 / 彩色负片 / 夜景与电影 / 黑白 / 大头贴 / 自定义 LUT。胶卷柜按组排列，组之间有小标题。

## 15. 接口约定（跨模块）

> 名字和签名是各模块之间的契约，实现方必须一模一样地提供，调用方直接用。

### NocchiKit（`Packages/NocchiKit/Sources/NocchiKit`）

- 已写好：`FilmFormat` 新规格（`instantMini` `instantWide` `boothGrid`）与 `displayName` `note` `isInstant` `isBooth` `frameCount` `instantChoices` `boothChoices`；`FilmFamily`、`FilmStock.family`、`FilmStock.recommendedFormat`、`FilmCatalog.grouped(_:)`（`Film/FilmFamily.swift`）；`PhotoRecord` 新字段（`takenAt` `templateID` `captionFont` `location` `tags` `stickers` `showsTags` `showsLocation` `showsTagStickers` `editedAt`，以及 `displayDate` `effectiveTemplateID` `tagLine` `locationLine` `normalizedTag(_:)`）；`InkStroke.tool`；`InkTool`、`CaptionFont`、`StickerCategory`、`StickerKind`、`StickerPlacement`（`Decorate/Decoration.swift`）；`PrintTemplate`、`TemplateCatalog`（`Decorate/PrintTemplate.swift`，模板清单待补）。
- 贴纸（`Decorate/StickerCatalog.swift`、`Decorate/StickerArt.swift`）：

```swift
public enum StickerCatalog {
    public static let all: [StickerKind]
    public static func kinds(in category: StickerCategory) -> [StickerKind]
    public static func kind(id: String) -> StickerKind?
    /// 标签（不带 #）→ 自动贴纸的 kind ID；没有对应时 nil。
    public static func kindID(forTag tag: String) -> String?
    /// 装饰台里的建议标签。
    public static let suggestedTags: [String]
}

public enum StickerArt {
    /// 在 rect 里画出贴纸。ctx 已是左上角原点、y 向下。
    public static func draw(_ kind: StickerKind, in ctx: CGContext, rect: CGRect, tint: RGB?, text: String?, seed: UInt64)
    /// 按相纸上的摆放画一枚贴纸（中心、大小、旋转、翻转）；paperWidth 是相纸的像素宽度。
    public static func draw(_ placement: StickerPlacement, in ctx: CGContext, paperWidth: CGFloat)
    /// 摆放的外框（未旋转，像素，左上原点）。
    public static func frame(of placement: StickerPlacement, paperWidth: CGFloat) -> CGRect
    /// 单独渲染成透明图（缩略图、装饰台的贴纸层）。
    public static func image(_ kind: StickerKind, pixelWidth: Int, tint: RGB?, text: String?, seed: UInt64) -> CGImage?
}

public extension StickerPlacement {
    /// 由 UUID 字节推出的稳定随机种子（不要用 hashValue）。
    var stableSeed: UInt64 { get }
}
```

- 合成（`Darkroom/PhotoComposer.swift`）：

```swift
public struct PrintSpec {
    // 原有字段不变，新增：
    public var template: PrintTemplate          // 默认 TemplateCatalog.classic
    public var captionFont: CaptionFont         // 默认 .handwriting
    public var tagLine: String?
    public var locationLine: String?
    public var tagStickerIDs: [String]          // 自动标签贴纸（kind ID）
    public var stickers: [StickerPlacement]
    public var seed: UInt64
    // 原来的 init 保持可用（新参数都有默认值）
    /// 从照片记录生成：套用模板相纸、题字字体、标签 / 地点、自动标签贴纸、贴纸、笔画。
    public init(record: PhotoRecord, stockPaper: PaperStyle, images: [CGImage], widthPixels: Int)
}

public enum PhotoComposer {
    /// 完整成片 = renderBase + 照片 + renderOverlay。
    public static func render(_ spec: PrintSpec) -> CGImage?
    /// 照片下面的一切：相纸、模板底纹（相纸外透明）。
    public static func renderBase(_ spec: PrintSpec) -> CGImage?
    /// 照片上面的一切：窗口内凹阴影与发丝边、模板前景图样、题字 / 日期 / 地点 / 标签、标签贴纸、贴纸、笔画（其余透明）。
    public static func renderOverlay(_ spec: PrintSpec, includeStickers: Bool = true, includeStrokes: Bool = true) -> CGImage?
    /// 第 index 个图像窗口的形状（像素，左上原点，相纸宽 width）。矩形模板就是窗口矩形，心形模板是心形。
    public static func windowPath(layout: PaperLayout, template: PrintTemplate, index: Int, width: CGFloat) -> CGPath
    /// 按 InkTool 画笔画（成片与装饰台共用）。
    public static func drawStrokes(_ strokes: [InkStroke], in ctx: CGContext, paperWidth: CGFloat, defaultInk: RGB)
}
```

- 模板预览与大头贴选择（`Decorate/TemplatePreview.swift`，已实现）：

```swift
public enum TemplatePreview {
    /// 一格占位画面（按窗口比例）：暖灰（黑白卷中性灰）渐变、左上暖光、柔和半身剪影、颗粒、暗角。
    public static func placeholder(aspect: CGFloat, pixelWidth: Int, monochrome: Bool, index: Int) -> CGImage?
    /// 用占位格合成一张模板预览（后台线程可调用）；模板不适用于这个规格时用默认模板。
    public static func render(template: PrintTemplate, format: FilmFormat, stock: FilmStock, caption: String? = nil,
                              captionFont: CaptionFont = .handwriting, showsDate: Bool = true, date: Date = Date(), widthPixels: Int) -> CGImage?
}
public extension TemplateCatalog {
    static let defaultBoothID: String                                   // "booth-classic"
    static func boothTemplates(for format: FilmFormat) -> [PrintTemplate] // 大头贴主题在前
}
public extension FilmCatalog {
    static let boothColorID: String   // "booth-flash-400"
    static let boothMonoID: String    // "booth-silver-400"
    static func boothStockID(monochrome: Bool, loaded: FilmStock) -> String
}
```

- 检索与分组（`Library/`）：

```swift
public enum PhotoSearch {
    /// 空格分隔的每个词都要命中：题字、标签（有没有 # 都行）、地点、胶卷名（中英文）、日期（2026、11月、2026/11/23）、首字母（单个字母）。不分大小写、忽略变音符号。
    public static func matches(_ record: PhotoRecord, query: String) -> Bool
    public static func filter(_ records: [PhotoRecord], query: String) -> [PhotoRecord]
}

public struct FilmStrip: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable { case roll, booth }
    public struct Frame: Hashable, Sendable { public let recordID: UUID; public let negativeIndex: Int }
    public let id: String
    public let kind: Kind
    public let stockID: String
    public let stockName: String
    public let frames: [Frame]
    public let startDate: Date
    public let monthKey: String           // "2026-11"
    public let firstFrameNumber: Int      // 这一条第一格在当月的帧号（从 1 开始）
}

public enum FilmStrips {
    /// 旧 → 新排成胶片条：大头贴一张一条；其余每 framesPerStrip 张一条，不跨月、不跨胶卷。
    public static func make(from records: [PhotoRecord], framesPerStrip: Int = 4) -> [FilmStrip]
}

public struct CalendarDay: Identifiable, Hashable, Sendable {
    public let id: String                 // "2026-11-23"
    public let date: Date
    public let day: Int
    public let isInMonth: Bool
    public let isToday: Bool
    public let weekdayIndex: Int          // 0 = 周一 … 6 = 周日
    public let records: [PhotoRecord]     // 新的在前，按 displayDate
}

public struct CalendarMonth: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let weeks: [[CalendarDay]]     // 每周 7 天，周一开头，前后补齐相邻月份
    public let photoCount: Int
    public let stockCount: Int
    public let topTag: String?
}

public enum PhotoCalendar {
    public static func month(year: Int, month: Int, records: [PhotoRecord], calendar: Calendar = .current, today: Date = Date()) -> CalendarMonth
}
```

### NocchiUI（`Packages/NocchiKit/Sources/NocchiUI`）

- `PrintSurface`：公开 `init` 不变；内部改为 `renderBase` + 显影中的照片（按 `windowPath` 裁切）+ `renderOverlay` + 光泽 + 正在写的笔画。模板、贴纸、标签、地点、字体在屏幕上与导出一致。
- `CardBoxView(model:)`、`CardBoxModel(loader:)` 保持可用；新增 `CardBoxModel.applySearch(_ query: String)`；照片记录的 `editedAt` 变了要重新读图。

### macOS App

| 接口 | 负责模块 |
| --- | --- |
| `FilmCanisterImage(stock: FilmStock, size: CGFloat)` 视图 | App（`App/FilmArt.swift`） |
| `AppModel.showsDockIcon`、`AppModel.cameraDeviceID: String?`、`AppModel.mirrorSelfie`、`AppModel.instantFormat: FilmFormat` | App |
| `AppModel.defaultInstantTemplateID`、`AppModel.defaultBoothTemplateID`、`AppModel.defaultCaptionFont`、`AppModel.autoOpenDecorate`、`AppModel.boothFormat`、`AppModel.boothMonochrome`、`AppModel.defaultTemplateID(for:)`、`AppModel.boothStock(monochrome:)` | 设置 / 大头贴（已实现） |
| `TemplatePreviewStore`、`TemplateSwatchRow` | App（`App/TemplatePreviews.swift`） |
| `Darkroom.shared.develop(_:source:body:mirror:booth:)`（`BoothSetup`：版式、相框、胶卷） | 暗房 / 大头贴 |
| `PhotoImport.chooseFiles()`、`PhotoImport.choosePhotosLibrary()` | 冲印照片（`Import/`） |
| `Darkroom.shared.developImported(_ images: [CGImage]) async` | 暗房 |
| `DecorateDesk.shared.open(_ record: PhotoRecord)` | 装饰台（`Editor/`） |
| `DesktopBoard.shared.refresh(_ record: PhotoRecord)` | 桌面相片（`Photo/`） |
| `LibraryStore.shared.upsert(_:)`（已有） | 相册 |

## 16. 工程约束

- **不在本机构建或测试**：不运行 `xcodebuild`、`swift build`、`swift test`、`swiftc`、`xcodegen`、模拟器。正确性靠仔细阅读与 CI。
- Swift 5 语言模式，macOS 14+ / iOS 17+。NocchiKit / NocchiUI 里给 App 用的东西都要 `public`。
- 界面代码默认 `@MainActor`；后台渲染用 `Task.detached` 并只传 `Sendable` 值（`CGImage`、值类型）。
- SwiftUI 大视图拆成小视图，避免「表达式太复杂无法类型检查」。
- 所有美术资源缺失时都要有退路（SF Symbol / 程序化绘制），不能崩溃。
- 新照片库字段必须兼容旧数据（解码缺省值）。

import AppKit
import NocchiKit
import NocchiUI
import SwiftUI

// 截图工作室的合成场景（`ImageRenderer` 以 2 倍像素渲染）。都用 App 自己的视图：
// 相片是 NocchiUI 的 `PrintSurface`，刘海是 `NotchShape`，大头贴是真的 `BoothInterior`。

/// Nocchi 的桌面壁纸（只在截图里用）：石油绿、胡桃、芥末和陶土色的柔光。
struct StudioWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1F3036), Color(hex: 0x35353A), Color(hex: 0x553B30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color(hex: 0xE8896B, opacity: 0.5), .clear], center: UnitPoint(x: 0.86, y: 0.96), startRadius: 8, endRadius: 760)
            RadialGradient(colors: [Color(hex: 0xD9A441, opacity: 0.26), .clear], center: UnitPoint(x: 0.08, y: 0.04), startRadius: 8, endRadius: 620)
            RadialGradient(colors: [Color(hex: 0x2F5F5C, opacity: 0.75), .clear], center: UnitPoint(x: 0.14, y: 0.92), startRadius: 8, endRadius: 680)
        }
    }
}

/// 屏幕顶上的菜单栏（只画右边的几个图标和时间；刘海在正中间）。
struct StudioMenuBar: View {
    var width: CGFloat
    /// 刘海特写里不画右边的图标和时间（真的菜单栏上它们离刘海很远）。
    var showsItems = true

    private var clock: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter.string(from: Date()) + "  09:41"
    }

    var body: some View {
        HStack(spacing: 15) {
            Spacer()
            if showsItems {
                Image(systemName: "camera.aperture")
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                Text(clock)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 18)
        .frame(width: width, height: 30)
        .background(Color.black.opacity(0.22))
    }
}

/// 一张相片：`PrintSurface` + 倾斜 + 和桌面上一样的三层阴影。
struct StudioPrintCard: View {
    let item: StudioPrint
    let width: CGFloat
    var tilt: Double = 0

    var body: some View {
        let size = item.record.layout.size(forWidth: width)
        PrintSurface(
            record: item.record,
            images: item.images,
            visuals: item.images.map { _ in DevelopmentVisual.developed },
            paper: item.paper,
            width: width
        )
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(tilt))
        .shadow(color: .black.opacity(0.3), radius: 0.8, x: 0, y: 0.6)
        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 3)
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 10)
    }
}

/// 正从出片口吐出来的一张：只露出下面 `progress` 那一截。
struct StudioEjectingPrint: View {
    let item: StudioPrint
    let width: CGFloat
    let progress: CGFloat

    var body: some View {
        let size = item.record.layout.size(forWidth: width)
        StudioPrintCard(item: item, width: width)
            .offset(y: -size.height * (1 - progress))
            .frame(width: size.width + 60, height: size.height * progress + 40, alignment: .top)
            .clipped()
    }
}

/// 刘海张开成出片口（黑色的岛 + 一道出片缝）。
struct StudioNotchSlot: View {
    let slotWidth: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            NotchShape(earRadius: 12, bottomRadius: 11)
                .fill(Color.black)
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
                .frame(width: slotWidth + 6, height: 4)
                .padding(.bottom, 4)
        }
        .frame(width: slotWidth + 60, height: 40)
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}

/// 桌面：一张相片正从刘海里吐出来；右上角是照片堆；装饰过的拿铁被拖到右下；左边是一条大头贴和一张宽幅。
struct DeskScene: View {
    let prints: [String: StudioPrint]

    var body: some View {
        ZStack(alignment: .topLeading) {
            StudioWallpaper()
            card("booth-strip", width: 106, tilt: -5, at: CGPoint(x: 150, y: 330))
            card("street", width: 290, tilt: 3, at: CGPoint(x: 330, y: 700))
            card("lake", width: 250, tilt: 7, at: CGPoint(x: 1250, y: 205))
            card("blossom", width: 205, tilt: -6, at: CGPoint(x: 1212, y: 240))
            card("cat", width: 158, tilt: 3, at: CGPoint(x: 1290, y: 262))
            card("latte", width: 246, tilt: -4, at: CGPoint(x: 1070, y: 610))
            StudioMenuBar(width: 1440)
            if let dog = prints["dog"] {
                VStack(spacing: -6) {
                    StudioNotchSlot(slotWidth: 226)
                    StudioEjectingPrint(item: dog, width: 226, progress: 0.72)
                }
                .frame(width: 1440, alignment: .top)
            }
        }
        .frame(width: 1440, height: 900, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private func card(_ key: String, width: CGFloat, tilt: Double, at point: CGPoint) -> some View {
        if let item = prints[key] {
            StudioPrintCard(item: item, width: width, tilt: tilt)
                .position(point)
        }
    }
}

/// 相纸一览：胡桃木桌上摆着不同相纸和模板的成片，下面一行打字机字的说明。
struct PrintGalleryScene: View {
    let prints: [String: StudioPrint]

    var body: some View {
        ZStack {
            Image("WoodTexture")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1600, height: 1000)
                .clipped()
            Color.black.opacity(0.28)
            RadialGradient(colors: [Color(hex: 0xFFE2B8, opacity: 0.26), .clear], center: UnitPoint(x: 0.45, y: 0.35), startRadius: 20, endRadius: 900)
            VStack(spacing: 64) {
                HStack(alignment: .center, spacing: 56) {
                    item("latte", width: 230, tilt: -2)
                    item("cat", width: 160, tilt: 2)
                    item("street", width: 300, tilt: -1.5)
                    item("beach", width: 290, tilt: 2.5)
                }
                HStack(alignment: .center, spacing: 50) {
                    item("booth-strip", width: 112, tilt: 2)
                    item("booth-heart", width: 220, tilt: -2)
                    item("blossom", width: 230, tilt: 1.5)
                    item("sparklers", width: 230, tilt: -2.5)
                    item("tulips", width: 230, tilt: 2)
                }
            }
        }
        .frame(width: 1600, height: 1000)
        .clipped()
    }

    @ViewBuilder
    private func item(_ key: String, width: CGFloat, tilt: Double) -> some View {
        if let shot = prints[key] {
            let template = TemplateCatalog.resolve(id: shot.record.templateID, format: shot.record.format)
            VStack(spacing: 16) {
                StudioPrintCard(item: shot, width: width, tilt: tilt)
                Text("\(template.name) · \(shot.record.format.displayName)")
                    .font(RetroFont.typewriter(13))
                    .foregroundStyle(Color(hex: 0xF2EEE6, opacity: 0.86))
            }
        }
    }
}

/// 大头贴机的「选相框」：真实的 `BoothInterior`，两边是拉上的 3D 丝绒布帘（`CurtainScene.renderClosed`
/// 离屏渲染的透明图，和 App 里同一套几何与材质）。没有 Metal 时退回平铺的丝绒纹理。
struct BoothScene: View {
    @ObservedObject var booth: PhotoBoothController
    var curtain: NSImage?
    var size = CGSize(width: 1300, height: 1100)

    var body: some View {
        ZStack {
            if let curtain {
                StudioWallpaper()
                Color.black.opacity(0.62)
                RadialGradient(colors: [Color(hex: 0xFFE2B8, opacity: 0.16), .clear], center: .top, startRadius: 10, endRadius: 640)
                Image(nsImage: curtain)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                BoothInterior(booth: booth, session: CameraService.shared.session, camera: CameraService.shared)
            } else {
                Image("VelvetTexture")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                Color.black.opacity(0.5)
                RadialGradient(colors: [Color(hex: 0xFFE2B8, opacity: 0.2), .clear], center: .top, startRadius: 10, endRadius: 720)
                BoothInterior(booth: booth, session: CameraService.shared.session, camera: CameraService.shared)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// 刘海面板截图的背景：壁纸 + 菜单栏（面板窗口本身由窗口服务器截下来再叠上去）。
struct NotchBackdrop: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            StudioWallpaper()
            StudioMenuBar(width: width, showsItems: false)
        }
        .frame(width: width, height: height)
    }
}

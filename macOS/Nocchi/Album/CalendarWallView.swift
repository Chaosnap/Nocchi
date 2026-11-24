import AppKit
import NocchiKit
import SwiftUI

/// 日历：墙上挂着的一页复古挂历（印刷红 + 墨黑两色）。
///
/// 顶上一条装订边和两个黄铜铆眼；大号月份数字、中英文月份、年份；有照片的日子贴一张带白边、
/// 四个黑色照片角的小照片（多于 1 张时角上一个红色小圆章「+2」）；今天用红色印章圈出来。
/// 点某一天，页面下方展开这一天的照片；页脚是本月统计。
struct CalendarWallView: View {
    let records: [PhotoRecord]
    let libraryIsEmpty: Bool
    @State private var year: Int
    @State private var month: Int
    @State private var selectedDay: String?

    init(records: [PhotoRecord], libraryIsEmpty: Bool) {
        self.records = records
        self.libraryIsEmpty = libraryIsEmpty
        let start = Self.startMonth(for: records)
        _year = State(initialValue: start.year)
        _month = State(initialValue: start.month)
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()

    /// 打开时显示最近一张照片所在的月份（没有照片时是这个月）。
    static func startMonth(for records: [PhotoRecord]) -> (year: Int, month: Int) {
        let date = records.map(\.displayDate).max() ?? Date()
        let parts = calendar.dateComponents([.year, .month], from: date)
        return (parts.year ?? 2026, parts.month ?? 1)
    }

    var body: some View {
        let page = PhotoCalendar.month(year: year, month: month, records: records, calendar: Self.calendar)
        let selected = page.weeks.joined().first { $0.id == selectedDay }
        GeometryReader { geo in
            let width = min(geo.size.width - 80, 940)
            let height = geo.size.height - 44
            ZStack {
                WallBackground()
                CalendarPage(
                    page: page,
                    selected: selected,
                    size: CGSize(width: width, height: height),
                    onSelect: { day in
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                            selectedDay = (selectedDay == day.id || day.records.isEmpty) ? nil : day.id
                        }
                    },
                    onStep: { delta in step(delta) },
                    onToday: { goToday() }
                )
                .frame(width: width, height: height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: records.first?.id) { _, _ in
            // 搜索结果变了：翻到最近一张命中照片所在的月份。
            let start = Self.startMonth(for: records)
            withAnimation(.easeOut(duration: 0.2)) {
                year = start.year
                month = start.month
                selectedDay = nil
            }
        }
    }

    private func step(_ delta: Int) {
        let next = PhotoCalendar.month(year: year, month: month + delta, records: [], calendar: Self.calendar)
        withAnimation(.easeOut(duration: 0.22)) {
            year = next.year
            month = next.month
            selectedDay = nil
        }
        SoundPlayer.shared.play(.cardSlide)
    }

    private func goToday() {
        let parts = Self.calendar.dateComponents([.year, .month], from: Date())
        withAnimation(.easeOut(duration: 0.22)) {
            year = parts.year ?? year
            month = parts.month ?? month
            selectedDay = nil
        }
    }
}

// MARK: - 挂历页

private struct CalendarPage: View {
    let page: CalendarMonth
    let selected: CalendarDay?
    let size: CGSize
    let onSelect: (CalendarDay) -> Void
    let onStep: (Int) -> Void
    let onToday: () -> Void

    private static let english = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    private static let chinese = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    private static let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 0) {
            BindingStrip()
            header
                .padding(.horizontal, 34)
                .padding(.top, 14)
            weekdayRow
                .padding(.horizontal, 30)
                .padding(.top, 10)
            grid
                .padding(.horizontal, 30)
            if let selected {
                DayTray(day: selected) { onSelect(selected) }
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            footer
                .padding(.horizontal, 34)
                .padding(.vertical, 12)
        }
        .background(PaperSheet())
        .clipShape(Rectangle())
        .shadow(color: .black.opacity(0.22), radius: 1.2, x: 0.5, y: 1)
        .shadow(color: .black.opacity(0.18), radius: 22, x: 6, y: 16)
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Text("\(page.month)")
                .font(RetroFont.display(96, weight: .bold))
                .foregroundStyle(Palette.printRed)
                .monospacedDigit()
                .frame(minWidth: 120, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Self.english[(page.month - 1 + 12) % 12]) · \(Self.chinese[(page.month - 1 + 12) % 12])")
                    .font(RetroFont.serif(16, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(Palette.ink)
                Text(String(page.year))
                    .font(RetroFont.typewriter(15))
                    .tracking(3)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            HStack(spacing: 8) {
                BrassButton(symbol: "chevron.left", help: "上个月") { onStep(-1) }
                BrassButton(title: "今天", help: "回到这个月") { onToday() }
                BrassButton(symbol: "chevron.right", help: "下个月") { onStep(1) }
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { index, name in
                Text(name)
                    .font(RetroFont.serif(13, weight: .semibold))
                    .foregroundStyle(index >= 5 ? Palette.printRed : Palette.ink)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.ink.opacity(0.75)).frame(height: 1.2)
        }
    }

    // MARK: 日期格

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(Array(page.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        DayCell(day: day, selected: selected?.id == day.id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(day) }
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(Palette.hairline).frame(width: 0.6)
                            }
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.hairline).frame(height: 0.6)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: 页脚

    private var footer: some View {
        HStack {
            Text(summary)
                .font(RetroFont.typewriter(12.5))
                .foregroundStyle(Palette.inkSoft)
            Spacer()
            Text("NOCCHI 冲印店 · 挂历")
                .font(RetroFont.typewriter(10.5))
                .tracking(1.5)
                .foregroundStyle(Palette.inkSoft.opacity(0.7))
        }
    }

    private var summary: String {
        guard page.photoCount > 0 else { return "本月还没有照片" }
        var parts = ["本月 \(page.photoCount) 张", "用了 \(page.stockCount) 卷胶卷"]
        if let tag = page.topTag {
            parts.append("最常写 #\(tag)")
        }
        return parts.joined(separator: " · ")
    }
}

/// 一个日期格：左上日期数字（周末红、非本月淡）；今天红色印章圈；有照片时贴一张小照片。
private struct DayCell: View {
    let day: CalendarDay
    let selected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if selected {
                Rectangle().fill(Palette.mustard.opacity(0.14))
            }
            Text("\(day.day)")
                .font(RetroFont.display(15, weight: .semibold))
                .foregroundStyle(day.weekdayIndex >= 5 ? Palette.printRed : Palette.ink)
                .opacity(day.isInMonth ? 1 : 0.28)
                .padding(.leading, 7)
                .padding(.top, 4)
                .overlay {
                    if day.isToday {
                        TodayStamp()
                            .offset(x: 3, y: 2)
                    }
                }
            if let first = day.records.first {
                CornerPhoto(record: first, extra: day.records.count - 1)
                    .padding(.top, 20)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(day.isInMonth ? 1 : 0.5)
            }
        }
        .help(day.records.isEmpty ? "" : "\(day.records.count) 张 · 点一下展开")
    }
}

/// 今天：一圈有点歪的红色印章。
private struct TodayStamp: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.printRed.opacity(0.85), lineWidth: 1.6)
                .frame(width: 30, height: 30)
            Circle()
                .stroke(Palette.printRed.opacity(0.35), lineWidth: 0.8)
                .frame(width: 33, height: 31)
                .offset(x: 0.6, y: -0.4)
        }
        .rotationEffect(.degrees(-8))
        .allowsHitTesting(false)
    }
}

/// 格子里的小照片：白边 + 四个黑色照片角，轻微倾斜；多于 1 张时右上角一个红色小圆章。
private struct CornerPhoto: View {
    let record: PhotoRecord
    let extra: Int

    var body: some View {
        GeometryReader { geo in
            let side = max(10, min(geo.size.width * 0.82, geo.size.height))
            ZStack(alignment: .topTrailing) {
                AlbumThumbnail(record: record, maxPixel: 240, photoOnly: true)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: side - 6, height: side - 6)
                    .clipped()
                    .padding(3)
                    .background(Color.white)
                    .overlay { PhotoCorners(size: max(5, side * 0.16)) }
                    .shadow(color: .black.opacity(0.22), radius: 1, x: 0.5, y: 0.8)
                    .rotationEffect(.degrees((Double((record.seed >> 20) & 0xFF) / 255 - 0.5) * 7))
                if extra > 0 {
                    Text("+\(extra)")
                        .font(RetroFont.typewriter(9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.printRed))
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.8))
                        .offset(x: 7, y: -7)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// 老相册的黑色照片角。
private struct PhotoCorners: View {
    let size: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.addLines([CGPoint(x: 0, y: 0), CGPoint(x: size, y: 0), CGPoint(x: 0, y: size)])
                path.closeSubpath()
                path.addLines([CGPoint(x: w, y: 0), CGPoint(x: w - size, y: 0), CGPoint(x: w, y: size)])
                path.closeSubpath()
                path.addLines([CGPoint(x: 0, y: h), CGPoint(x: size, y: h), CGPoint(x: 0, y: h - size)])
                path.closeSubpath()
                path.addLines([CGPoint(x: w, y: h), CGPoint(x: w - size, y: h), CGPoint(x: w, y: h - size)])
                path.closeSubpath()
            }
            .fill(Color(hex: 0x1C1A18))
        }
        .allowsHitTesting(false)
    }
}

/// 点开的那一天：一排照片 + 题字。
private struct DayTray: View {
    let day: CalendarDay
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(RetroFont.serif(14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.paperDeep))
                }
                .buttonStyle(.plain)
                .help("收起")
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(day.records) { record in
                        VStack(alignment: .leading, spacing: 5) {
                            AlbumThumbnail(record: record, maxPixel: 420)
                                .aspectRatio(max(0.1, record.printFile != nil ? record.layout.aspect : record.layout.windowAspect), contentMode: .fit)
                                .frame(height: 140)
                                .shadow(color: .black.opacity(0.22), radius: 1.2, x: 0.5, y: 1)
                                .shadow(color: .black.opacity(0.14), radius: 6, x: 2, y: 4)
                                .onTapGesture(count: 2) { AlbumActions.open(record) }
                                .contextMenu { AlbumContextMenu(record: record) }
                            Text(record.indexTitle)
                                .font(RetroFont.typewriter(11))
                                .foregroundStyle(Palette.inkSoft)
                                .lineLimit(1)
                                .frame(maxWidth: 160, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.paperDeep.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Palette.hairline, lineWidth: 0.6)
        )
    }

    private var title: String {
        let parts = CalendarWallView.calendar.dateComponents([.month, .day], from: day.date)
        return "\(parts.month ?? 0) 月 \(parts.day ?? 0) 日 · \(day.records.count) 张"
    }
}

// MARK: - 纸、装订边、墙

/// 挂历纸：米色 + 纸纹 + 四周轻微做旧。
private struct PaperSheet: View {
    var body: some View {
        ZStack {
            Color(hex: 0xF3EBDD)
            if BundledImage.has("PaperTexture") {
                Image("PaperTexture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.22)
                    .blendMode(.multiply)
            }
            RadialGradient(colors: [.clear, Color(hex: 0x8A6A3A, opacity: 0.1)], center: .center, startRadius: 260, endRadius: 760)
        }
    }
}

/// 顶上的装订边与两个黄铜铆眼。
private struct BindingStrip: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2E2924), Color(hex: 0x1C1916)], startPoint: .top, endPoint: .bottom)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                ForEach([0.25, 0.75], id: \.self) { fraction in
                    Eyelet()
                        .position(x: geo.size.width * fraction, y: geo.size.height / 2)
                }
            }
        }
        .frame(height: 22)
    }
}

private struct Eyelet: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x7A5E30)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 14, height: 14)
            Circle()
                .fill(Color(hex: 0x0E0C0A))
                .frame(width: 6, height: 6)
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 0.6)
                .frame(width: 12, height: 12)
                .offset(x: -0.4, y: -0.4)
        }
        .shadow(color: .black.opacity(0.45), radius: 0.8, y: 0.8)
    }
}

/// 墙：暖灰米色，左上方的光。
private struct WallBackground: View {
    var body: some View {
        ZStack {
            Palette.paperDeep
            LinearGradient(colors: [Color.white.opacity(0.25), .clear, Color.black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// 黄铜小按钮（‹ ›「今天」）。
private struct BrassButton: View {
    var symbol: String? = nil
    var title: String? = nil
    let help: String
    let action: () -> Void
    @State private var hovering = false

    init(symbol: String? = nil, title: String? = nil, help: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                } else if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 11)
                        .frame(height: 26)
                }
            }
            .foregroundStyle(Palette.walnutDeep)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 0.8).padding(0.8))
            .overlay(Capsule().stroke(Palette.walnut.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 0.8, y: 0.8)
            .shadow(color: .black.opacity(hovering ? 0.18 : 0.1), radius: hovering ? 5 : 3, y: 2)
            .scaleEffect(hovering ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { hovering = inside }
        }
        .help(help)
    }
}

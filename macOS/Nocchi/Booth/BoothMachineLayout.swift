// 由 design/blender/booth/make_machine.py 生成，不要手改。
import CoreGraphics

/// 大头贴机整机正面（`BoothMachine`，720 × 960 点）上各处的位置：橱窗、铭牌、页码槽、拨杆刻字、灯泡，
/// 以及会动的零件图（箭头、拨杆、开始按钮）在整机上的框。
enum BoothMachineLayout {
    static let size = CGSize(width: 720, height: 960)
    /// 橱窗（透明，界面在里面放样张 / 摄像头画面）。
    static let window = CGRect(x: 130.0, y: 240.0, width: 460.0, height: 370.0)
    static let windowCornerRadius: CGFloat = 26
    /// 黄铜铭牌（写模板名和一句说明）。
    static let nameplate = CGRect(x: 244.0, y: 624.0, width: 232.0, height: 52.0)
    /// 黑色页码槽。
    static let dots = CGRect(x: 244.0, y: 690.0, width: 232.0, height: 10.0)
    /// 控制台底下写胶卷名的地方。
    static let filmInfo = CGRect(x: 240.0, y: 832.0, width: 240.0, height: 18.0)
    /// 招牌（立体金字所在的搪瓷牌）。
    static let sign = CGRect(x: 66.0, y: 46.0, width: 588.0, height: 144.0)
    static let startCenter = CGPoint(x: 360.0, y: 776.0)
    static let arrowLeft = CGRect(x: 43.0, y: 390.0, width: 87.5, height: 87.5)
    static let arrowLeftDown = CGRect(x: 43.0, y: 390.0, width: 87.5, height: 87.5)
    static let arrowRight = CGRect(x: 607.0, y: 390.0, width: 87.5, height: 87.5)
    static let arrowRightDown = CGRect(x: 607.0, y: 390.0, width: 87.5, height: 87.5)
    static let formatLeft = CGRect(x: 131.5, y: 750.5, width: 82.0, height: 57.0)
    static let formatRight = CGRect(x: 164.5, y: 750.5, width: 82.0, height: 57.0)
    static let colorLeft = CGRect(x: 491.5, y: 750.5, width: 82.0, height: 57.0)
    static let colorRight = CGRect(x: 524.5, y: 750.5, width: 82.0, height: 57.0)
    static let start = CGRect(x: 311.5, y: 727.5, width: 115.0, height: 115.0)
    static let startLit = CGRect(x: 311.5, y: 727.5, width: 115.0, height: 115.0)
    static let startDown = CGRect(x: 311.5, y: 727.5, width: 115.0, height: 115.0)
    /// 拨杆两边的刻字（中心点）：点刻字拨到那一边。
    static let labels: [String: CGPoint] = [
        "四格条": CGPoint(x: 110.0, y: 770.0),
        "四宫格": CGPoint(x: 250.0, y: 770.0),
        "黑白": CGPoint(x: 482.0, y: 770.0),
        "彩色": CGPoint(x: 598.0, y: 770.0),
    ]
    /// 拱框上一圈灯泡的中心。
    static let bulbs: [CGPoint] = [
        CGPoint(x: 53.0, y: 188.0),
        CGPoint(x: 53.0, y: 144.4),
        CGPoint(x: 69.4, y: 105.5),
        CGPoint(x: 104.9, y: 80.5),
        CGPoint(x: 145.1, y: 63.6),
        CGPoint(x: 187.0, y: 51.6),
        CGPoint(x: 229.7, y: 43.1),
        CGPoint(x: 272.9, y: 37.4),
        CGPoint(x: 316.4, y: 34.1),
        CGPoint(x: 360.0, y: 33.0),
        CGPoint(x: 403.6, y: 34.1),
        CGPoint(x: 447.1, y: 37.4),
        CGPoint(x: 490.3, y: 43.1),
        CGPoint(x: 533.0, y: 51.6),
        CGPoint(x: 574.9, y: 63.6),
        CGPoint(x: 615.1, y: 80.5),
        CGPoint(x: 650.6, y: 105.5),
        CGPoint(x: 667.0, y: 144.4),
        CGPoint(x: 667.0, y: 188.0),
    ]
}

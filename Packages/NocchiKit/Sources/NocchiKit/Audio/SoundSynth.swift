import Foundation

/// 相机铺里的所有声音。全部由程序合成，不打包任何音频素材。
public enum SoundEffect: String, CaseIterable, Sendable {
    /// 机身开机的「嗡」。
    case powerOn
    /// 大头贴机投币。
    case coin
    /// 倒数「哔」。
    case beep
    /// 倒数最后一声（更高）。
    case beepFinal
    /// 即显相机的机械快门。
    case shutter
    /// 大头贴机的快门（更重一点）。
    case shutterBooth
    /// 出片马达。
    case motor
    /// 显影完成的轻「叮」。
    case ding
    /// 撕纸。
    case tear
    /// 过片齿轮。
    case gearClick
    /// 闪光灯充电。
    case flashCharge
    /// 拉帘子。
    case curtain
    /// 照片吸到屏幕边缘。
    case magnet
    /// 甩出色块时「啪」的一下。
    case splat
}

/// 简单的程序化合成器：噪声爆发、衰减正弦、滤波。
public enum SoundSynth {
    public static let sampleRate: Double = 44_100

    /// 渲染单声道样本，峰值归一化到 0.85 以内。
    public static func render(_ effect: SoundEffect, duration: Double? = nil, seed: UInt64 = 7) -> [Float] {
        let index = UInt64(SoundEffect.allCases.firstIndex(of: effect) ?? 0)
        var rng = SeededRandom(seed: seed &+ index &* 7919)
        var buf: [Float]

        switch effect {
        case .powerOn:
            buf = silence(0.55)
            addClick(&buf, at: 0, amp: 0.5, decay: 0.004, rng: &rng)
            addSweep(&buf, start: 0.02, duration: 0.45, from: 180, to: 420, amp: 0.25, rng: &rng)
            addTone(&buf, start: 0.0, frequency: 60, duration: 0.5, amp: 0.25, decay: 0.4, attack: 0.12, partials: [(1, 1), (2, 0.5), (3, 0.25)])
        case .coin:
            buf = silence(0.75)
            addClick(&buf, at: 0, amp: 0.6, decay: 0.003, rng: &rng)
            addTone(&buf, start: 0.0, frequency: 2093, duration: 0.45, amp: 0.45, decay: 0.16, partials: [(1, 1), (2.76, 0.4), (5.4, 0.2)])
            addTone(&buf, start: 0.07, frequency: 2637, duration: 0.45, amp: 0.4, decay: 0.18, partials: [(1, 1), (2.76, 0.35), (5.4, 0.15)])
            addTone(&buf, start: 0.26, frequency: 190, duration: 0.12, amp: 0.35, decay: 0.03)
            for (i, t) in [0.31, 0.37, 0.415, 0.45].enumerated() {
                addClick(&buf, at: t, amp: 0.35 / Float(i + 1), decay: 0.003, rng: &rng)
            }
        case .beep:
            buf = silence(0.16)
            addTone(&buf, start: 0, frequency: 880, duration: 0.12, amp: 0.45, decay: 1, attack: 0.004, release: 0.02, partials: [(1, 1), (3, 0.18)])
        case .beepFinal:
            buf = silence(0.42)
            addTone(&buf, start: 0, frequency: 1320, duration: 0.34, amp: 0.5, decay: 1, attack: 0.004, release: 0.06, partials: [(1, 1), (3, 0.15)])
        case .shutter:
            buf = silence(0.34)
            addClick(&buf, at: 0, amp: 1.0, decay: 0.005, rng: &rng)
            addTone(&buf, start: 0, frequency: 140, duration: 0.07, amp: 0.55, decay: 0.02)
            addNoise(&buf, start: 0.008, duration: 0.07, amp: 0.16, decay: 0.03, lowpass: 2600, rng: &rng)
            addClick(&buf, at: 0.085, amp: 0.8, decay: 0.007, rng: &rng)
            addTone(&buf, start: 0.085, frequency: 112, duration: 0.09, amp: 0.45, decay: 0.03)
            addTone(&buf, start: 0.09, frequency: 1850, duration: 0.2, amp: 0.06, decay: 0.05)
        case .shutterBooth:
            buf = silence(0.5)
            addClick(&buf, at: 0, amp: 1.0, decay: 0.008, rng: &rng)
            addTone(&buf, start: 0, frequency: 95, duration: 0.12, amp: 0.6, decay: 0.04)
            addNoise(&buf, start: 0.01, duration: 0.14, amp: 0.2, decay: 0.05, lowpass: 1800, rng: &rng)
            addClick(&buf, at: 0.13, amp: 0.9, decay: 0.01, rng: &rng)
            addTone(&buf, start: 0.13, frequency: 88, duration: 0.14, amp: 0.5, decay: 0.05)
            addTone(&buf, start: 0.14, frequency: 940, duration: 0.3, amp: 0.07, decay: 0.09)
        case .motor:
            let d = max(0.3, duration ?? 2.2)
            buf = silence(d)
            renderMotor(&buf, duration: d, rng: &rng)
        case .ding:
            buf = silence(1.5)
            addTone(&buf, start: 0, frequency: 1568, duration: 1.45, amp: 0.4, decay: 0.55, attack: 0.003, partials: [(1, 1), (2.01, 0.35), (3.0, 0.16), (4.2, 0.07)])
        case .tear:
            buf = silence(0.55)
            renderTear(&buf, rng: &rng)
        case .gearClick:
            buf = silence(0.12)
            addClick(&buf, at: 0, amp: 0.7, decay: 0.003, rng: &rng)
            addTone(&buf, start: 0, frequency: 620, duration: 0.03, amp: 0.2, decay: 0.008)
            addClick(&buf, at: 0.032, amp: 0.5, decay: 0.003, rng: &rng)
        case .flashCharge:
            buf = silence(1.15)
            addSweep(&buf, start: 0, duration: 1.1, from: 2400, to: 8600, amp: 0.12, rng: &rng)
        case .curtain:
            buf = silence(0.8)
            renderWhoosh(&buf, rng: &rng)
        case .magnet:
            buf = silence(0.1)
            addClick(&buf, at: 0, amp: 0.4, decay: 0.002, rng: &rng)
            addTone(&buf, start: 0, frequency: 420, duration: 0.07, amp: 0.4, decay: 0.016)
        case .splat:
            buf = silence(0.28)
            addNoise(&buf, start: 0, duration: 0.25, amp: 0.5, decay: 0.06, lowpass: 900, rng: &rng)
            addTone(&buf, start: 0, frequency: 160, duration: 0.15, amp: 0.4, decay: 0.05)
        }
        normalize(&buf, peak: 0.85)
        return buf
    }

    // MARK: - Building blocks

    static func silence(_ seconds: Double) -> [Float] {
        [Float](repeating: 0, count: max(1, Int(seconds * sampleRate)))
    }

    static func addTone(
        _ buf: inout [Float],
        start: Double,
        frequency: Double,
        duration: Double,
        amp: Float,
        decay: Double,
        attack: Double = 0.002,
        release: Double = 0.01,
        partials: [(Double, Float)] = [(1, 1)]
    ) {
        let i0 = Int(start * sampleRate)
        let n = Int(duration * sampleRate)
        guard i0 < buf.count, n > 0 else { return }
        for k in 0..<n {
            let i = i0 + k
            if i >= buf.count { break }
            let t = Double(k) / sampleRate
            var env = exp(-t / max(decay, 0.0005))
            if t < attack { env *= t / attack }
            let tail = duration - t
            if tail < release { env *= max(0, tail / release) }
            var s = 0.0
            for (ratio, gain) in partials {
                s += sin(2 * .pi * frequency * ratio * t) * Double(gain)
            }
            buf[i] += Float(s * env) * amp
        }
    }

    static func addNoise(
        _ buf: inout [Float],
        start: Double,
        duration: Double,
        amp: Float,
        decay: Double,
        lowpass: Double? = nil,
        highpass: Double? = nil,
        rng: inout SeededRandom
    ) {
        let i0 = Int(start * sampleRate)
        let n = Int(duration * sampleRate)
        guard i0 < buf.count, n > 0 else { return }
        let aLow = lowpass.map { Float(1 - exp(-2 * .pi * $0 / sampleRate)) }
        let aHigh = highpass.map { Float(1 - exp(-2 * .pi * $0 / sampleRate)) }
        var low: Float = 0
        var highState: Float = 0
        for k in 0..<n {
            let i = i0 + k
            if i >= buf.count { break }
            let t = Double(k) / sampleRate
            var x = Float(rng.signed())
            if let a = aLow {
                low += a * (x - low)
                x = low
            }
            if let a = aHigh {
                highState += a * (x - highState)
                x -= highState
            }
            buf[i] += x * Float(exp(-t / max(decay, 0.0005))) * amp
        }
    }

    static func addClick(_ buf: inout [Float], at start: Double, amp: Float, decay: Double, rng: inout SeededRandom) {
        addNoise(&buf, start: start, duration: decay * 8, amp: amp, decay: decay, highpass: 1800, rng: &rng)
    }

    static func addSweep(_ buf: inout [Float], start: Double, duration: Double, from f0: Double, to f1: Double, amp: Float, rng: inout SeededRandom) {
        let i0 = Int(start * sampleRate)
        let n = Int(duration * sampleRate)
        var phase = 0.0
        for k in 0..<n {
            let i = i0 + k
            if i >= buf.count { break }
            let u = Double(k) / Double(max(n - 1, 1))
            let f = f0 + (f1 - f0) * u * u
            phase += 2 * .pi * f / sampleRate
            let env = min(1, u * 8) * min(1, (1 - u) * 6)
            let tremolo = 0.85 + 0.15 * sin(2 * .pi * 23 * Double(k) / sampleRate)
            buf[i] += Float(sin(phase) * env * tremolo) * amp
        }
    }

    static func renderMotor(_ buf: inout [Float], duration d: Double, rng: inout SeededRandom) {
        var phase = 0.0
        var whinePhase = 0.0
        var low: Float = 0
        for i in 0..<buf.count {
            let t = Double(i) / sampleRate
            let wobble = 1 + 0.035 * sin(2 * .pi * 7 * t)
            phase += 2 * .pi * 92 * wobble / sampleRate
            whinePhase += 2 * .pi * 760 * wobble / sampleRate
            var s = 0.0
            for h in 1...6 {
                s += sin(phase * Double(h)) / Double(h)
            }
            let whine = sin(whinePhase) * 0.12
            low += 0.08 * (Float(rng.signed()) - low)
            let env = min(1, t / 0.05) * min(1, max(0, d - t) / 0.08)
            buf[i] = Float((s * 0.33 + whine) * env) + low * 0.22 * Float(env)
        }
        var t = 0.03
        while t < d - 0.05 {
            addClick(&buf, at: t, amp: 0.22, decay: 0.002, rng: &rng)
            t += 0.11
        }
    }

    static func renderTear(_ buf: inout [Float], rng: inout SeededRandom) {
        var low: Float = 0
        var highState: Float = 0
        let aLow: Float = Float(1 - exp(-2 * .pi * 5200 / sampleRate))
        let aHigh: Float = Float(1 - exp(-2 * .pi * 900 / sampleRate))
        let n = buf.count
        for i in 0..<n {
            let u = Double(i) / Double(n)
            let env = sin(.pi * min(1, u * 1.15))
            let density = 0.02 + 0.2 * env
            var x: Float = Float(rng.signed()) * 0.18
            if rng.unit() < density {
                x += Float(rng.signed())
            }
            low += aLow * (x - low)
            highState += aHigh * (low - highState)
            buf[i] = (low - highState) * Float(env)
        }
    }

    static func renderWhoosh(_ buf: inout [Float], rng: inout SeededRandom) {
        var low: Float = 0
        let n = buf.count
        for i in 0..<n {
            let u = Double(i) / Double(n)
            let cutoff = 350 + 1500 * sin(.pi * u)
            let a = Float(1 - exp(-2 * .pi * cutoff / sampleRate))
            low += a * (Float(rng.signed()) - low)
            let env = sin(.pi * u) * sin(.pi * u)
            buf[i] = low * Float(env) * 1.6
        }
    }

    static func normalize(_ buf: inout [Float], peak target: Float) {
        var peak: Float = 0
        for v in buf where v.isFinite {
            peak = max(peak, abs(v))
        }
        guard peak > 0 else { return }
        let gain = target / peak
        for i in buf.indices {
            let v = buf[i].isFinite ? buf[i] : 0
            buf[i] = v * gain
        }
    }
}

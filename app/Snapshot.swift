import AppKit
import SwiftUI

/// Mode développement : `UsageForecast --snapshot /chemin/popover.png [--settings]` rend le popover dans un PNG puis quitte.
/// Permet de vérifier l'interface sans cliquer dans la barre de menu.
enum Snapshot {
    static var outputPath: String? {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshot"), flag + 1 < args.count else { return nil }
        return args[flag + 1]
    }

    /// Valeur d'une option `--nom valeur` (vérifications visuelles, jamais enregistrée dans les réglages).
    static func option(_ name: String) -> String? {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: name), flag + 1 < args.count else { return nil }
        return args[flag + 1]
    }

    /// Historique fictif des dernières 24 h (dents de scie de sessions de 5 h) pour les aperçus.
    static func demoHistory(session current: Double, now: Date = AppClock.now, hours: Double = 24) -> [UsageSample] {
        let first = 288 - Int(hours * 12)
        return (max(first, 0)...288).map { index in
            let minutesAgo = Double(288 - index) * 5
            let phase = (minutesAgo.truncatingRemainder(dividingBy: 300)) / 300
            let level = max(0, min(100, (1 - phase) * 62 + (index % 7 == 0 ? 3 : 0)))
            let value = index == 288 ? current : level
            return UsageSample(time: now.addingTimeInterval(-minutesAgo * 60).timeIntervalSince1970, session: value, weekly: min(100, 20 + Double(index) / 288 * 17))
        }
    }

    /// Journal quotidien fictif (semaines chargées, week-ends calmes, un jour partiel) : rendu identique tous les jours avec l'horloge figée.
    static func demoDailySummaries(days: Int = 45, now: Date = AppClock.now, calendar: Calendar = .current) -> [DailySummary] {
        let midnight = calendar.startOfDay(for: now)
        let base: [Double] = [26, 22, 24, 20, 17, 7, 4]    // lundi … dimanche
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: midnight) else { return nil }
            let weekday = DailyInsights.weekdayIndex(of: date, calendar: calendar)
            let used = max(1, base[weekday] + Double((offset * 37) % 9) - 4)
            let working = weekday < 5 ? Array(9...12) + Array(14...18) + (weekday == 0 ? [20, 21] : []) : [10, 11, 15, 16]
            let samples = offset == 0 ? 520 : (offset % 11 == 3 ? 180 : 1100 + (offset * 13) % 300)
            return DailySummary(day: DailyStats.stamp(for: date, calendar: calendar), weeklyUsed: offset == 0 ? used * 0.45 : used,
                                sessionUsed: used * 2.6, peakSession: min(100, 35 + used * 1.8),
                                activeHours: working.filter { ($0 + offset) % 5 != 0 }, samples: samples)
        }
    }

    static func write(view: some View, to path: String, size: NSSize) {
        let isLight = CommandLine.arguments.contains("--light")
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height).background(Color(white: isLight ? 0.96 : 0.11)))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        let start = CFAbsoluteTimeGetCurrent()
        hosting.layoutSubtreeIfNeeded()
        defer { if CommandLine.arguments.contains("--time") { print(String(format: "rendu complet : %.0f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)) } }
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
